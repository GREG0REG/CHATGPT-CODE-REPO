import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/event.dart';

/// Schedules exactly the notifications required by the spec:
///  - 1 day before start time at 9:00 AM (if start time set)
///    OR 1 day before deadline at 9:00 AM (if no start time)
///  - 1 hour before start time (if start time set)
///    OR 1 hour before deadline (if no start time)
/// Tapping a notification opens the app (default behaviour).
class NotificationService {
NotificationService._();

static final NotificationService instance = NotificationService._();

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;

Future<void> init() async {
  if (_initialized) return;
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.local);
  
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await _plugin.initialize(initSettings);
  
  // Android 13+ runtime notification permission.
  final androidImpl = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.requestNotificationsPermission();
  await androidImpl?.requestExactAlarmsPermission();
  _initialized = true;
}

/// Two notification IDs per event: dayBefore = id*10+1, hourBefore = id*10+2
int _dayBeforeId(int eventId) => eventId * 10 + 1;
int _hourBeforeId(int eventId) => eventId * 10 + 2;

Future<void> cancelForEvent(int eventId) async {
  await _plugin.cancel(_dayBeforeId(eventId));
  await _plugin.cancel(_hourBeforeId(eventId));
}

Future<void> scheduleForEvent(Event event) async {
  if (event.id == null) return;
  await cancelForEvent(event.id!);
  
  // Which timestamp drives the reminders: start time if set, else deadline.
  final anchorMillis = event.startTimeMillis ?? event.deadlineMillis;
  if (anchorMillis == null) return; // nothing to schedule
  
  final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMillis);
  final now = DateTime.now();
  
  // 1 day before, at 9:00 AM.
  final dayBeforeDate = anchor.subtract(const Duration(days: 1));
  final dayBefore = DateTime(
    dayBeforeDate.year,
    dayBeforeDate.month,
    dayBeforeDate.day,
    9,
    0,
  );
  
  // 1 hour before the anchor.
  final hourBefore = anchor.subtract(const Duration(hours: 1));
  
  final label = event.startTimeMillis != null ? 'starts' : 'deadline is';
  
  // Format time for display (12-hour or 24-hour)
  String formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }
  
  if (dayBefore.isAfter(now)) {
    await _scheduleAt(
      id: _dayBeforeId(event.id!),
      title: ' ${event.title}',
      body: 'Tomorrow at 9:00 AM • ${event.title} $label',
      when: dayBefore,
    );
  }
  
  if (hourBefore.isAfter(now)) {
    await _scheduleAt(
      id: _hourBeforeId(event.id!),
      title: '⏰ ${event.title}',
      body: 'At ${formatTime(hourBefore)} • ${event.title} $label',
      when: hourBefore,
    );
  }
}

Future<void> _scheduleAt({
  required int id,
  required String title,
  required String body,
  required DateTime when,
}) async {
  const androidDetails = AndroidNotificationDetails(
    'event_countdown_channel',
    'Event Reminders',
    channelDescription: 'Reminders for upcoming events and deadlines',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    autoCancel: false,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );
  
  const details = NotificationDetails(android: androidDetails);
  
  await _plugin.zonedSchedule(
    id,
    title,
    body,
    tz.TZDateTime.from(when, tz.local),
    details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> rescheduleAll(List<Event> events) async {
  for (final e in events) {
    await scheduleForEvent(e);
  }
}
}
