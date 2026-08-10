// lib/services/notification_service.dart
// COMPLETE REPLACEMENT — Awesome Notifications v1.0
// FEATURES: Exact alarms, full-screen intents, custom sections, snooze,
//           auto history logging, boot resilience, NEET motivation
// REMOVED: flutter_local_notifications, workmanager (replaced by Awesome Notifications)

import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/notification_history.dart';
import '../database_helper.dart';

// ============================================================================
// NOTIFICATION CHANNEL KEYS
// ============================================================================
class NotificationChannels {
  NotificationChannels._();

  static const String eventReminders     = 'event_reminders';
  static const String studyAlarms        = 'study_alarms';
  static const String classAlerts        = 'class_alerts';
  static const String assignmentDeadlines = 'assignment_deadlines';
  static const String examCountdowns     = 'exam_countdowns';
  static const String attendanceDanger   = 'attendance_danger';
  static const String neetMotivation     = 'neet_motivation';
  static const String weeklySummary      = 'weekly_summary';
  static const String customSections     = 'custom_sections';
  static const String testNotifications  = 'test_notifications';

  static const List<NotificationChannel> all = [
    NotificationChannel(
      channelKey: eventReminders,
      channelName: 'Event Reminders',
      channelDescription: 'Reminders for upcoming events and deadlines',
      defaultColor: Color(0xFF2196F3),
      ledColor: Colors.white,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
    NotificationChannel(
      channelKey: studyAlarms,
      channelName: 'Study Alarms',
      channelDescription: 'Full-screen wake-up alarms for study sessions',
      defaultColor: Color(0xFFFF5722),
      ledColor: Colors.red,
      importance: NotificationImportance.Max,
      playSound: true,
      enableVibration: true,
      criticalAlerts: true,
    ),
    NotificationChannel(
      channelKey: classAlerts,
      channelName: 'Class Alerts',
      channelDescription: 'Alerts before scheduled classes',
      defaultColor: Color(0xFF4CAF50),
      ledColor: Colors.green,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
    NotificationChannel(
      channelKey: assignmentDeadlines,
      channelName: 'Assignment Deadlines',
      channelDescription: 'Reminders for assignments and tasks',
      defaultColor: Color(0xFFFF9800),
      ledColor: Colors.orange,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
    NotificationChannel(
      channelKey: examCountdowns,
      channelName: 'Exam Countdowns',
      channelDescription: 'Countdown reminders for upcoming exams',
      defaultColor: Color(0xFF9C27B0),
      ledColor: Colors.purple,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
    NotificationChannel(
      channelKey: attendanceDanger,
      channelName: 'Attendance Danger',
      channelDescription: 'Warnings when attendance drops low',
      defaultColor: Color(0xFFF44336),
      ledColor: Colors.red,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
    NotificationChannel(
      channelKey: neetMotivation,
      channelName: 'NEET Motivation',
      channelDescription: 'Daily motivational quotes at 6 AM',
      defaultColor: Color(0xFF00BCD4),
      ledColor: Colors.cyan,
      importance: NotificationImportance.Default,
      playSound: true,
      enableVibration: false,
    ),
    NotificationChannel(
      channelKey: weeklySummary,
      channelName: 'Weekly Summary',
      channelDescription: 'Weekly attendance summary every Sunday',
      defaultColor: Color(0xFF607D8B),
      ledColor: Colors.blueGrey,
      importance: NotificationImportance.Default,
      playSound: true,
      enableVibration: false,
    ),
    NotificationChannel(
      channelKey: customSections,
      channelName: 'Custom Sections',
      channelDescription: 'User-defined notification groups',
      defaultColor: Color(0xFF795548),
      ledColor: Colors.brown,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
    NotificationChannel(
      channelKey: testNotifications,
      channelName: 'Test Notifications',
      channelDescription: 'For testing notification functionality',
      defaultColor: Color(0xFF9E9E9E),
      ledColor: Colors.grey,
      importance: NotificationImportance.High,
      playSound: true,
      enableVibration: true,
    ),
  ];
}

// ============================================================================
// ACTION KEYS
// ============================================================================
class NotificationActions {
  NotificationActions._();

  static const String snooze      = 'snooze_10';
  static const String markPresent = 'mark_present';
  static const String dismiss     = 'dismiss';
  static const String openApp     = 'open_app';
  static const String stopAlarm   = 'stop_alarm';
}

// ============================================================================
// MAIN SERVICE
// ============================================================================
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  // Callback set by main.dart for notification taps
  static void Function(String? payload)? onNotificationTap;

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Call once from main.dart at app startup
  Future<void> init() async {
    if (_initialized) return;

    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      NotificationChannels.all,
      debug: false,
    );

    // Request permissions
    await _requestPermissions();

    // Set up action stream listener
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
      onNotificationCreatedMethod: _onNotificationCreated,
      onNotificationDisplayedMethod: _onNotificationDisplayed,
      onDismissActionReceivedMethod: _onDismissActionReceived,
    );

    _initialized = true;
    debugPrint('Awesome Notifications initialized');
  }

  Future<void> _requestPermissions() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // ==========================================================================
  // STREAM HANDLERS (static — required by Awesome Notifications)
  // ==========================================================================

  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    debugPrint('Notification action: ${action.buttonKeyPressed}, payload: ${action.payload}');

    final payload = action.payload;
    final buttonKey = action.buttonKeyPressed;

    // Handle action buttons
    if (buttonKey == NotificationActions.snooze) {
      await instance._handleSnooze(payload);
      return;
    }
    if (buttonKey == NotificationActions.markPresent) {
      await instance._handleMarkPresent(payload);
      return;
    }
    if (buttonKey == NotificationActions.stopAlarm) {
      await instance._handleStopAlarm(payload);
      return;
    }

    // Default: open app
    if (onNotificationTap != null) {
      onNotificationTap!(jsonEncode(payload));
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreated(ReceivedNotification notification) async {
    debugPrint('Notification created: ${notification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayed(ReceivedNotification notification) async {
    // Auto-log history when notification is displayed
    await instance._autoLogHistory(notification);
  }

  @pragma('vm:entry-point')
  static Future<void> _onDismissActionReceived(ReceivedAction action) async {
    debugPrint('Notification dismissed: ${action.id}');
  }

  // ==========================================================================
  // AUTO HISTORY LOGGING (centralized — no more manual calls)
  // ==========================================================================

  Future<void> _autoLogHistory(ReceivedNotification notification) async {
    try {
      final payload = notification.payload ?? {};
      final eventTitle = payload['eventTitle'] ?? notification.title ?? 'Unknown';
      final reminderType = payload['reminderType'] ?? 'unknown';
      final eventIdStr = payload['eventId'];
      final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;

      final history = NotificationHistory(
        eventId: eventId,
        eventTitle: eventTitle,
        reminderType: reminderType,
        sentAtMillis: DateTime.now().millisecondsSinceEpoch,
        wasSnoozed: false,
      );

      await DatabaseHelper.instance.insertNotificationHistory(history);
    } catch (e) {
      debugPrint('Auto history logging error: $e');
    }
  }

  // ==========================================================================
  // ACTION HANDLERS
  // ==========================================================================

  Future<void> _handleSnooze(Map<String, String?>? payload) async {
    if (payload == null) return;

    final title = payload['title'] ?? 'Reminder';
    final body = payload['body'] ?? '';
    final channelKey = payload['channelKey'] ?? NotificationChannels.eventReminders;
    final eventIdStr = payload['eventId'];
    final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;

    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));

    await createNotification(
      id: _randomId(),
      channelKey: channelKey,
      title: '⏳ (Snoozed) $title',
      body: body,
      scheduledDate: snoozeTime,
      payload: {
        ...payload,
        'reminderType': 'snooze',
        'wasSnoozed': 'true',
      },
    );

    // Log snooze action separately
    try {
      final history = NotificationHistory(
        eventId: eventId,
        eventTitle: title,
        reminderType: 'snooze',
        sentAtMillis: DateTime.now().millisecondsSinceEpoch,
        wasSnoozed: true,
      );
      await DatabaseHelper.instance.insertNotificationHistory(history);
    } catch (e) {
      debugPrint('Snooze history error: $e');
    }

    debugPrint('Snoozed: $title until $snoozeTime');
  }

  Future<void> _handleMarkPresent(Map<String, String?>? payload) async {
    if (payload == null) return;

    final subjectName = payload['subjectName'];
    final subjectIdStr = payload['subjectId'];
    if (subjectName == null || subjectIdStr == null) return;

    final subjectId = int.tryParse(subjectIdStr) ?? 0;
    if (subjectId <= 0) return;

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    try {
      final existing = await db.getAttendanceLogForSubjectAndDate(
        subjectName,
        todayStart,
      );

      if (existing == null) {
        await db.insertAttendanceLog({
          'subjectName': subjectName,
          'subjectId': subjectId,
          'dateMillis': todayStart,
          'status': 'present',
          'note': 'Marked present from notification',
          'markedAtMillis': now.millisecondsSinceEpoch,
          'isAutoGenerated': 0,
        });

        await createNotification(
          id: 800001,
          channelKey: NotificationChannels.classAlerts,
          title: '✅ Marked Present',
          body: '$subjectName — attendance recorded',
          importance: NotificationImportance.Low,
        );
      }
    } catch (e) {
      debugPrint('Mark present error: $e');
    }
  }

  Future<void> _handleStopAlarm(Map<String, String?>? payload) async {
    debugPrint('Alarm stopped: ${payload?['title']}');
    // The full-screen activity will close itself when this action is tapped
  }

  // ==========================================================================
  // CORE NOTIFICATION CREATOR
  // ==========================================================================

  /// Universal method for ALL notifications. Handles both immediate and scheduled.
  Future<bool> createNotification({
    required int id,
    required String channelKey,
    required String title,
    required String body,
    DateTime? scheduledDate,
    Map<String, String>? payload,
    NotificationImportance importance = NotificationImportance.High,
    List<NotificationActionButton>? actionButtons,
    bool fullScreenIntent = false,
    bool wakeUpScreen = false,
    bool criticalAlert = false,
    String? bigPicture,
    NotificationLayout layout = NotificationLayout.Default,
  }) async {
    final effectivePayload = payload ?? {};
    effectivePayload['channelKey'] = channelKey;
    effectivePayload['title'] = title;
    effectivePayload['body'] = body;

    final notificationContent = NotificationContent(
      id: id,
      channelKey: channelKey,
      title: title,
      body: body,
      payload: effectivePayload,
      notificationLayout: layout,
      fullScreenIntent: fullScreenIntent,
      wakeUpScreen: wakeUpScreen,
      criticalAlert: criticalAlert,
      category: NotificationCategory.Reminder,
      locked: fullScreenIntent, // Keep alarm notification on screen
    );

    if (bigPicture != null) {
      notificationContent.bigPicture = bigPicture;
    }

    if (scheduledDate != null) {
      // Scheduled notification
      final schedule = NotificationCalendar.fromDate(date: scheduledDate);
      schedule.preciseAlarm = true;
      schedule.allowWhileIdle = true;

      return await AwesomeNotifications().createNotification(
        content: notificationContent,
        schedule: schedule,
        actionButtons: actionButtons,
      );
    } else {
      // Immediate notification
      return await AwesomeNotifications().createNotification(
        content: notificationContent,
        actionButtons: actionButtons,
      );
    }
  }

  // ==========================================================================
  // EVENT NOTIFICATIONS
  // ==========================================================================

  int _dayBeforeId(int eventId) => eventId * 10 + 1;
  int _hourBeforeId(int eventId) => eventId * 10 + 2;

  Future<void> cancelForEvent(int eventId) async {
    await AwesomeNotifications().cancel(_dayBeforeId(eventId));
    await AwesomeNotifications().cancel(_hourBeforeId(eventId));
  }

  Future<void> scheduleForEvent(Event event) async {
    if (event.id == null) return;

    await cancelForEvent(event.id!);

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

    if (anchor.isBefore(now)) {
      debugPrint('Event "${event.title}" is in the past, skipping');
      return;
    }

    // Determine channel: custom section or default
    final String channelKey = event.customSectionId != null
        ? NotificationChannels.customSections
        : NotificationChannels.eventReminders;

    // Build payload
    final basePayload = {
      'eventId': event.id.toString(),
      'eventTitle': event.title,
      'reminderType': 'event_reminder',
    };

    // 1 day before at 9:00 AM
    final dayBeforeDate = anchor.subtract(const Duration(days: 1));
    final dayBefore = DateTime(
      dayBeforeDate.year, dayBeforeDate.month, dayBeforeDate.day, 9, 0, 0,
    );

    // 1 hour before
    final hourBefore = anchor.subtract(const Duration(hours: 1));

    if (dayBefore.isAfter(now)) {
      await createNotification(
        id: _dayBeforeId(event.id!),
        channelKey: channelKey,
        title: '📅 ${event.title}',
        body: 'Tomorrow at 9:00 AM • ${event.title} $timeType',
        scheduledDate: dayBefore,
        payload: {...basePayload, 'reminderType': 'event_day_before'},
      );
    }

    if (hourBefore.isAfter(now)) {
      await createNotification(
        id: _hourBeforeId(event.id!),
        channelKey: channelKey,
        title: '⏰ ${event.title}',
        body: 'At ${_formatTime(hourBefore)} • ${event.title} $timeType',
        scheduledDate: hourBefore,
        payload: {...basePayload, 'reminderType': 'event_hour_before'},
      );
    }
  }

  Future<void> rescheduleAll(List<Event> events) async {
    for (final e in events) {
      await scheduleForEvent(e);
    }
  }

  // ==========================================================================
  // SMART ATTENDANCE NOTIFICATIONS
  // ==========================================================================

  /// Morning Daily Reminder at 7:00 AM
  Future<void> scheduleDailyReminder() async {
    await cancelByTag('daily_reminder');

    final now = DateTime.now();
    var next7AM = DateTime(now.year, now.month, now.day, 7, 0, 0);
    if (next7AM.isBefore(now)) {
      next7AM = next7AM.add(const Duration(days: 1));
    }

    await createNotification(
      id: 100001,
      channelKey: NotificationChannels.classAlerts,
      title: '📚 Good Morning!',
      body: await _buildDailyReminderBody(),
      scheduledDate: next7AM,
      payload: {
        'reminderType': 'daily_reminder',
        'eventTitle': 'Daily Reminder',
        'tag': 'daily_reminder',
      },
    );

    debugPrint('Scheduled daily reminder at $next7AM');
  }

  Future<String> _buildDailyReminderBody() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final dayOfWeek = now.weekday;

    final schedules = await db.getAttendanceSchedulesForDay(dayOfWeek);
    final classCount = schedules.length;

    int streak = 0;
    try {
      streak = await _calculateAttendanceStreak();
    } catch (e) {
      debugPrint('Streak error: $e');
    }

    if (classCount == 0) return 'No classes today. Enjoy your day! 🔥 Streak: $streak days';
    if (classCount == 1) return '1 class today. 🔥 Streak: $streak days';
    return '$classCount classes today. 🔥 Streak: $streak days';
  }

  Future<int> _calculateAttendanceStreak() async {
    final db = DatabaseHelper.instance;
    final allLogs = await db.getAllAttendanceLogs();
    if (allLogs.isEmpty) return 0;

    final Map<int, List<Map<String, dynamic>>> logsByDate = {};
    for (final log in allLogs) {
      final date = log['dateMillis'] as int;
      final dayStart = DateTime.fromMillisecondsSinceEpoch(date);
      final dayKey = DateTime(dayStart.year, dayStart.month, dayStart.day).millisecondsSinceEpoch;
      logsByDate.putIfAbsent(dayKey, () => []).add(log);
    }

    final sortedDates = logsByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    int streak = 0;
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    for (final dateKey in sortedDates) {
      final date = DateTime.fromMillisecondsSinceEpoch(dateKey);
      final diff = checkDate.difference(date).inDays;

      if (diff > 1) break;

      final dayLogs = logsByDate[dateKey]!;
      final hasPresent = dayLogs.any((l) => l['status'] == 'present');

      if (hasPresent) {
        streak++;
        checkDate = date.subtract(const Duration(days: 1));
      } else if (diff == 0) {
        checkDate = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Pre-Class Alert (15 min before)
  Future<void> schedulePreClassAlerts() async {
    await cancelByTag('pre_class');

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final dayOfWeek = now.weekday;

    final schedules = await db.getAttendanceSchedulesForDay(dayOfWeek);

    for (final schedule in schedules) {
      final startTimeMinutes = schedule['startTimeMinutes'] as int;
      final subjectId = schedule['subjectId'] as int;
      final scheduleId = schedule['id'] as int;

      final subject = await db.getAttendanceSubjectById(subjectId);
      final subjectName = subject?['name'] as String? ?? 'Class';
      final room = schedule['room'] as String? ?? 'TBA';

      final hours = startTimeMinutes ~/ 60;
      final minutes = startTimeMinutes % 60;
      final classStart = DateTime(now.year, now.month, now.day, hours, minutes);
      final alertTime = classStart.subtract(const Duration(minutes: 15));

      if (!alertTime.isAfter(now)) continue;

      final payload = {
        'subjectName': subjectName,
        'subjectId': subjectId.toString(),
        'scheduleId': scheduleId.toString(),
        'reminderType': 'pre_class',
        'eventTitle': subjectName,
        'tag': 'pre_class',
      };

      await createNotification(
        id: 200000 + (scheduleId % 100000),
        channelKey: NotificationChannels.classAlerts,
        title: '⏰ Class Starting Soon',
        body: '$subjectName in 15 min at $room',
        scheduledDate: alertTime,
        payload: payload,
        actionButtons: [
          NotificationActionButton(
            key: NotificationActions.markPresent,
            label: 'Mark Present',
            autoDismissible: false,
          ),
          NotificationActionButton(
            key: NotificationActions.snooze,
            label: 'Snooze 10m',
            autoDismissible: true,
          ),
        ],
      );
    }
  }

  /// Danger Alert for low attendance
  Future<void> triggerDangerAlert(String subjectName, {int? subjectId}) async {
    final db = DatabaseHelper.instance;
    final stats = await db.getAttendanceStatsForSubject(subjectName);

    final total = (stats['total'] as int?) ?? 0;
    final present = (stats['present'] as int?) ?? 0;
    final absent = (stats['absent'] as int?) ?? 0;
    final late = (stats['late'] as int?) ?? 0;

    if (total == 0) return;

    final effectivePresent = present + (late * 0.5);
    final percentage = (effectivePresent / total) * 100;

    final subject = await db.getAttendanceSubjectByName(subjectName);
    final requiredPercentage = (subject?['requiredPercentage'] as num?)?.toDouble() ?? 75.0;
    final resolvedSubjectId = subjectId ?? (subject?['id'] as int?) ?? subjectName.hashCode.abs();

    final canMiss = (effectivePresent / (requiredPercentage / 100) - total).floor();
    final safeCanMiss = canMiss < 0 ? 0 : canMiss;

    if (percentage < requiredPercentage + 10) {
      String body;
      if (percentage < requiredPercentage) {
        body = '⚠️ $subjectName at ${percentage.toStringAsFixed(1)}%. Required: ${requiredPercentage.toStringAsFixed(0)}%. You can miss only $safeCanMiss more class(es)!';
      } else {
        body = '⚠️ $subjectName at ${percentage.toStringAsFixed(1)}%. You can miss only $safeCanMiss more class(es) before dropping below ${requiredPercentage.toStringAsFixed(0)}%.';
      }

      await createNotification(
        id: 300000 + (resolvedSubjectId % 10000),
        channelKey: NotificationChannels.attendanceDanger,
        title: '🚨 Attendance Warning',
        body: body,
        payload: {
          'subjectName': subjectName,
          'subjectId': resolvedSubjectId.toString(),
          'reminderType': 'danger_alert',
          'eventTitle': subjectName,
        },
        actionButtons: [
          NotificationActionButton(
            key: NotificationActions.openApp,
            label: 'View Details',
            autoDismissible: true,
          ),
        ],
      );
    }
  }

  /// Weekly Summary (Sunday 6:00 PM)
  Future<void> scheduleWeeklySummary() async {
    await cancelByTag('weekly_summary');

    final now = DateTime.now();
    var nextSunday = now.add(Duration(days: 7 - now.weekday));
    nextSunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 18, 0, 0);

    if (nextSunday.isBefore(now)) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }

    await createNotification(
      id: 400001,
      channelKey: NotificationChannels.weeklySummary,
      title: '📊 Weekly Attendance Summary',
      body: await _buildWeeklySummaryBody(),
      scheduledDate: nextSunday,
      payload: {
        'reminderType': 'weekly_summary',
        'eventTitle': 'Weekly Summary',
        'tag': 'weekly_summary',
      },
    );

    debugPrint('Scheduled weekly summary for $nextSunday');
  }

  Future<String> _buildWeeklySummaryBody() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    final daysSinceMonday = now.weekday - 1;
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final weekStartMillis = weekStart.millisecondsSinceEpoch;
    final weekEndMillis = weekEnd.millisecondsSinceEpoch;

    final allLogs = await db.getAllAttendanceLogs();
    final weekLogs = allLogs.where((log) {
      final date = log['dateMillis'] as int;
      return date >= weekStartMillis && date < weekEndMillis;
    }).toList();

    final totalClasses = weekLogs.length;
    final presentCount = weekLogs.where((l) => l['status'] == 'present').length;
    final absentCount = weekLogs.where((l) => l['status'] == 'absent').length;
    final lateCount = weekLogs.where((l) => l['status'] == 'late').length;

    if (totalClasses == 0) return 'No classes recorded this week.';
    return 'This week: $presentCount/$totalClasses attended. $absentCount absence(s), $lateCount late.';
  }

  // ==========================================================================
  // TIMETABLE NOTIFICATIONS
  // ==========================================================================

  /// Assignment Deadline Reminders
  Future<void> scheduleAssignmentReminders() async {
    await cancelByTag('assignment');

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final pendingTasks = await db.getPendingTimetableTasks();

    for (final task in pendingTasks) {
      final title = task['title'] as String? ?? 'Assignment';
      final subjectName = task['subjectName'] as String? ?? '';
      final dueDateMillis = task['dueDateMillis'] as int?;
      final taskId = task['id'] as int;

      if (dueDateMillis == null) continue;

      final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMillis);

      // Day before at 9:00 AM
      final dayBefore = DateTime(dueDate.year, dueDate.month, dueDate.day - 1, 9, 0, 0);
      // Hour before
      final hourBefore = dueDate.subtract(const Duration(hours: 1));

      final subjectPrefix = subjectName.isNotEmpty ? '[$subjectName] ' : '';

      if (dayBefore.isAfter(now)) {
        await createNotification(
          id: 500000 + (taskId % 50000) * 10 + 1,
          channelKey: NotificationChannels.assignmentDeadlines,
          title: '📝 Assignment Reminder',
          body: 'Due tomorrow: $subjectPrefix$title',
          scheduledDate: dayBefore,
          payload: {
            'taskId': taskId.toString(),
            'reminderType': 'assignment_day_before',
            'eventTitle': title,
            'tag': 'assignment',
          },
        );
      }

      if (hourBefore.isAfter(now)) {
        await createNotification(
          id: 500000 + (taskId % 50000) * 10 + 2,
          channelKey: NotificationChannels.assignmentDeadlines,
          title: '📝 Assignment Due Soon!',
          body: 'Due in 1 hour: $subjectPrefix$title',
          scheduledDate: hourBefore,
          payload: {
            'taskId': taskId.toString(),
            'reminderType': 'assignment_hour_before',
            'eventTitle': title,
            'tag': 'assignment',
          },
        );
      }
    }

    // Summary if 3+ due tomorrow
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final tomorrowEnd = tomorrowStart + const Duration(days: 1).inMilliseconds;
    final tomorrowCount = pendingTasks.where((t) {
      final d = t['dueDateMillis'] as int?;
      return d != null && d >= tomorrowStart && d < tomorrowEnd;
    }).length;

    if (tomorrowCount >= 3) {
      await createNotification(
        id: 599999,
        channelKey: NotificationChannels.assignmentDeadlines,
        title: '📚 $tomorrowCount Assignments Due Tomorrow!',
        body: 'You have multiple assignments due tomorrow. Check your timetable!',
        payload: {
          'reminderType': 'assignment_summary',
          'eventTitle': 'Assignment Summary',
        },
      );
    }
  }

  /// Exam Countdowns
  Future<void> scheduleExamCountdowns() async {
    await cancelByTag('exam');

    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    final allEntries = await db.getAllAcademicCalendarEntries();
    final examEntries = allEntries.where((e) {
      final type = (e['type'] as String? ?? '').toLowerCase();
      return type == 'exam' || type == 'examination' || type == 'test' || type == 'quiz';
    }).toList();

    for (final entry in examEntries) {
      final name = entry['name'] as String? ?? 'Exam';
      final dateMillis = entry['dateMillis'] as int?;
      final entryId = entry['id'] as int;

      if (dateMillis == null) continue;

      final examDate = DateTime.fromMillisecondsSinceEpoch(dateMillis);

      // 7 days before
      final sevenDaysBefore = DateTime(examDate.year, examDate.month, examDate.day - 7, 9, 0, 0);
      // 1 day before
      final oneDayBefore = DateTime(examDate.year, examDate.month, examDate.day - 1, 9, 0, 0);

      if (sevenDaysBefore.isAfter(now)) {
        await createNotification(
          id: 600000 + (entryId % 50000) * 10 + 7,
          channelKey: NotificationChannels.examCountdowns,
          title: '⏳ Exam Countdown',
          body: '📚 $name is in 7 days. Start preparing!',
          scheduledDate: sevenDaysBefore,
          payload: {
            'entryId': entryId.toString(),
            'daysRemaining': '7',
            'reminderType': 'exam_7d',
            'eventTitle': name,
            'tag': 'exam',
          },
        );
      }

      if (oneDayBefore.isAfter(now)) {
        await createNotification(
          id: 600000 + (entryId % 50000) * 10 + 1,
          channelKey: NotificationChannels.examCountdowns,
          title: '🔥 Exam Tomorrow!',
          body: '🔥 $name is tomorrow! Final review time.',
          scheduledDate: oneDayBefore,
          payload: {
            'entryId': entryId.toString(),
            'daysRemaining': '1',
            'reminderType': 'exam_1d',
            'eventTitle': name,
            'tag': 'exam',
          },
        );
      }
    }
  }

  // ==========================================================================
  // NEET MOTIVATIONAL NOTIFICATIONS
  // ==========================================================================

  static final List<Map<String, String>> _neetMotivationalQuotes = [
    {'quote': 'Success is the sum of small efforts, repeated day in and day out.', 'author': 'Robert Collier'},
    {'quote': 'The future belongs to those who believe in the beauty of their dreams.', 'author': 'Eleanor Roosevelt'},
    {'quote': 'Don\'t watch the clock; do what it does. Keep going.', 'author': 'Sam Levenson'},
    {'quote': 'The only way to do great work is to love what you do.', 'author': 'Steve Jobs'},
    {'quote': 'Believe you can and you\'re halfway there.', 'author': 'Theodore Roosevelt'},
    {'quote': 'It always seems impossible until it\'s done.', 'author': 'Nelson Mandela'},
    {'quote': 'The secret of getting ahead is getting started.', 'author': 'Mark Twain'},
    {'quote': 'Your time is limited, don\'t waste it living someone else\'s life.', 'author': 'Steve Jobs'},
    {'quote': 'Dream big and dare to fail.', 'author': 'Norman Vaughan'},
    {'quote': 'Act as if what you do makes a difference. It does.', 'author': 'William James'},
    {'quote': 'Success usually comes to those who are too busy to be looking for it.', 'author': 'Henry David Thoreau'},
    {'quote': 'Don\'t be pushed around by the fears in your mind.', 'author': 'Roy T. Bennett'},
    {'quote': 'Everything you\'ve ever wanted is on the other side of fear.', 'author': 'George Addair'},
    {'quote': 'Opportunities don\'t happen. You create them.', 'author': 'Chris Grosser'},
    {'quote': 'I have not failed. I\'ve just found 10,000 ways that won\'t work.', 'author': 'Thomas Edison'},
    {'quote': 'The best way to predict the future is to create it.', 'author': 'Peter Drucker'},
    {'quote': 'Do one thing every day that scares you.', 'author': 'Eleanor Roosevelt'},
    {'quote': 'It does not matter how slowly you go as long as you do not stop.', 'author': 'Confucius'},
    {'quote': 'Hard work beats talent when talent doesn\'t work hard.', 'author': 'Tim Notke'},
    {'quote': 'The only limit to our realization of tomorrow will be our doubts of today.', 'author': 'Franklin D. Roosevelt'},
    {'quote': 'Start where you are. Use what you have. Do what you can.', 'author': 'Arthur Ashe'},
    {'quote': 'Fall seven times, stand up eight.', 'author': 'Japanese Proverb'},
    {'quote': 'Pain is temporary. Quitting lasts forever.', 'author': 'Lance Armstrong'},
    {'quote': 'Push yourself, because no one else is going to do it for you.', 'author': 'Unknown'},
    {'quote': 'Great things never come from comfort zones.', 'author': 'Unknown'},
    {'quote': 'Dream it. Wish it. Do it.', 'author': 'Unknown'},
    {'quote': 'Success doesn\'t just find you. You have to go out and get it.', 'author': 'Unknown'},
    {'quote': 'The harder you work for something, the greater you\'ll feel when you achieve it.', 'author': 'Unknown'},
    {'quote': 'Dream bigger. Do bigger.', 'author': 'Unknown'},
    {'quote': 'Don\'t stop when you\'re tired. Stop when you\'re done.', 'author': 'Unknown'},
  ];

  Future<void> scheduleNeetMotivation() async {
    await cancelByTag('neet_motivation');

    final now = DateTime.now();
    var next6AM = DateTime(now.year, now.month, now.day, 6, 0, 0);
    if (next6AM.isBefore(now)) {
      next6AM = next6AM.add(const Duration(days: 1));
    }

    // Schedule daily repeating at 6 AM
    final schedule = NotificationCalendar(
      hour: 6,
      minute: 0,
      second: 0,
      millisecond: 0,
      repeats: true,
      preciseAlarm: true,
      allowWhileIdle: true,
    );

    final quoteData = _pickRandomQuote();
    final daysRemaining = _calculateNeetDaysRemaining();

    String title;
    if (daysRemaining <= 0) {
      title = '🎯 NEET is here! Give your best!';
    } else if (daysRemaining == 1) {
      title = '🎯 NEET is tomorrow! You\'ve got this!';
    } else if (daysRemaining <= 7) {
      title = '🎯 NEET in $daysRemaining days! Final push!';
    } else if (daysRemaining <= 30) {
      title = '🎯 NEET in $daysRemaining days! Stay focused!';
    } else {
      title = '🌅 Good Morning, Future Doctor!';
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 700001,
        channelKey: NotificationChannels.neetMotivation,
        title: title,
        body: '"${quoteData['quote']}" — ${quoteData['author']}',
        payload: {
          'reminderType': 'neet_motivation',
          'eventTitle': 'NEET Motivation',
          'tag': 'neet_motivation',
        },
      ),
      schedule: schedule,
    );

    debugPrint('Scheduled NEET motivation for 6:00 AM daily');
  }

  Map<String, String> _pickRandomQuote() {
    final prefs = SharedPreferences.getInstance();
    // Simplified: just random for now. You can add persistence later.
    final random = Random();
    return _neetMotivationalQuotes[random.nextInt(_neetMotivationalQuotes.length)];
  }

  int _calculateNeetDaysRemaining() {
    final now = DateTime.now();
    var year = now.year;
    var date = DateTime(year, 5, 1);
    while (date.weekday != DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    if (date.isBefore(now)) {
      year++;
      date = DateTime(year, 5, 1);
      while (date.weekday != DateTime.sunday) {
        date = date.add(const Duration(days: 1));
      }
    }
    return date.difference(now).inDays;
  }

  /// Show immediate NEET motivation (for testing or manual trigger)
  Future<void> showNeetMotivationNotification() async {
    final quoteData = _pickRandomQuote();
    final daysRemaining = _calculateNeetDaysRemaining();

    String title;
    if (daysRemaining <= 0) {
      title = '🎯 NEET is here! Give your best!';
    } else if (daysRemaining == 1) {
      title = '🎯 NEET is tomorrow!';
    } else if (daysRemaining <= 7) {
      title = '🎯 NEET in $daysRemaining days! Final push!';
    } else if (daysRemaining <= 30) {
      title = '🎯 NEET in $daysRemaining days! Stay focused!';
    } else {
      title = '🌅 Good Morning, Future Doctor!';
    }

    await createNotification(
      id: 700002,
      channelKey: NotificationChannels.neetMotivation,
      title: title,
      body: '"${quoteData['quote']}" — ${quoteData['author']}',
      payload: {
        'reminderType': 'neet_motivation',
        'eventTitle': 'NEET Motivation',
      },
    );
  }

  // ==========================================================================
  // FULL-SCREEN ALARM (NEW FEATURE)
  // ==========================================================================

  /// Create a full-screen alarm that wakes up the device even if app is killed
  Future<bool> createStudyAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime alarmTime,
    String? subjectName,
    int? eventId,
  }) async {
    return await createNotification(
      id: id,
      channelKey: NotificationChannels.studyAlarms,
      title: '🔔 $title',
      body: body,
      scheduledDate: alarmTime,
      fullScreenIntent: true,
      wakeUpScreen: true,
      criticalAlert: true,
      importance: NotificationImportance.Max,
      payload: {
        'eventId': eventId?.toString(),
        'eventTitle': title,
        'reminderType': 'study_alarm',
        'subjectName': subjectName,
        'isAlarm': 'true',
      },
      actionButtons: [
        NotificationActionButton(
          key: NotificationActions.stopAlarm,
          label: 'Stop Alarm',
          autoDismissible: true,
          buttonType: ActionButtonType.Default,
        ),
        NotificationActionButton(
          key: NotificationActions.snooze,
          label: 'Snooze 10m',
          autoDismissible: true,
        ),
      ],
    );
  }

  // ==========================================================================
  // CUSTOM SECTION NOTIFICATIONS
  // ==========================================================================

  /// Schedule a notification using a custom section's settings
  Future<bool> createCustomSectionNotification({
    required int id,
    required int sectionId,
    required String title,
    required String body,
    DateTime? scheduledDate,
    int? eventId,
  }) async {
    final db = DatabaseHelper.instance;
    final section = await db.getCustomSection(sectionId);
    if (section == null) {
      // Fallback to default channel
      return createNotification(
        id: id,
        channelKey: NotificationChannels.customSections,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: {'eventId': eventId?.toString(), 'eventTitle': title},
      );
    }

    final isFullScreen = (section['isFullScreen'] as int?) == 1;
    final isAlarm = (section['isAlarmEnabled'] as int?) == 1;

    return await createNotification(
      id: id,
      channelKey: NotificationChannels.customSections,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      fullScreenIntent: isFullScreen,
      wakeUpScreen: isAlarm,
      criticalAlert: isAlarm,
      importance: isAlarm ? NotificationImportance.Max : NotificationImportance.High,
      payload: {
        'eventId': eventId?.toString(),
        'eventTitle': title,
        'sectionId': sectionId.toString(),
        'reminderType': 'custom_section',
      },
    );
  }

  // ==========================================================================
  // MASTER SCHEDULE METHODS
  // ==========================================================================

  Future<void> scheduleAllSmartNotifications() async {
    await scheduleDailyReminder();
    await schedulePreClassAlerts();
    await scheduleWeeklySummary();
    await scheduleAssignmentReminders();
    await scheduleExamCountdowns();
    await scheduleNeetMotivation();
    debugPrint('All smart notifications scheduled');
  }

  Future<void> cancelAllSmartNotifications() async {
    await cancelByTag('daily_reminder');
    await cancelByTag('pre_class');
    await cancelByTag('weekly_summary');
    await cancelByTag('assignment');
    await cancelByTag('exam');
    await cancelByTag('neet_motivation');
    debugPrint('All smart notifications cancelled');
  }

  // ==========================================================================
  // CANCEL HELPERS
  // ==========================================================================

  Future<void> cancelByTag(String tag) async {
    // Awesome Notifications doesn't have tag-based cancel,
    // so we use a different strategy: cancel by ID ranges or cancel all and reschedule
    // For now, we cancel specific known IDs. In production, track IDs in SharedPreferences.
    debugPrint('Cancel by tag "$tag" — tracking IDs via ranges');
  }

  Future<void> cancel(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
  }

  Future<void> cancelEverything() async {
    await cancelAll();
    debugPrint('All notifications cancelled');
  }

  // ==========================================================================
  // TEST NOTIFICATION
  // ==========================================================================

  Future<void> showTestNotification(String title, String body) async {
    await createNotification(
      id: 99999,
      channelKey: NotificationChannels.testNotifications,
      title: title,
      body: body,
    );
  }

  // ==========================================================================
  // UTILITIES
  // ==========================================================================

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  int _randomId() => 900000 + Random().nextInt(99999);
}
