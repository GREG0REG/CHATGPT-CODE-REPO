// CHATGPT-CODE-REPO-TEST/lib/services/notification_service.dart

import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import '../models/event.dart';
import '../db/database_helper.dart';

// ============================================================================
// WORKMANAGER TASK NAMES
// ============================================================================
const String _taskDailyReminder = 'daily_reminder';
const String _taskPreClassAlert = 'pre_class_alert';
const String _taskWeeklySummary = 'weekly_summary';
const String _taskAssignmentDeadline = 'assignment_deadline';
const String _taskExamCountdown = 'exam_countdown';
const String _taskDangerAlert = 'danger_alert';

// ============================================================================
// NOTIFICATION CHANNEL IDs
// ============================================================================
const String _channelDaily = 'attendance_daily';
const String _channelPreClass = 'attendance_pre_class';
const String _channelDanger = 'attendance_danger';
const String _channelWeekly = 'attendance_weekly';
const String _channelAssignment = 'timetable_assignment';
const String _channelExam = 'timetable_exam';
const String _channelEvent = 'event_countdown_channel';
const String _channelTest = 'event_countdown_test';

// ============================================================================
// WORKMANAGER CALLBACK DISPATCHER (must be a top-level or static function)
// ============================================================================
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final service = NotificationService.instance;
    await service.init();

    switch (taskName) {
      case _taskDailyReminder:
        await service._showDailyReminder();
        break;
      case _taskPreClassAlert:
        final subjectName = inputData?['subjectName'] as String? ?? 'Class';
        final room = inputData?['room'] as String? ?? '';
        final scheduleId = inputData?['scheduleId'] as int? ?? 0;
        await service._showPreClassAlert(subjectName, room, scheduleId);
        break;
      case _taskWeeklySummary:
        await service._showWeeklySummary();
        break;
      case _taskAssignmentDeadline:
        final title = inputData?['title'] as String? ?? 'Assignment';
        final subjectName = inputData?['subjectName'] as String? ?? '';
        final taskId = inputData?['taskId'] as int? ?? 0;
        final minutesBefore = inputData?['minutesBefore'] as int? ?? 60;
        await service._showAssignmentDeadline(title, subjectName, taskId, minutesBefore);
        break;
      case _taskExamCountdown:
        final title = inputData?['title'] as String? ?? 'Exam';
        final daysRemaining = inputData?['daysRemaining'] as int? ?? 0;
        final entryId = inputData?['entryId'] as int? ?? 0;
        await service._showExamCountdown(title, daysRemaining, entryId);
        break;
      case _taskDangerAlert:
        final subjectName = inputData?['subjectName'] as String? ?? 'Subject';
        final percentage = inputData?['percentage'] as double? ?? 0.0;
        final canMiss = inputData?['canMiss'] as int? ?? 0;
        await service._showDangerAlert(subjectName, percentage, canMiss);
        break;
    }

    return Future.value(true);
  });
}

/// FIXED: Properly schedules notifications with exact alarm permissions,
/// graceful degradation, and Android 13+ compatibility.
/// ENHANCED: Smart attendance and timetable notifications via Workmanager.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================
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

    // Initialize Workmanager for background scheduling
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    _initialized = true;
  }

  // ==========================================================================
  // EVENT NOTIFICATIONS (ORIGINAL - ENHANCED)
  // ==========================================================================

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
        channelId: _channelEvent,
        channelName: 'Event Reminders',
        channelDesc: 'Reminders for upcoming events and deadlines',
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
        channelId: _channelEvent,
        channelName: 'Event Reminders',
        channelDesc: 'Reminders for upcoming events and deadlines',
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

  /// 1. Morning Daily Reminder (7:00 AM)
  /// "X classes today. Streak: Y days"
  Future<void> scheduleDailyReminder() async {
    await Workmanager().cancelByTag('daily_reminder');

    final now = DateTime.now();
    var next7AM = DateTime(now.year, now.month, now.day, 7, 0, 0);
    if (next7AM.isBefore(now)) {
      next7AM = next7AM.add(const Duration(days: 1));
    }

    await Workmanager().registerPeriodicTask(
      'daily_reminder_task',
      _taskDailyReminder,
      tag: 'daily_reminder',
      frequency: const Duration(hours: 24),
      initialDelay: next7AM.difference(now),
      constraints: Constraints(networkType: NetworkType.not_required),
    );

    debugPrint('Scheduled daily reminder starting at $next7AM');
  }

  Future<void> _showDailyReminder() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1=Monday, 7=Sunday

    // Get today's classes from attendance_schedules
    final schedules = await db.getAttendanceSchedulesForDay(dayOfWeek);
    final classCount = schedules.length;

    // Calculate streak from daily_goals or attendance_logs
    int streak = 0;
    try {
      streak = await _calculateAttendanceStreak();
    } catch (e) {
      debugPrint('Error calculating streak: $e');
    }

    String body;
    if (classCount == 0) {
      body = 'No classes today. Enjoy your day! 🔥 Streak: $streak days';
    } else if (classCount == 1) {
      body = '1 class today. 🔥 Streak: $streak days';
    } else {
      body = '$classCount classes today. 🔥 Streak: $streak days';
    }

    await _showNotification(
      id: 100001,
      title: '📚 Good Morning!',
      body: body,
      channelId: _channelDaily,
      channelName: 'Daily Attendance Reminder',
      channelDesc: 'Morning summary of your classes and attendance streak',
      importance: Importance.defaultImportance,
    );
  }

  Future<int> _calculateAttendanceStreak() async {
    final db = DatabaseHelper.instance;
    final allLogs = await db.getAllAttendanceLogs();
    if (allLogs.isEmpty) return 0;

    // Group logs by date
    final Map<int, List<Map<String, dynamic>>> logsByDate = {};
    for (final log in allLogs) {
      final date = log['dateMillis'] as int;
      final dayStart = DateTime.fromMillisecondsSinceEpoch(date);
      final dayKey = DateTime(dayStart.year, dayStart.month, dayStart.day).millisecondsSinceEpoch;
      logsByDate.putIfAbsent(dayKey, () => []).add(log);
    }

    // Sort dates descending
    final sortedDates = logsByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    int streak = 0;
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    for (final dateKey in sortedDates) {
      final date = DateTime.fromMillisecondsSinceEpoch(dateKey);
      final diff = checkDate.difference(date).inDays;

      if (diff > 1) break; // Gap in streak

      final dayLogs = logsByDate[dateKey]!;
      final hasPresent = dayLogs.any((l) => l['status'] == 'present');

      if (hasPresent) {
        streak++;
        checkDate = date.subtract(const Duration(days: 1));
      } else if (diff == 0) {
        // Today with no present yet - don't break streak, just don't count
        checkDate = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// 2. Pre-Class Alert (15 min before each class)
  /// "Subject in 15 min at Room"
  Future<void> schedulePreClassAlerts() async {
    // Cancel existing pre-class alerts
    await Workmanager().cancelByTag('pre_class');

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final dayOfWeek = now.weekday;

    // Get all active schedules for today
    final schedules = await db.getAttendanceSchedulesForDay(dayOfWeek);

    for (final schedule in schedules) {
      final startTimeMinutes = schedule['startTimeMinutes'] as int;
      final subjectId = schedule['subjectId'] as int;

      // Get subject name
      final subject = await db.getAttendanceSubjectById(subjectId);
      final subjectName = subject?['name'] as String? ?? 'Class';
      final room = schedule['room'] as String? ?? 'TBA';
      final scheduleId = schedule['id'] as int;

      // Calculate class start time today
      final hours = startTimeMinutes ~/ 60;
      final minutes = startTimeMinutes % 60;
      final classStart = DateTime(now.year, now.month, now.day, hours, minutes);
      final alertTime = classStart.subtract(const Duration(minutes: 15));

      // Only schedule if alert time is in the future
      if (alertTime.isAfter(now)) {
        final delay = alertTime.difference(now);

        await Workmanager().registerOneOffTask(
          'pre_class_$scheduleId',
          _taskPreClassAlert,
          tag: 'pre_class',
          initialDelay: delay,
          inputData: {
            'subjectName': subjectName,
            'room': room,
            'scheduleId': scheduleId,
          },
          constraints: Constraints(networkType: NetworkType.not_required),
        );

        debugPrint('Scheduled pre-class alert for $subjectName at $alertTime');
      }
    }
  }

  Future<void> _showPreClassAlert(String subjectName, String room, int scheduleId) async {
    await _showNotification(
      id: 200000 + scheduleId,
      title: '⏰ Class Starting Soon',
      body: '$subjectName in 15 min at $room',
      channelId: _channelPreClass,
      channelName: 'Pre-Class Alerts',
      channelDesc: 'Alerts 15 minutes before each scheduled class',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 3. Danger Alert (triggered after marking absent)
  /// "Subject at X%. You can miss only Y more"
  Future<void> triggerDangerAlert(String subjectName) async {
    final db = DatabaseHelper.instance;
    final stats = await db.getAttendanceStatsForSubject(subjectName);

    final total = (stats['total'] as int?) ?? 0;
    final present = (stats['present'] as int?) ?? 0;
    final absent = (stats['absent'] as int?) ?? 0;
    final late = (stats['late'] as int?) ?? 0;

    if (total == 0) return;

    // Calculate attendance percentage (count late as 0.5 present)
    final effectivePresent = present + (late * 0.5);
    final percentage = (effectivePresent / total) * 100;

    // Get subject requirements
    final subject = await db.getAttendanceSubjectByName(subjectName);
    final requiredPercentage = (subject?['requiredPercentage'] as num?)?.toDouble() ?? 75.0;

    // Calculate how many more can be missed
    // If current is P/A total T, required is R%
    // We need: (P + 0.5*L) / (T + x) >= R/100
    // Solving for max absences x: x <= (P + 0.5*L) / (R/100) - T
    final canMiss = max(0, ((effectivePresent / (requiredPercentage / 100)) - total).floor());

    // Only show danger alert if below or near threshold
    if (percentage < requiredPercentage + 10) {
      await Workmanager().registerOneOffTask(
        'danger_$subjectName',
        _taskDangerAlert,
        initialDelay: Duration.zero,
        inputData: {
          'subjectName': subjectName,
          'percentage': percentage,
          'canMiss': canMiss,
        },
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    }
  }

  Future<void> _showDangerAlert(String subjectName, double percentage, int canMiss) async {
    final db = DatabaseHelper.instance;
    final subject = await db.getAttendanceSubjectByName(subjectName);
    final requiredPercentage = (subject?['requiredPercentage'] as num?)?.toDouble() ?? 75.0;

    String body;
    if (percentage < requiredPercentage) {
      body = '⚠️ $subjectName at ${percentage.toStringAsFixed(1)}%. Required: ${requiredPercentage.toStringAsFixed(0)}%. You can miss only $canMiss more class(es)!';
    } else {
      body = '⚠️ $subjectName at ${percentage.toStringAsFixed(1)}%. You can miss only $canMiss more class(es) before dropping below ${requiredPercentage.toStringAsFixed(0)}%.';
    }

    await _showNotification(
      id: 300000 + subjectName.hashCode.abs() % 10000,
      title: '🚨 Attendance Warning',
      body: body,
      channelId: _channelDanger,
      channelName: 'Attendance Danger Alerts',
      channelDesc: 'Warnings when attendance drops near or below required percentage',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 4. Weekly Summary (Sunday 6:00 PM)
  /// "This week: X/Y classes. Z absences"
  Future<void> scheduleWeeklySummary() async {
    await Workmanager().cancelByTag('weekly_summary');

    final now = DateTime.now();
    var nextSunday = now.add(Duration(days: 7 - now.weekday));
    nextSunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 18, 0, 0);

    if (nextSunday.isBefore(now)) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }

    await Workmanager().registerPeriodicTask(
      'weekly_summary_task',
      _taskWeeklySummary,
      tag: 'weekly_summary',
      frequency: const Duration(days: 7),
      initialDelay: nextSunday.difference(now),
      constraints: Constraints(networkType: NetworkType.not_required),
    );

    debugPrint('Scheduled weekly summary for $nextSunday');
  }

  Future<void> _showWeeklySummary() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    // Get start of week (Monday) and end of week (Sunday)
    final daysSinceMonday = now.weekday - 1;
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final weekStartMillis = weekStart.millisecondsSinceEpoch;
    final weekEndMillis = weekEnd.millisecondsSinceEpoch;

    // Get all logs for this week
    final allLogs = await db.getAllAttendanceLogs();
    final weekLogs = allLogs.where((log) {
      final date = log['dateMillis'] as int;
      return date >= weekStartMillis && date < weekEndMillis;
    }).toList();

    final totalClasses = weekLogs.length;
    final presentCount = weekLogs.where((l) => l['status'] == 'present').length;
    final absentCount = weekLogs.where((l) => l['status'] == 'absent').length;
    final lateCount = weekLogs.where((l) => l['status'] == 'late').length;

    String body;
    if (totalClasses == 0) {
      body = 'No classes recorded this week.';
    } else {
      body = 'This week: $presentCount/$totalClasses attended. $absentCount absence(s), $lateCount late.';
    }

    await _showNotification(
      id: 400001,
      title: '📊 Weekly Attendance Summary',
      body: body,
      channelId: _channelWeekly,
      channelName: 'Weekly Summary',
      channelDesc: 'Weekly attendance summary every Sunday at 6 PM',
      importance: Importance.defaultImportance,
    );
  }

  // ==========================================================================
  // SMART TIMETABLE NOTIFICATIONS
  // ==========================================================================

  /// 5. Assignment Deadline Reminders (1 day before, 1 hour before)
  Future<void> scheduleAssignmentReminders() async {
    await Workmanager().cancelByTag('assignment');

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

      // 1 day before at 9:00 AM
      final dayBefore = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day - 1,
        9, 0, 0,
      );

      // 1 hour before
      final hourBefore = dueDate.subtract(const Duration(hours: 1));

      // Schedule day-before reminder
      if (dayBefore.isAfter(now)) {
        final delay = dayBefore.difference(now);
        await Workmanager().registerOneOffTask(
          'assign_day_$taskId',
          _taskAssignmentDeadline,
          tag: 'assignment',
          initialDelay: delay,
          inputData: {
            'title': title,
            'subjectName': subjectName,
            'taskId': taskId,
            'minutesBefore': 24 * 60,
          },
          constraints: Constraints(networkType: NetworkType.not_required),
        );
      }

      // Schedule hour-before reminder
      if (hourBefore.isAfter(now)) {
        final delay = hourBefore.difference(now);
        await Workmanager().registerOneOffTask(
          'assign_hour_$taskId',
          _taskAssignmentDeadline,
          tag: 'assignment',
          initialDelay: delay,
          inputData: {
            'title': title,
            'subjectName': subjectName,
            'taskId': taskId,
            'minutesBefore': 60,
          },
          constraints: Constraints(networkType: NetworkType.not_required),
        );
      }
    }
  }

  Future<void> _showAssignmentDeadline(String title, String subjectName, int taskId, int minutesBefore) async {
    String timeText;
    if (minutesBefore >= 24 * 60) {
      timeText = 'Due tomorrow';
    } else {
      timeText = 'Due in 1 hour';
    }

    final subjectPrefix = subjectName.isNotEmpty ? '[$subjectName] ' : '';

    await _showNotification(
      id: 500000 + taskId * 10 + (minutesBefore >= 24 * 60 ? 1 : 2),
      title: '📝 Assignment Reminder',
      body: '$timeText: $subjectPrefix$title',
      channelId: _channelAssignment,
      channelName: 'Assignment Deadlines',
      channelDesc: 'Reminders for assignment and task deadlines',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 6. Exam Countdown (7 days before, 1 day before)
  Future<void> scheduleExamCountdowns() async {
    await Workmanager().cancelByTag('exam');

    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    // Get exam entries from academic_calendar (type = 'exam')
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

      // 7 days before at 9:00 AM
      final sevenDaysBefore = DateTime(
        examDate.year,
        examDate.month,
        examDate.day - 7,
        9, 0, 0,
      );

      // 1 day before at 9:00 AM
      final oneDayBefore = DateTime(
        examDate.year,
        examDate.month,
        examDate.day - 1,
        9, 0, 0,
      );

      // Schedule 7-day countdown
      if (sevenDaysBefore.isAfter(now)) {
        final delay = sevenDaysBefore.difference(now);
        await Workmanager().registerOneOffTask(
          'exam_7d_$entryId',
          _taskExamCountdown,
          tag: 'exam',
          initialDelay: delay,
          inputData: {
            'title': name,
            'daysRemaining': 7,
            'entryId': entryId,
          },
          constraints: Constraints(networkType: NetworkType.not_required),
        );
      }

      // Schedule 1-day countdown
      if (oneDayBefore.isAfter(now)) {
        final delay = oneDayBefore.difference(now);
        await Workmanager().registerOneOffTask(
          'exam_1d_$entryId',
          _taskExamCountdown,
          tag: 'exam',
          initialDelay: delay,
          inputData: {
            'title': name,
            'daysRemaining': 1,
            'entryId': entryId,
          },
          constraints: Constraints(networkType: NetworkType.not_required),
        );
      }
    }
  }

  Future<void> _showExamCountdown(String title, int daysRemaining, int entryId) async {
    String body;
    if (daysRemaining == 7) {
      body = '📚 $title is in 7 days. Start preparing!';
    } else if (daysRemaining == 1) {
      body = '🔥 $title is tomorrow! Final review time.';
    } else {
      body = '$title in $daysRemaining days.';
    }

    await _showNotification(
      id: 600000 + entryId * 10 + daysRemaining,
      title: daysRemaining == 1 ? '🔥 Exam Tomorrow!' : '⏳ Exam Countdown',
      body: body,
      channelId: _channelExam,
      channelName: 'Exam Countdowns',
      channelDesc: 'Countdown reminders for upcoming exams',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  // ==========================================================================
  // MASTER SCHEDULE METHOD
  // ==========================================================================

  /// Call this to schedule ALL smart notifications at once.
  /// Best called at app startup and whenever attendance/timetable data changes.
  Future<void> scheduleAllSmartNotifications() async {
    await scheduleDailyReminder();
    await schedulePreClassAlerts();
    await scheduleWeeklySummary();
    await scheduleAssignmentReminders();
    await scheduleExamCountdowns();
    debugPrint('All smart notifications scheduled successfully');
  }

  /// Cancel all smart notifications (keep event notifications)
  Future<void> cancelAllSmartNotifications() async {
    await Workmanager().cancelByTag('daily_reminder');
    await Workmanager().cancelByTag('pre_class');
    await Workmanager().cancelByTag('weekly_summary');
    await Workmanager().cancelByTag('assignment');
    await Workmanager().cancelByTag('exam');
    debugPrint('All smart notifications cancelled');
  }

  // ==========================================================================
  // LOW-LEVEL NOTIFICATION HELPERS
  // ==========================================================================

  /// Show a simple immediate notification with custom channel
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: false,
    );

    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// FIXED: Use exactAllowWhileIdle with automatic fallback to inexact if permission denied.
  /// Also uses Importance.high instead of max to avoid Do Not Disturb blocking.
  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
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

    final details = NotificationDetails(android: androidDetails);

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

  /// Show immediate notification (for testing)
  Future<void> showTestNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      _channelTest,
      'Test Notifications',
      channelDescription: 'For testing notification functionality',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(99999, title, body, details);
  }
}
