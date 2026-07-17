import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../db/database_helper.dart';
import '../models/custom_reminder.dart';
import '../models/event.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  int _dayBeforeId(int eventId) => eventId * 100 + 1;
  int _hourBeforeId(int eventId) => eventId * 100 + 2;
  int _customReminderId(int eventId, int index) => eventId * 100 + 10 + index;

  Future<void> cancelForEvent(int eventId) async {
    await _plugin.cancel(_dayBeforeId(eventId));
    await _plugin.cancel(_hourBeforeId(eventId));
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(_customReminderId(eventId, i));
    }
  }

  Future<void> scheduleForEvent(Event event) async {
    if (event.id == null) return;
    await cancelForEvent(event.id!);

    final anchorMillis = event.startTimeMillis ?? event.deadlineMillis ?? event.dateMillis;
    final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMillis);
    final now = DateTime.now();

    // Default reminders
    final dayBeforeDate = anchor.subtract(const Duration(days: 1));
    final dayBefore = DateTime(dayBeforeDate.year, dayBeforeDate.month, dayBeforeDate.day, 9, 0);
    final hourBefore = anchor.subtract(const Duration(hours: 1));
    final label = event.startTimeMillis != null ? 'starts' : 'deadline is';

    if (dayBefore.isAfter(now)) {
      await _scheduleAt(
        id: _dayBeforeId(event.id!),
        title: event.title,
        body: '${event.title} $label tomorrow',
        when: dayBefore,
      );
    }

    if (hourBefore.isAfter(now)) {
      await _scheduleAt(
        id: _hourBeforeId(event.id!),
        title: event.title,
        body: '${event.title} $label in 1 hour',
        when: hourBefore,
      );
    }

    // FIX: Schedule custom reminders from database
    final customReminders = await DatabaseHelper.instance.getCustomRemindersForEvent(event.id!);
    for (int i = 0; i < customReminders.length; i++) {
      final reminder = customReminders[i];
      if (!reminder.isEnabled) continue;

      final reminderTime = anchor.subtract(Duration(minutes: reminder.minutesBefore));
      if (reminderTime.isAfter(now)) {
        final typeLabel = reminder.isAlarm ? 'Alarm' : 'Reminder';
        await _scheduleAt(
          id: _customReminderId(event.id!, i),
          title: event.title,
          body: '$typeLabel: ${event.title} in ${reminder.minutesBefore} minutes',
          when: reminderTime,
          isAlarm: reminder.isAlarm,
        );
      }
    }
  }

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool isAlarm = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      isAlarm ? 'event_countdown_alarms' : 'event_countdown_channel',
      isAlarm ? 'Event Alarms' : 'Event Reminders',
      channelDescription: isAlarm
          ? 'Full-screen alarms for upcoming events'
          : 'Reminders for upcoming events and deadlines',
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      fullScreenIntent: isAlarm,
      // FIX: Ensure notifications show in drawer
      visibility: NotificationVisibility.public,
      showWhen: true,
      when: when.millisecondsSinceEpoch,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id, title, body,
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
