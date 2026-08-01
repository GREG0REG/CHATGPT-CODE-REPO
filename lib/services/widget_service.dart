import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../theme/app_themes.dart';
import 'countdown_service.dart';
import 'settings_service.dart';

/// Enum for widget background types.
enum WidgetBackgroundType { themeColor, customImage }

/// Pushes data into home_widget SharedPreferences and triggers native updates.
/// COMPLETE REPLACEMENT — v5: Multi-habit widget with per-day completion fix
class WidgetService {
  WidgetService._();

  // ── Android Provider Names ──
  static const String eventWidgetName = 'EventCountdownWidgetProvider';
  static const String pomodoroWidgetName = 'PomodoroWidgetProvider';
  static const String attendanceWidgetName = 'AttendanceWidgetProvider';
  static const String timetableWidgetName = 'TimetableWidgetProvider';
  static const String habitWidgetName = 'HabitWidgetProvider';
  static const String readingWidgetName = 'ReadingWidgetProvider';

  // ── Event Widget Keys ──
  static const _kEventTitle = 'event_title';
  static const _kEventCountdown = 'countdown_text';
  static const _kEventBgType = 'widget_bg_type';
  static const _kEventBgColor = 'widget_bg_color';
  static const _kEventTextColor = 'widget_text_color';
  static const _kEventImagePath = 'widget_image_path';
  static const _kEventProgressPercent = 'widget_progress_percent';
  static const _kEventPulseEnabled = 'widget_pulse_enabled';
  static const _kEventIsUrgent = 'widget_is_urgent';

  // ── Pomodoro Widget Keys ──
  static const _kPomPhase = 'pomodoro_phase';
  static const _kPomTimerText = 'pomodoro_timer_text';
  static const _kPomStatus = 'pomodoro_status';
  static const _kPomSubject = 'pomodoro_subject';
  static const _kPomTopic = 'pomodoro_topic';
  static const _kPomProgress = 'pomodoro_progress_percent';
  static const _kPomSessions = 'pomodoro_sessions';
  static const _kPomDistractions = 'pomodoro_distractions';
  static const _kPomDailyMinutes = 'pomodoro_daily_minutes';
  static const _kPomDailyGoal = 'pomodoro_daily_goal';
  static const _kPomNeetDays = 'pomodoro_neet_days';
  static const _kPomNextSubject = 'pomodoro_next_subject';

  // ── Attendance Widget Keys ──
  static const _kAttSubjectCount = 'attendance_subject_count';
  static const _kAttPrefixName = 'attendance_subject_name_';
  static const _kAttPrefixPercent = 'attendance_subject_percent_';
  static const _kAttPrefixPresent = 'attendance_subject_present_';
  static const _kAttPrefixAbsent = 'attendance_subject_absent_';
  static const _kAttPrefixLate = 'attendance_subject_late_';
  static const _kAttPrefixExcused = 'attendance_subject_excused_';
  static const _kAttPrefixTotal = 'attendance_subject_total_';
  static const _kAttPrefixColor = 'attendance_subject_color_';
  static const _kAttPrefixStatus = 'attendance_subject_status_';
  static const _kAttPrefixStreak = 'attendance_subject_streak_';
  static const _kAttPrefixCanMiss = 'attendance_subject_can_miss_';

  // ── Timetable Widget Keys ──
  static const _kTtClassCount = 'timetable_class_count';
  static const _kTtPrefixSubject = 'timetable_subject_';
  static const _kTtPrefixTime = 'timetable_time_';
  static const _kTtPrefixRoom = 'timetable_room_';
  static const _kTtPrefixColor = 'timetable_color_';

  // ── Habit Widget Keys ──
  static const _kHabitCount = 'habit_count';
  static const _kHabitPrefixName = 'habit_name_';
  static const _kHabitPrefixStreak = 'habit_streak_';
  static const _kHabitPrefixProgress = 'habit_progress_';
  static const _kHabitPrefixColor = 'habit_color_';
  // NEW v5: Per-day completion booleans for correct dot mapping
  static const _kHabitPrefixDay = 'habit_day_';
  static const _kHabitPrefixCompleted = 'habit_completed_';
  static const _kHabitPrefixTarget = 'habit_target_';

  // ── Reading Widget Keys ──
  static const _kReadBookCount = 'reading_book_count';
  static const _kReadTotalBooksAdded = 'reading_total_books_added';
  static const _kReadTotalPagesToday = 'reading_total_pages_today';
  static const _kReadTotalMinutesToday = 'reading_total_minutes_today';
  static const _kReadStreakDays = 'reading_streak_days';
  static const _kReadReadToday = 'reading_read_today';
  static const _kReadPrefixTitle = 'reading_title_';
  static const _kReadPrefixProgress = 'reading_progress_';
  static const _kReadPrefixPages = 'reading_pages_';
  static const _kReadPrefixColor = 'reading_color_';
  static const _kReadPrefixSubject = 'reading_subject_';
  static const _kReadPrefixStatus = 'reading_status_';
  static const _kReadPrefixPagesPerDay = 'reading_pages_per_day_';
  static const _kReadPrefixEstDate = 'reading_est_date_';
  static const _kReadPrefixReadToday = 'reading_read_today_';
  static const _kReadPrefixIsUrgent = 'reading_is_urgent_';

  // ── NEET Countdown Widget Keys ──
  static const _kNeetDays = 'neet_countdown_days';
  static const _kNeetHours = 'neet_countdown_hours';
  static const _kNeetMinutes = 'neet_countdown_minutes';
  static const _kNeetExamDate = 'neet_exam_date_millis';
  static const _kNeetIsUrgent = 'neet_is_urgent';
  static const _kNeetProgress = 'neet_progress_percent';

  // ── Subject Streak Widget Keys ──
  static const _kSubStreakPhysics = 'subject_streak_physics';
  static const _kSubStreakChemistry = 'subject_streak_chemistry';
  static const _kSubStreakBiology = 'subject_streak_biology';
  static const _kSubStreakGeneral = 'subject_streak_general';
  static const _kSubStreakBest = 'subject_streak_best';

  // ── MCQ Target Widget Keys ──
  static const _kMcqTarget = 'mcq_daily_target';
  static const _kMcqAttempted = 'mcq_daily_attempted';
  static const _kMcqCorrect = 'mcq_daily_correct';
  static const _kMcqAccuracy = 'mcq_daily_accuracy';
  static const _kMcqSubject = 'mcq_daily_subject';

  // ── Revision Round Widget Keys ──
  static const _kRevRound = 'revision_current_round';
  static const _kRevRoundLabel = 'revision_round_label';
  static const _kRevPhysicsRound = 'revision_physics_round';
  static const _kRevChemistryRound = 'revision_chemistry_round';
  static const _kRevBiologyRound = 'revision_biology_round';

  // ═════════════════════════════════════════════════════════════════
  // HELPER: Get SharedPreferences directly
  // ═════════════════════════════════════════════════════════════════

  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  /// Helper to get a color for a theme option.
  static Color _colorFor(AppThemeOption theme) {
    return AppThemes.getPrimaryColor(theme);
  }

  /// Helper to compute an auto-contrast color (black or white) for readability.
  static Color _autoContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // ═════════════════════════════════════════════════════════════════
  // EVENT COUNTDOWN WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      final active = CountdownService.getActiveEvent(events, now);

      final smart = await SettingsService.instance.getSmartFormatEnabled();
      final theme = await SettingsService.instance.getSelectedTheme();
      final bgTypeStr = await SettingsService.instance.getWidgetBackgroundType();
      final imagePath = await SettingsService.instance.getWidgetImagePath();
      final progressBarEnabled = await SettingsService.instance.getWidgetProgressBar();
      final pulseEnabled = await SettingsService.instance.getWidgetPulseAnimation();

      String title;
      String countdownText;
      int progressPercent = -1;
      bool isUrgent = false;

      if (active == null) {
        title = 'No upcoming events';
        countdownText = '';
      } else {
        title = active.title;
        countdownText = CountdownService.buildCountdownText(
          active,
          now,
          smartFormatEnabled: smart,
        ).text;

        if (progressBarEnabled) {
          final start = active.startTimeMillis ?? active.dateMillis;
          final deadline = active.deadlineMillis ?? active.startTimeMillis ?? active.dateMillis;

          if (deadline > start) {
            final total = deadline - start;
            final elapsed = now.millisecondsSinceEpoch - start;
            progressPercent = ((elapsed / total) * 100).clamp(0, 100).toInt();
          } else if (active.dateMillis > 0) {
            final total = active.dateMillis - now.millisecondsSinceEpoch;
            progressPercent = total > 0 ? 0 : 100;
          }
        }

        final target = active.deadlineMillis ?? active.startTimeMillis ?? active.dateMillis;
        final diff = Duration(milliseconds: target - now.millisecondsSinceEpoch);
        isUrgent = diff.inHours < 24 && !diff.isNegative;
      }

      final themeColor = _colorFor(theme);
      final textColor = _autoContrastColor(themeColor);

      await HomeWidget.saveWidgetData(_kEventTitle, title);
      await HomeWidget.saveWidgetData(_kEventCountdown, countdownText);
      await HomeWidget.saveWidgetData(
        _kEventBgType,
        bgTypeStr == 'customImage' ? 'image' : 'theme',
      );
      await HomeWidget.saveWidgetData(
        _kEventBgColor,
        themeColor.value.toString(),
      );
      await HomeWidget.saveWidgetData(
        _kEventTextColor,
        textColor.value.toString(),
      );
      if (imagePath != null && bgTypeStr == 'customImage') {
        await HomeWidget.saveWidgetData(_kEventImagePath, imagePath);
      } else {
        await HomeWidget.saveWidgetData(_kEventImagePath, '');
      }
      await HomeWidget.saveWidgetData(_kEventProgressPercent, progressPercent);
      await HomeWidget.saveWidgetData(_kEventPulseEnabled, pulseEnabled);
      await HomeWidget.saveWidgetData(_kEventIsUrgent, isUrgent);

      await HomeWidget.updateWidget(
        name: eventWidgetName,
        androidName: eventWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService.refreshWidget error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // POMODORO WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshPomodoroWidget() async {
    try {
      final prefs = await _getPrefs();
      final phase = prefs.getString('pomodoro_phase') ?? 'idle';
      final endTime = prefs.getInt('pomodoro_end_time_millis') ?? 0;
      final totalDuration = prefs.getInt('pomodoro_total_duration_seconds') ?? 5400;
      final subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      final status = prefs.getString('pomodoro_status') ?? 'Ready';
      final sessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;
      final topicTag = prefs.getString('pomodoro_topic_tag');
      final distractionCount = prefs.getInt('pomodoro_distraction_count') ?? 0;
      final nextSubject = prefs.getString('pomodoro_next_subject');
      final dailyMinutes = prefs.getInt('pomodoro_daily_minutes') ?? 0;
      final dailyGoal = prefs.getInt('pomodoro_daily_goal_minutes') ?? 360;

      final remainingSeconds = _calculateRemainingTime(endTime);
      final timerText = _formatPomodoroTimerText(phase, remainingSeconds, endTime, prefs);
      final progress = _calculatePomodoroProgress(phase, remainingSeconds, totalDuration, prefs);
      final neetDays = _calculateNeetDaysRemaining();

      await HomeWidget.saveWidgetData(_kPomPhase, phase);
      await HomeWidget.saveWidgetData(_kPomTimerText, timerText);
      await HomeWidget.saveWidgetData(_kPomStatus, status);
      await HomeWidget.saveWidgetData(_kPomSubject, subject);
      await HomeWidget.saveWidgetData(_kPomTopic, topicTag);
      await HomeWidget.saveWidgetData(_kPomProgress, progress);
      await HomeWidget.saveWidgetData(_kPomSessions, sessions);
      await HomeWidget.saveWidgetData(_kPomDistractions, distractionCount);
      await HomeWidget.saveWidgetData(_kPomDailyMinutes, dailyMinutes);
      await HomeWidget.saveWidgetData(_kPomDailyGoal, dailyGoal);
      await HomeWidget.saveWidgetData(_kPomNeetDays, neetDays);
      await HomeWidget.saveWidgetData(_kPomNextSubject, nextSubject);

      await HomeWidget.updateWidget(
        name: pomodoroWidgetName,
        androidName: pomodoroWidgetName,
      );

      debugPrint('Pomodoro widget data saved: phase=$phase, timer=$timerText, progress=$progress');
    } catch (e) {
      debugPrint('WidgetService.refreshPomodoroWidget error: $e');
    }
  }

  static int _calculateRemainingTime(int endTimeMillis) {
    if (endTimeMillis <= 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = ((endTimeMillis - now) / 1000).toInt();
    return remaining.clamp(0, 999999);
  }

  static String _formatPomodoroTimerText(String phase, int remainingSeconds, int endTime, SharedPreferences prefs) {
    if (phase == 'idle') return 'Tap to Start';
    if (phase == 'paused') {
      final savedRemaining = prefs.getInt('pomodoro_remaining_seconds') ?? 0;
      return _formatTime(savedRemaining);
    }
    if (remainingSeconds <= 0 && endTime > 0) return '00:00';
    return _formatTime(remainingSeconds);
  }

  static String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static int _calculatePomodoroProgress(String phase, int remainingSeconds, int totalDuration, SharedPreferences prefs) {
    if (phase == 'idle') return 0;
    if (phase == 'paused') return prefs.getInt('pomodoro_progress_percent') ?? 0;
    if (remainingSeconds <= 0) return 100;
    if (totalDuration > 0) {
      return ((totalDuration - remainingSeconds) / totalDuration * 100).toInt().clamp(0, 100);
    }
    return 0;
  }

  static int _calculateNeetDaysRemaining() {
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
    final diff = date.difference(now).inDays;
    return diff.clamp(0, 999);
  }

  // ═════════════════════════════════════════════════════════════════
  // ATTENDANCE WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshAttendanceWidget() async {
    try {
      final subjects = await DatabaseHelper.instance.getAllAttendanceSubjects();
      final subjectData = <Map<String, dynamic>>[];

      for (final row in subjects) {
        final id = (row['id'] as int?) ?? 0;
        final name = row['name'] as String;
        final requiredPct = (row['requiredPercentage'] as num?)?.toDouble() ?? 75.0;
        final colorHex = row['colorHex'] as String? ?? '#4CAF50';

        final stats = await DatabaseHelper.instance.getAttendanceStatsForSubject(name);
        final present = (stats['present'] as int?) ?? 0;
        final absent = (stats['absent'] as int?) ?? 0;
        final late = (stats['late'] as int?) ?? 0;
        final excused = (stats['excused'] as int?) ?? 0;
        final total = (stats['total'] as int?) ?? 0;

        final effectiveTotal = total - excused;
        final attended = present + (late * 0.5);
        final percentage = effectiveTotal > 0
            ? ((attended / effectiveTotal) * 100).toInt()
            : 0;

        String statusText;
        int canMiss = 0;
        if (effectiveTotal == 0) {
          statusText = 'No data yet';
        } else if (requiredPct >= 100.0) {
          statusText = percentage >= 99 ? 'Perfect attendance!' : '100% required — attend all';
        } else if (percentage >= requiredPct) {
          canMiss = ((effectiveTotal * (requiredPct / 100) - absent) / (1 - requiredPct / 100)).floor();
          canMiss = canMiss.clamp(0, 999);
          statusText = 'Can miss $canMiss more';
        } else {
          final needAttend = ((requiredPct / 100 * effectiveTotal - attended) / (requiredPct / 100)).ceil();
          statusText = 'Need $needAttend more';
        }

        final streak = await _calculateStreakForSubject(name);

        subjectData.add({
          'name': name,
          'percentage': percentage,
          'present': present,
          'absent': absent,
          'late': late,
          'excused': excused,
          'total': total,
          'effectiveTotal': effectiveTotal,
          'color': colorHex,
          'status': statusText,
          'streak': streak,
          'canMiss': canMiss,
        });
      }

      subjectData.sort((a, b) => (a['percentage'] as int).compareTo(b['percentage'] as int));

      await HomeWidget.saveWidgetData(_kAttSubjectCount, subjectData.length);

      for (int i = 0; i < subjectData.length && i < 5; i++) {
        final s = subjectData[i];
        await HomeWidget.saveWidgetData(_kAttPrefixName + '$i', s['name'] as String);
        await HomeWidget.saveWidgetData(_kAttPrefixPercent + '$i', s['percentage'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixPresent + '$i', s['present'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixAbsent + '$i', s['absent'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixLate + '$i', s['late'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixExcused + '$i', s['excused'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixTotal + '$i', s['total'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixColor + '$i', s['color'] as String);
        await HomeWidget.saveWidgetData(_kAttPrefixStatus + '$i', s['status'] as String);
        await HomeWidget.saveWidgetData(_kAttPrefixStreak + '$i', s['streak'] as int);
        await HomeWidget.saveWidgetData(_kAttPrefixCanMiss + '$i', s['canMiss'] as int);
      }

      await HomeWidget.updateWidget(
        name: attendanceWidgetName,
        androidName: attendanceWidgetName,
      );

      debugPrint('Attendance widget data saved: ${subjectData.length} subjects');
    } catch (e) {
      debugPrint('WidgetService.refreshAttendanceWidget error: $e');
    }
  }

  static Future<int> _calculateStreakForSubject(String subjectName) async {
    final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subjectName);
    final sortedLogs = logs.where((l) => l['subjectName'] == subjectName).toList()
      ..sort((a, b) => ((b['dateMillis'] as int?) ?? 0).compareTo((a['dateMillis'] as int?) ?? 0));

    if (sortedLogs.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();
    var expectedDate = DateTime(now.year, now.month, now.day);

    for (final log in sortedLogs) {
      final logDate = DateTime.fromMillisecondsSinceEpoch((log['dateMillis'] as int?) ?? 0);
      final normalizedLog = DateTime(logDate.year, logDate.month, logDate.day);

      if (normalizedLog == expectedDate) {
        final status = log['status'] as String? ?? '';
        if (status == 'present' || status == 'late') {
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else if (normalizedLog.isBefore(expectedDate)) {
        break;
      }
    }

    return streak;
  }

  // ═════════════════════════════════════════════════════════════════
  // TIMETABLE WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshTimetableWidget() async {
    try {
      final now = DateTime.now();
      final dayOfWeek = now.weekday;
      final classes = await DatabaseHelper.instance.getTimetableClassesForDay(dayOfWeek);

      classes.sort((a, b) =>
          (a['startTimeMinutes'] as int).compareTo(b['startTimeMinutes'] as int));

      await HomeWidget.saveWidgetData(_kTtClassCount, classes.length.clamp(0, 5));

      for (int i = 0; i < classes.length && i < 5; i++) {
        final c = classes[i];
        final subjectName = c['subjectName'] as String? ?? 'Class';
        final startMin = (c['startTimeMinutes'] as int?) ?? 0;
        final endMin = (c['endTimeMinutes'] as int?) ?? 0;
        final room = c['room'] as String? ?? '';
        final color = c['colorHex'] as String? ?? '#2196F3';

        final startH = (startMin ~/ 60).toString().padLeft(2, '0');
        final startM = (startMin % 60).toString().padLeft(2, '0');
        final endH = (endMin ~/ 60).toString().padLeft(2, '0');
        final endM = (endMin % 60).toString().padLeft(2, '0');
        final timeStr = '$startH:$startM - $endH:$endM';

        await HomeWidget.saveWidgetData(_kTtPrefixSubject + '$i', subjectName);
        await HomeWidget.saveWidgetData(_kTtPrefixTime + '$i', timeStr);
        await HomeWidget.saveWidgetData(_kTtPrefixRoom + '$i', room);
        await HomeWidget.saveWidgetData(_kTtPrefixColor + '$i', color);
      }

      await HomeWidget.updateWidget(
        name: timetableWidgetName,
        androidName: timetableWidgetName,
      );

      debugPrint('Timetable widget data saved: ${classes.length} classes');
    } catch (e) {
      debugPrint('WidgetService.refreshTimetableWidget error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // HABIT WIDGET — v5: MULTI-HABIT + PER-DAY COMPLETION FIX
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshHabitWidget() async {
    try {
      final habits = await DatabaseHelper.instance.getAllHabits();
      final habitData = <Map<String, dynamic>>[];
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekStartMillis = weekStart.millisecondsSinceEpoch;

      for (final habit in habits) {
        final id = (habit['id'] as int?) ?? 0;
        final name = habit['name'] as String? ?? 'Habit';
        final color = habit['colorHex'] as String? ?? '#4CAF50';
        final targetPerWeek = (habit['targetPerWeek'] as int?) ?? 7;

        final streak = await DatabaseHelper.instance.getHabitStreak(id);

        // ── FIX: Get per-day completion for Mon-Sun (indices 0-6) ──
        final weekCompletion = <bool>[];
        int completedThisWeek = 0;
        for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
          final day = weekStart.add(Duration(days: dayIndex));
          final dayMillis = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
          final log = await DatabaseHelper.instance.getHabitLogForDate(id, dayMillis);
          final isDone = log != null && (log['completed'] as int? ?? 0) == 1;
          weekCompletion.add(isDone);
          if (isDone) completedThisWeek++;
        }

        final progress = targetPerWeek > 0
            ? ((completedThisWeek / targetPerWeek) * 100).round().clamp(0, 100)
            : 0;

        habitData.add({
          'id': id,
          'name': name,
          'streak': streak,
          'progress': progress,
          'color': color,
          'targetPerWeek': targetPerWeek,
          'completedThisWeek': completedThisWeek,
          'weekCompletion': weekCompletion, // List<bool> length 7 (Mon-Sun)
        });
      }

      // Sort by streak descending (priority: higher streak = more important)
      habitData.sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));

      final displayCount = habitData.length.clamp(0, 7);
      await HomeWidget.saveWidgetData(_kHabitCount, displayCount);

      for (int i = 0; i < displayCount; i++) {
        final h = habitData[i];
        await HomeWidget.saveWidgetData(_kHabitPrefixName + '$i', h['name'] as String);
        await HomeWidget.saveWidgetData(_kHabitPrefixStreak + '$i', h['streak'] as int);
        await HomeWidget.saveWidgetData(_kHabitPrefixProgress + '$i', h['progress'] as int);
        await HomeWidget.saveWidgetData(_kHabitPrefixColor + '$i', h['color'] as String);
        await HomeWidget.saveWidgetData(_kHabitPrefixCompleted + '$i', h['completedThisWeek'] as int);
        await HomeWidget.saveWidgetData(_kHabitPrefixTarget + '$i', h['targetPerWeek'] as int);

        // Save per-day booleans: habit_day_0_0 = habit 0, Monday
        final weekCompletion = h['weekCompletion'] as List<bool>;
        for (int d = 0; d < 7; d++) {
          await HomeWidget.saveWidgetData(
            '${_kHabitPrefixDay}${i}_$d',
            weekCompletion[d],
          );
        }
      }

      // Clear old data beyond current count
      for (int i = displayCount; i < 10; i++) {
        await HomeWidget.saveWidgetData(_kHabitPrefixName + '$i', null);
        for (int d = 0; d < 7; d++) {
          await HomeWidget.saveWidgetData('${_kHabitPrefixDay}${i}_$d', null);
        }
      }

      await HomeWidget.updateWidget(
        name: habitWidgetName,
        androidName: habitWidgetName,
      );

      debugPrint('Habit widget data saved: $displayCount habits with per-day mapping');
    } catch (e) {
      debugPrint('WidgetService.refreshHabitWidget error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // READING WIDGET — ENHANCED v4: Multi-book, NEET features, vertical resize
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshReadingWidget() async {
    try {
      final allBooks = await DatabaseHelper.instance.getAllReadingBooks(includeCompleted: true);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

      // Separate active and completed
      final activeBooks = allBooks.where((b) => (b['isCompleted'] as int? ?? 0) == 0).toList();
      final completedBooks = allBooks.where((b) => (b['isCompleted'] as int? ?? 0) == 1).toList();

      // ── SMART SORTING FOR NEET: Priority = Urgency > Deadline proximity > Progress ──
      final bookData = <Map<String, dynamic>>[];
      final processedBookIds = <int>{};

      // Helper: compute NEET metrics for a book
      Map<String, dynamic> computeBookMetrics(Map<String, dynamic> book) {
        final bookId = (book['id'] as int?) ?? 0;
        final title = (book['title'] as String?) ?? 'Book';
        final totalPages = (book['totalPages'] as int?) ?? 1;
        final currentPage = (book['currentPage'] as int?) ?? 0;
        final color = book['colorHex'] as String? ?? '#2196F3';
        final subject = (book['subjectName'] as String?) ?? '';
        final targetEndDateMillis = book['targetEndDateMillis'] as int?;
        final startDateMillis = (book['startDateMillis'] as int?) ?? now.millisecondsSinceEpoch;
        final isCompleted = (book['isCompleted'] as int? ?? 0) == 1;

        final progress = totalPages > 0
            ? ((currentPage / totalPages) * 100).round().clamp(0, 100)
            : 0;

        final pagesLeft = totalPages - currentPage;

        // Calculate pages per day needed
        int pagesPerDayNeeded = 0;
        String estCompletionDate = '';
        bool isUrgent = false;
        bool isBehind = false;

        if (!isCompleted && targetEndDateMillis != null && pagesLeft > 0) {
          final targetDate = DateTime.fromMillisecondsSinceEpoch(targetEndDateMillis);
          final daysLeft = targetDate.difference(now).inDays;
          if (daysLeft > 0) {
            pagesPerDayNeeded = (pagesLeft / daysLeft).ceil();
            isUrgent = pagesPerDayNeeded > 50;
            isBehind = pagesPerDayNeeded > 30;
          } else if (daysLeft <= 0 && pagesLeft > 0) {
            pagesPerDayNeeded = 999; // Overdue
            isUrgent = true;
            isBehind = true;
          }

          // Estimate completion date based on average pace
          final totalMinutes = (book['totalMinutesRead'] as int?) ?? 0;
          final avgPace = totalMinutes > 0 && currentPage > 0
              ? currentPage / totalMinutes
              : 0.5; // Default 0.5 pages/min = 30 pages/hour
          if (avgPace > 0 && pagesLeft > 0) {
            final estMinutes = pagesLeft / avgPace;
            final estDate = now.add(Duration(minutes: estMinutes.ceil()));
            estCompletionDate = '${estDate.day}/${estDate.month}';
          }
        }

        // Today's reading for this book
        int pagesReadToday = 0;
        int minutesReadToday = 0;
        try {
          final sessions = await DatabaseHelper.instance.getReadingSessionsForBook(bookId);
          for (final session in sessions) {
            final sessionDate = session['sessionDateMillis'] as int? ?? 0;
            if (sessionDate >= todayStart && sessionDate < todayEnd) {
              pagesReadToday += (session['pagesRead'] as int?) ?? 0;
              minutesReadToday += (session['minutesRead'] as int?) ?? 0;
            }
          }
        } catch (_) {}

        // Determine status text
        String status;
        if (isCompleted) {
          status = 'Completed';
        } else if (currentPage == 0) {
          status = 'Not Started';
        } else if (isUrgent) {
          status = 'Behind';
        } else if (pagesReadToday > 0) {
          status = 'Goal met';
        } else {
          status = 'On Track';
        }

        return {
          'id': bookId,
          'title': title,
          'progress': progress,
          'pages': '$currentPage / $totalPages',
          'color': color,
          'subject': subject,
          'status': status,
          'pagesPerDayNeeded': pagesPerDayNeeded,
          'estCompletionDate': estCompletionDate,
          'pagesReadToday': pagesReadToday,
          'minutesReadToday': minutesReadToday,
          'readToday': pagesReadToday > 0,
          'isUrgent': isUrgent,
          'isBehind': isBehind,
          'isCompleted': isCompleted,
          'pagesLeft': pagesLeft,
          'targetEndDateMillis': targetEndDateMillis,
          'currentPage': currentPage,
          'totalPages': totalPages,
        };
      }

      // Process all active books
      for (final book in activeBooks) {
        final metrics = await computeBookMetrics(book);
        bookData.add(metrics);
        processedBookIds.add(metrics['id'] as int);
      }

      // Sort active books: Urgent first, then by deadline proximity, then by progress
      bookData.sort((a, b) {
        // Completed books go to bottom
        final aCompleted = (a['isCompleted'] as bool?) ?? false;
        final bCompleted = (b['isCompleted'] as bool?) ?? false;
        if (aCompleted && !bCompleted) return 1;
        if (!aCompleted && bCompleted) return -1;

        // Urgent books first
        final aUrgent = (a['isUrgent'] as bool?) ?? false;
        final bUrgent = (b['isUrgent'] as bool?) ?? false;
        if (aUrgent && !bUrgent) return -1;
        if (!aUrgent && bUrgent) return 1;

        // Behind schedule next
        final aBehind = (a['isBehind'] as bool?) ?? false;
        final bBehind = (b['isBehind'] as bool?) ?? false;
        if (aBehind && !bBehind) return -1;
        if (!aBehind && bBehind) return 1;

        // Then by deadline proximity (null deadlines last)
        final aDeadline = a['targetEndDateMillis'] as int?;
        final bDeadline = b['targetEndDateMillis'] as int?;
        if (aDeadline != null && bDeadline != null) {
          return aDeadline.compareTo(bDeadline);
        }
        if (aDeadline != null) return -1;
        if (bDeadline != null) return 1;

        // Finally by progress descending
        return (b['progress'] as int).compareTo(a['progress'] as int);
      });

      // If more than 10 books, keep top 10 most important
      final displayBooks = bookData.length > 10 ? bookData.sublist(0, 10) : bookData;

      // Calculate aggregate stats
      int totalPagesToday = 0;
      int totalMinutesToday = 0;
      int booksReadToday = 0;
      for (final b in displayBooks) {
        totalPagesToday += (b['pagesReadToday'] as int?) ?? 0;
        totalMinutesToday += (b['minutesReadToday'] as int?) ?? 0;
        if ((b['readToday'] as bool?) ?? false) booksReadToday++;
      }

      // Calculate reading streak (consecutive days with any reading)
      int streakDays = 0;
      try {
        streakDays = await _calculateReadingStreak();
      } catch (_) {}

      final bool readToday = booksReadToday > 0;

      // Save aggregate data
      await HomeWidget.saveWidgetData(_kReadBookCount, displayBooks.length);
      await HomeWidget.saveWidgetData(_kReadTotalBooksAdded, allBooks.length);
      await HomeWidget.saveWidgetData(_kReadTotalPagesToday, totalPagesToday);
      await HomeWidget.saveWidgetData(_kReadTotalMinutesToday, totalMinutesToday);
      await HomeWidget.saveWidgetData(_kReadStreakDays, streakDays);
      await HomeWidget.saveWidgetData(_kReadReadToday, readToday);

      // Save each book's data
      for (int i = 0; i < displayBooks.length; i++) {
        final b = displayBooks[i];
        await HomeWidget.saveWidgetData(_kReadPrefixTitle + '$i', b['title'] as String);
        await HomeWidget.saveWidgetData(_kReadPrefixProgress + '$i', b['progress'] as int);
        await HomeWidget.saveWidgetData(_kReadPrefixPages + '$i', b['pages'] as String);
        await HomeWidget.saveWidgetData(_kReadPrefixColor + '$i', b['color'] as String);
        await HomeWidget.saveWidgetData(_kReadPrefixSubject + '$i', b['subject'] as String);
        await HomeWidget.saveWidgetData(_kReadPrefixStatus + '$i', b['status'] as String);
        await HomeWidget.saveWidgetData(_kReadPrefixPagesPerDay + '$i', b['pagesPerDayNeeded'] as int);
        await HomeWidget.saveWidgetData(_kReadPrefixEstDate + '$i', b['estCompletionDate'] as String);
        await HomeWidget.saveWidgetData(_kReadPrefixReadToday + '$i', b['readToday'] as bool);
        await HomeWidget.saveWidgetData(_kReadPrefixIsUrgent + '$i', b['isUrgent'] as bool);
      }

      // Clear any old book data beyond current count
      for (int i = displayBooks.length; i < 15; i++) {
        await HomeWidget.saveWidgetData(_kReadPrefixTitle + '$i', null);
        await HomeWidget.saveWidgetData(_kReadPrefixProgress + '$i', null);
        await HomeWidget.saveWidgetData(_kReadPrefixPages + '$i', null);
      }

      await HomeWidget.updateWidget(
        name: readingWidgetName,
        androidName: readingWidgetName,
      );

      debugPrint('Reading widget data saved: ${displayBooks.length} books, $totalPagesToday pages today, streak=$streakDays');
    } catch (e) {
      debugPrint('WidgetService.refreshReadingWidget error: $e');
      // Don't rethrow — prevent widget crash
    }
  }

  /// Calculate consecutive days of reading streak
  static Future<int> _calculateReadingStreak() async {
    try {
      final now = DateTime.now();
      int streak = 0;

      for (int i = 0; i < 365; i++) {
        final day = now.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
        final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;

        final sessions = await DatabaseHelper.instance.getReadingSessionsForDateRange(dayStart, dayEnd);
        final hasReading = sessions.isNotEmpty;

        if (hasReading) {
          streak++;
        } else {
          // If today has no reading yet, don't break streak (allow current day)
          if (i == 0) {
            // Check if it's still early in the day — be lenient
            continue;
          }
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('_calculateReadingStreak error: $e');
      return 0;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // NEET COUNTDOWN WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshNeetCountdownWidget() async {
    try {
      final prefs = await _getPrefs();
      final neetDateMs = prefs.getInt('neet_exam_date_millis');

      final now = DateTime.now();
      final examDate = neetDateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(neetDateMs)
          : _getDefaultNeetDate();

      final today = DateTime(now.year, now.month, now.day);
      final exam = DateTime(examDate.year, examDate.month, examDate.day);
      final diff = exam.difference(today);

      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      final isUrgent = days <= 30 && days >= 0;

      final totalPrepDays = 365;
      final progress = days >= 0
          ? (((totalPrepDays - days) / totalPrepDays) * 100).round().clamp(0, 100)
          : 100;

      await HomeWidget.saveWidgetData(_kNeetDays, days);
      await HomeWidget.saveWidgetData(_kNeetHours, hours);
      await HomeWidget.saveWidgetData(_kNeetMinutes, minutes);
      await HomeWidget.saveWidgetData(_kNeetExamDate, examDate.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData(_kNeetIsUrgent, isUrgent);
      await HomeWidget.saveWidgetData(_kNeetProgress, progress);

      await HomeWidget.updateWidget(
        name: 'NeetCountdownWidgetProvider',
        androidName: 'NeetCountdownWidgetProvider',
      );

      debugPrint('NEET countdown widget saved: $days days remaining');
    } catch (e) {
      debugPrint('WidgetService.refreshNeetCountdownWidget error: $e');
    }
  }

  static DateTime _getDefaultNeetDate() {
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
    return date;
  }

  // ═════════════════════════════════════════════════════════════════
  // SUBJECT STREAK WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshSubjectStreakWidget() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

      final sessions = await DatabaseHelper.instance
          .getStudySessionsForDateRange(todayStart, todayEnd);

      int physicsCount = 0;
      int chemistryCount = 0;
      int biologyCount = 0;
      int generalCount = 0;

      for (final session in sessions) {
        final neetSubject = session.neetSubject;
        switch (neetSubject) {
          case 0:
            physicsCount++;
            break;
          case 1:
            chemistryCount++;
            break;
          case 2:
            biologyCount++;
            break;
          default:
            generalCount++;
            break;
        }
      }

      final physicsStreak = await _calculateSubjectStudyStreak(0);
      final chemistryStreak = await _calculateSubjectStudyStreak(1);
      final biologyStreak = await _calculateSubjectStudyStreak(2);
      final generalStreak = await _calculateSubjectStudyStreak(3);

      final bestStreak = [physicsStreak, chemistryStreak, biologyStreak, generalStreak]
          .reduce((a, b) => a > b ? a : b);

      await HomeWidget.saveWidgetData(_kSubStreakPhysics, physicsStreak);
      await HomeWidget.saveWidgetData(_kSubStreakChemistry, chemistryStreak);
      await HomeWidget.saveWidgetData(_kSubStreakBiology, biologyStreak);
      await HomeWidget.saveWidgetData(_kSubStreakGeneral, generalStreak);
      await HomeWidget.saveWidgetData(_kSubStreakBest, bestStreak);

      await HomeWidget.updateWidget(
        name: 'SubjectStreakWidgetProvider',
        androidName: 'SubjectStreakWidgetProvider',
      );

      debugPrint('Subject streak widget saved: Physics=$physicsStreak, Chem=$chemistryStreak, Bio=$biologyStreak');
    } catch (e) {
      debugPrint('WidgetService.refreshSubjectStreakWidget error: $e');
    }
  }

  static Future<int> _calculateSubjectStudyStreak(int neetSubjectIndex) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;

      final result = await db.rawQuery("""
        SELECT COUNT(*) as count FROM study_sessions
        WHERE completedAtMillis >= ? AND completedAtMillis < ? AND neetSubject = ?
      """, [dayStart, dayEnd, neetSubjectIndex]);

      final count = (result.first['count'] as int?) ?? 0;
      if (count > 0) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  // ═════════════════════════════════════════════════════════════════
  // MCQ TARGET WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshMcqTargetWidget() async {
    try {
      final prefs = await _getPrefs();

      final target = prefs.getInt('mcq_daily_target') ?? 100;
      final attempted = prefs.getInt('mcq_daily_attempted') ?? 0;
      final correct = prefs.getInt('mcq_daily_correct') ?? 0;
      final subject = prefs.getString('mcq_daily_subject') ?? 'All';

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

      final sessions = await DatabaseHelper.instance
          .getStudySessionsForDateRange(todayStart, todayEnd);

      int dbAttempted = 0;
      int dbCorrect = 0;
      for (final session in sessions) {
        dbAttempted += session.mcqsAttempted ?? 0;
        dbCorrect += session.mcqsCorrect ?? 0;
      }

      final finalAttempted = max(attempted, dbAttempted);
      final finalCorrect = max(correct, dbCorrect);
      final accuracy = finalAttempted > 0
          ? ((finalCorrect / finalAttempted) * 100).round()
          : 0;

      await HomeWidget.saveWidgetData(_kMcqTarget, target);
      await HomeWidget.saveWidgetData(_kMcqAttempted, finalAttempted);
      await HomeWidget.saveWidgetData(_kMcqCorrect, finalCorrect);
      await HomeWidget.saveWidgetData(_kMcqAccuracy, accuracy);
      await HomeWidget.saveWidgetData(_kMcqSubject, subject);

      await HomeWidget.updateWidget(
        name: 'McqTargetWidgetProvider',
        androidName: 'McqTargetWidgetProvider',
      );

      debugPrint('MCQ target widget saved: $finalAttempted/$target attempted, $accuracy% accuracy');
    } catch (e) {
      debugPrint('WidgetService.refreshMcqTargetWidget error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // REVISION ROUND WIDGET
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshRevisionRoundWidget() async {
    try {
      final prefs = await _getPrefs();

      final currentRound = prefs.getInt('revision_current_round') ?? 1;
      final roundLabels = ['Round 1', 'Round 2', 'Round 3', 'Final'];
      final roundLabel = currentRound >= 1 && currentRound <= 4
          ? roundLabels[currentRound - 1]
          : 'Round $currentRound';

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery("""
        SELECT neetSubject, MAX(revisionRound) as maxRound
        FROM study_sessions
        WHERE completedAtMillis >= ? AND neetSubject IS NOT NULL
        GROUP BY neetSubject
      """, [thirtyDaysAgo]);

      int physicsRound = 0;
      int chemistryRound = 0;
      int biologyRound = 0;

      for (final row in result) {
        final subjectIdx = row['neetSubject'] as int?;
        final maxRound = (row['maxRound'] as int?) ?? 0;
        switch (subjectIdx) {
          case 0:
            physicsRound = maxRound;
            break;
          case 1:
            chemistryRound = maxRound;
            break;
          case 2:
            biologyRound = maxRound;
            break;
        }
      }

      await HomeWidget.saveWidgetData(_kRevRound, currentRound);
      await HomeWidget.saveWidgetData(_kRevRoundLabel, roundLabel);
      await HomeWidget.saveWidgetData(_kRevPhysicsRound, physicsRound);
      await HomeWidget.saveWidgetData(_kRevChemistryRound, chemistryRound);
      await HomeWidget.saveWidgetData(_kRevBiologyRound, biologyRound);

      await HomeWidget.updateWidget(
        name: 'RevisionRoundWidgetProvider',
        androidName: 'RevisionRoundWidgetProvider',
      );

      debugPrint('Revision round widget saved: $roundLabel, Physics=$physicsRound, Chem=$chemistryRound, Bio=$biologyRound');
    } catch (e) {
      debugPrint('WidgetService.refreshRevisionRoundWidget error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // COMPOSITE: REFRESH ALL WIDGETS
  // ═════════════════════════════════════════════════════════════════

  static Future<void> refreshAllWidgets() async {
    await refreshWidget();
    await refreshPomodoroWidget();
    await refreshAttendanceWidget();
    await refreshTimetableWidget();
    await refreshHabitWidget();
    await refreshReadingWidget();
    await refreshNeetCountdownWidget();
    await refreshSubjectStreakWidget();
    await refreshMcqTargetWidget();
    await refreshRevisionRoundWidget();
    debugPrint('WidgetService.refreshAllWidgets: all widgets refreshed');
  }

  static Future registerInteractivityCallback() async {
    // No-op: tap-to-open is handled natively. Kept for clarity.
  }
}
