// CHATGPT-CODE-REPO-TEST/lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter/material.dart';
import '../models/event.dart';

/// FIXED: Properly schedules notifications with exact alarm permissions,
/// graceful degradation, and Android 13+ compatibility.
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
    
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    // FIX: Request notification permission (Android 13+) with better error handling
    try {
      final notifPermission = await androidImpl?.requestNotificationsPermission();
      debugPrint('Notification permission: $notifPermission');
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    
    // FIX: Request exact alarm permission with graceful fallback
    bool exactAlarmGranted = false;
    try {
      exactAlarmGranted = await androidImpl?.requestExactAlarmsPermission() ?? false;
      debugPrint('Exact alarm permission: $exactAlarmGranted');
    } catch (e) {
      debugPrint('Exact alarm permission request failed: $e');
    }
    
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
  /// with fallback for denied exact alarm permission
  Future<void> scheduleForEvent(Event event) async {
    if (event.id == null) return;
    
    // Cancel any existing notifications for this event first
    await cancelForEvent(event.id!);
    
    // Determine the correct anchor time
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
    
    // Only schedule if event is in the future
    if (anchor.isBefore(now)) {
      debugPrint('Event "${event.title}" is in the past, skipping notification scheduling');
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
      debugPrint('Scheduling day-before notification for "${event.title}" at $dayBefore');
      await _scheduleAt(
        id: _dayBeforeId(event.id!),
        title: '📅 ${event.title}',
        body: 'Tomorrow at 9:00 AM • ${event.title} $timeType',
        when: dayBefore,
      );
    }
    
    // Schedule hour-before notification
    if (hourBefore.isAfter(now)) {
      debugPrint('Scheduling hour-before notification for "${event.title}" at $hourBefore');
      await _scheduleAt(
        id: _hourBeforeId(event.id!),
        title: '⏰ ${event.title}',
        body: 'At ${formatTime(hourBefore)} • ${event.title} $timeType',
        when: hourBefore,
      );
    }
  }

  /// FIXED: Use exactAllowWhileIdle with automatic fallback to inexact if permission denied.
  /// Also uses Importance.high instead of max to avoid Do Not Disturb blocking.
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
      // FIX: Use high instead of max to prevent Do Not Disturb from blocking
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: false,
    );
    
    const details = NotificationDetails(android: androidDetails);
    
    // Try exact scheduling first, fall back to inexact if denied
    bool scheduled = false;
    
    // Attempt 1: Exact alarm (most reliable)
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Successfully scheduled exact notification ID $id for $when');
      scheduled = true;
    } catch (e) {
      debugPrint('Exact scheduling failed for ID $id: $e');
    }
    
    // Attempt 2: Inexact fallback (works without exact alarm permission)
    if (!scheduled) {
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
        debugPrint('Fallback: Scheduled inexact notification ID $id');
        scheduled = true;
      } catch (e) {
        debugPrint('Inexact scheduling also failed for ID $id: $e');
      }
    }
    
    // Attempt 3: Immediate notification as last resort (for very near events)
    if (!scheduled) {
      final timeUntil = when.difference(DateTime.now());
      if (timeUntil.inMinutes < 5) {
        try {
          await _plugin.show(
            id,
            title,
            '$body (Immediate - scheduling unavailable)',
            details,
          );
          debugPrint('Last resort: Showed immediate notification ID $id');
        } catch (e) {
          debugPrint('FATAL: Could not show any notification for ID $id: $e');
        }
      }
    }
  }

  Future<void> rescheduleAll(List<Event> events) async {
    for (final e in events) {
      await scheduleForEvent(e);
    }
  }
  
  /// Show immediate notification (for testing)
  Future<void> showTestNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'event_countdown_test',
      'Test Notifications',
      channelDescription: 'For testing notification functionality',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(99999, title, body, details);
  }
}
