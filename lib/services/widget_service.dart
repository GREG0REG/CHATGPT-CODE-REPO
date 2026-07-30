import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../db/database_helper.dart';
import '../models/event.dart';
import '../theme/app_themes.dart';
import 'countdown_service.dart';
import 'settings_service.dart';

/// Pushes data into home_widget SharedPreferences and triggers native updates.
/// COMPLETE REPLACEMENT — v2 with Attendance & Pomodoro widget support
class WidgetService {
  WidgetService._();

  // ── Android Provider Names ──
  static const String eventWidgetName = 'EventCountdownWidgetProvider';
  static const String pomodoroWidgetName = 'PomodoroWidgetProvider';
  static const String attendanceWidgetName = 'AttendanceWidgetProvider';

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
      final bgType = await SettingsService.instance.getWidgetBackgroundType();
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

      final themeColor = AppThemes.colorFor(theme);
      final textColor = AppThemes.autoContrastColor(themeColor);

      await HomeWidget.saveWidgetData(_kEventTitle, title);
      await HomeWidget.saveWidgetData(_kEventCountdown, countdownText);
      await HomeWidget.saveWidgetData(
        _kEventBgType,
        bgType == WidgetBackgroundType.customImage ? 'image' : 'theme',
      );
      await HomeWidget.saveWidgetData(
        _kEventBgColor,
        themeColor.value.toString(),
      );
      await HomeWidget.saveWidgetData(
        _kEventTextColor,
        textColor.value.toString(),
      );
      if (imagePath != null && bgType == WidgetBackgroundType.customImage) {
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
      // Read pomodoro data from app's own SharedPreferences via SettingsService
      // or compute from PomodoroService state
      final prefs = await SettingsService.instance.prefs;
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

      // Calculate remaining time
      final remainingSeconds = _calculateRemainingTime(endTime);
      final timerText = _formatPomodoroTimerText(phase, remainingSeconds, endTime, prefs);

      // Calculate progress
      final progress = _calculatePomodoroProgress(phase, remainingSeconds, totalDuration, prefs);

      // NEET days (from FocusSettingsService or hardcoded for now)
      final neetDays = _calculateNeetDaysRemaining();

      // Save ALL data to home_widget SharedPreferences
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

      // Trigger widget update
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
    // NEET 2027: First Sunday of May 2027
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

        // Calculate status text
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

        // Calculate streak
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

      // Sort by percentage ascending (worst attendance first — most important to see)
      subjectData.sort((a, b) => (a['percentage'] as int).compareTo(b['percentage'] as int));

      // Save subject count
      await HomeWidget.saveWidgetData(_kAttSubjectCount, subjectData.length);

      // Save each subject's data with indexed keys
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

      // Trigger widget update
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

  static Future registerInteractivityCallback() async {
    // No-op: tap-to-open is handled natively. Kept for clarity.
  }
}
