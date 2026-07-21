import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/event.dart';

/// FIXED: Properly schedules notifications with exact alarm permissions
/// and correct timing logic for start time vs deadline
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
    
    // FIXED: Request all required permissions for Android 12+ (API 31+)
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    // Request notification permission (Android 13+)
    final notifPermission = await androidImpl?.requestNotificationsPermission();
    print('Notification permission: $notifPermission');
    
    // FIXED: Request exact alarm permission - CRITICAL for precise scheduling
    final exactAlarmPermission = await androidImpl?.requestExactAlarmsPermission();
    print('Exact alarm permission: $exactAlarmPermission');
    
    _initialized = true;
  }

  /// FIXED: Use stable notification IDs to prevent duplicates
  /// Format: eventId * 100 + reminderType (1=dayBefore, 2=hourBefore)
  int _dayBeforeId(int eventId) => eventId * 100 + 1;
  int _hourBeforeId(int eventId) => eventId * 100 + 2;

  Future<void> cancelForEvent(int eventId) async {
    await _plugin.cancel(_dayBeforeId(eventId));
    await _plugin.cancel(_hourBeforeId(eventId));
  }

  /// FIXED: Properly determine anchor time and schedule both reminders
  Future<void> scheduleForEvent(Event event) async {
    if (event.id == null) return;
    
    // Cancel any existing notifications for this event first
    await cancelForEvent(event.id!);
    
    // FIXED: Determine the correct anchor time
    // Priority: startTime > deadline > date
    int anchorMillis;
    String timeType;
    
    if (event.startTimeMillis != null) {
      anchorMillis = event.startTimeMillis!;
      timeType = 'starts';
    } else if (event.deadlineMillis != null) {
      anchorMillis = event.deadlineMillis!;
      timeType = 'deadline';
    } else {
      anchorMillis = event.dateMillis;
      timeType = 'is on';
    }
    
    final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMillis);
    final now = DateTime.now();
    
    // FIXED: Only schedule if event is in the future
    if (anchor.isBefore(now)) {
      print('Event "${event.title}" is in the past, skipping notification scheduling');
      return;
    }
    
    // 1 day before at 9:00 AM
    final dayBeforeDate = anchor.subtract(const Duration(days: 1));
    final dayBefore = DateTime(
      dayBeforeDate.year,
      dayBeforeDate.month,
      dayBeforeDate.day,
      9, 0, 0,
    );
    
    // 1 hour before the anchor
    final hourBefore = anchor.subtract(const Duration(hours: 1));
    
    // Format time for display
    String formatTime(DateTime dt) {
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:$minute $period';
    }
    
    // Schedule day-before notification
    if (dayBefore.isAfter(now)) {
      print('Scheduling day-before notification for "${event.title}" at $dayBefore');
      await _scheduleAt(
        id: _dayBeforeId(event.id!),
        title: '📅 ${event.title}',
        body: 'Tomorrow at 9:00 AM • ${event.title} $timeType',
        when: dayBefore,
      );
    }
    
    // Schedule hour-before notification
    if (hourBefore.isAfter(now)) {
      print('Scheduling hour-before notification for "${event.title}" at $hourBefore');
      await _scheduleAt(
        id: _hourBeforeId(event.id!),
        title: '⏰ ${event.title}',
        body: 'At ${formatTime(hourBefore)} • ${event.title} $timeType',
        when: hourBefore,
      );
    }
  }

  /// FIXED: Use exactAllowWhileIdle for reliable delivery even in Doze mode
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
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      // FIXED: Full screen intent for alarm-like behavior
      fullScreenIntent: false,
    );
    
    const details = NotificationDetails(android: androidDetails);
    
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        details,
        // FIXED: Use exactAllowWhileIdle for Doze mode compatibility
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Successfully scheduled notification ID $id for $when');
    } catch (e) {
      print('ERROR scheduling notification ID $id: $e');
      // Fallback to inexact if exact fails
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(when, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        print('Fallback: Scheduled inexact notification ID $id');
      } catch (e2) {
        print('FATAL: Could not schedule notification: $e2');
      }
    }
  }

  Future<void> rescheduleAll(List<Event> events) async {
    for (final e in events) {
      await scheduleForEvent(e);
    }
  }
  
  /// FIXED: Show immediate notification (for testing)
  Future<void> showTestNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'event_countdown_test',
      'Test Notifications',
      channelDescription: 'For testing notification functionality',
      importance: Importance.max,
      priority: Priority.max,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(99999, title, body, details);
  }
}
