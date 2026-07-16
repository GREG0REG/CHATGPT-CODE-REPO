import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../db/database_helper.dart';
import '../models/custom_reminder.dart';
import '../models/event.dart';
import '../models/notification_history.dart';
import 'settings_service.dart';

/// Background handler for notification actions (snooze, dismiss).
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) {
  // Handle snooze actions in background
  if (response.actionId?.startsWith('snooze_') ?? false) {
    final minutesStr = response.actionId!.split('_')[1];
    final minutes = int.tryParse(minutesStr) ?? 5;
    final payload = response.payload;

    if (payload != null && payload.isNotEmpty) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        final title = parts[0];
        final body = parts[1];
        final idBase = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

        NotificationService.instance._scheduleSnooze(
          idBase: idBase,
          title: title,
          body: body,
          minutes: minutes,
        );
      }
    }
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification channels
  static const String _channelDefault = 'event_countdown_default';
  static const String _channelUrgent = 'event_countdown_urgent';
  static const String _channelAlarm = 'event_countdown_alarms';

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );

    // Create notification channels
    await _createChannels();

    // Android 13+ runtime notification permission.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelDefault,
        'Event Reminders',
        description: 'Standard event reminders',
        importance: Importance.high,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelUrgent,
        'Urgent Reminders',
        description: 'High priority reminders for imminent events',
        importance: Importance.max,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelAlarm,
        'Event Alarms',
        description: 'Full-screen alarm notifications',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  /// Two notification IDs per event: dayBefore = id*10+1, hourBefore = id*10+2
  int _dayBeforeId(int eventId) => eventId * 10 + 1;
  int _hourBeforeId(int eventId) => eventId * 10 + 2;
  int _customReminderId(int eventId, int reminderId) => eventId * 1000 + reminderId;

  Future<void> cancelForEvent(int eventId) async {
    await _plugin.cancel(_dayBeforeId(eventId));
    await _plugin.cancel(_hourBeforeId(eventId));
    // Cancel all custom reminders for this event
    final reminders = await DatabaseHelper.instance.getCustomRemindersForEvent(eventId);
    for (final r in reminders) {
      if (r.id != null) {
        await _plugin.cancel(_customReminderId(eventId, r.id!));
      }
    }
  }

  Future<void> scheduleForEvent(Event event) async {
    if (event.id == null) return;
    await cancelForEvent(event.id!);

    // Check quiet hours for immediate scheduling decisions
    final now = DateTime.now();
    final inQuietHours = await SettingsService.instance.isInQuietHours(now);

    // Which timestamp drives the reminders: start time if set, else deadline.
    final anchorMillis = event.startTimeMillis ?? event.deadlineMillis;
    if (anchorMillis == null) return;

    final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMillis);

    // ============================================
    // DEFAULT REMINDERS (preserved from Sessions 1-3)
    // ============================================
    final label = event.startTimeMillis != null ? 'starts' : 'deadline is';

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

    if (dayBefore.isAfter(now)) {
      await _scheduleAt(
        id: _dayBeforeId(event.id!),
        title: event.title,
        body: '${event.title} $label tomorrow',
        when: dayBefore,
        channelId: _channelDefault,
        payload: '${event.title}|${event.title} $label tomorrow|${event.id}',
      );
      await _logHistory(event, 'day_before');
    }

    if (hourBefore.isAfter(now)) {
      await _scheduleAt(
        id: _hourBeforeId(event.id!),
        title: event.title,
        body: '${event.title} $label in 1 hour',
        when: hourBefore,
        channelId: _channelUrgent,
        payload: '${event.title}|${event.title} $label in 1 hour|${event.id}',
      );
      await _logHistory(event, 'hour_before');
    }

    // ============================================
    // SESSION 4: Custom reminders
    // ============================================
    final customReminders = await DatabaseHelper.instance.getCustomRemindersForEvent(event.id!);
    for (final reminder in customReminders) {
      if (!reminder.isEnabled) continue;

      final reminderTime = anchor.subtract(Duration(minutes: reminder.minutesBefore));
      if (reminderTime.isAfter(now)) {
        final isAlarm = reminder.isAlarm;
        await _scheduleAt(
          id: _customReminderId(event.id!, reminder.id ?? 0),
          title: event.title,
          body: '${event.title} ${event.startTimeMillis != null ? 'starts' : 'deadline is'} '
              'in ${reminder.minutesBefore} minutes',
          when: reminderTime,
          channelId: isAlarm ? _channelAlarm : _channelUrgent,
          fullScreen: isAlarm,
          soundUri: reminder.soundUri,
          payload: '${event.title}|Custom reminder|${event.id}',
        );
        await _logHistory(event, 'custom_${reminder.minutesBefore}');
      }
    }
  }

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String channelId,
    bool fullScreen = false,
    String? soundUri,
    String? payload,
  }) async {
    // Skip if in quiet hours and not an alarm
    if (!fullScreen) {
      final inQuiet = await SettingsService.instance.isInQuietHours(when);
      if (inQuiet) return;
    }

    AndroidNotificationSound? sound;
    if (soundUri != null && soundUri.isNotEmpty) {
      sound = UriAndroidNotificationSound(soundUri);
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _channelAlarm ? 'Event Alarms' : 'Event Reminders',
      channelDescription: 'Reminders for upcoming events',
      importance: fullScreen ? Importance.max : Importance.high,
      priority: fullScreen ? Priority.max : Priority.high,
      fullScreenIntent: fullScreen,
      category: fullScreen ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      sound: sound,
      actions: fullScreen
          ? [
              const AndroidNotificationAction('dismiss', 'Dismiss'),
              const AndroidNotificationAction('snooze_5', 'Snooze 5m'),
              const AndroidNotificationAction('snooze_15', 'Snooze 15m'),
            ]
          : [
              const AndroidNotificationAction('snooze_5', 'Snooze 5m'),
              const AndroidNotificationAction('snooze_10', 'Snooze 10m'),
              const AndroidNotificationAction('snooze_30', 'Snooze 30m'),
            ],
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> _scheduleSnooze({
    required int idBase,
    required String title,
    required String body,
    required int minutes,
  }) async {
    final when = DateTime.now().add(Duration(minutes: minutes));
    await _scheduleAt(
      id: idBase + 99999, // Unique ID for snooze
      title: 'Snoozed: $title',
      body: body,
      when: when,
      channelId: _channelUrgent,
      payload: '$title|$body|$idBase',
    );
  }

  Future<void> _logHistory(Event event, String type) async {
    await DatabaseHelper.instance.insertNotificationHistory(
      NotificationHistory(
        eventId: event.id,
        eventTitle: event.title,
        reminderType: type,
        sentAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> rescheduleAll(List<Event> events) async {
    for (final e in events) {
      await scheduleForEvent(e);
    }
  }

  Future<void> showBatteryOptimizationDialog() async {
    // No-op: UI layer handles the dialog. This method exists for testing.
  }
}
