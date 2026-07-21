// CHATGPT-CODE-REPO-TEST/lib/services/widget_service.dart
// COMPLETE FILE - Fixed type errors and added grade/tasks widget support

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';
import '../theme/app_themes.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  // ── SharedPreferences keys (must match Android WidgetProvider) ──
  static const _kTitle = 'event_title';
  static const _kCountdown = 'countdown_text';
  static const _kBgColor = 'widget_bg_color';
  static const _kTextColor = 'widget_text_color';
  static const _kProgress = 'widget_progress_percent';
  static const _kUrgencyColor = 'widget_urgency_color';

  // Pomodoro widget keys
  static const _kPomodoroSubject = 'pomodoro_subject';
  static const _kPomodoroTimer = 'pomodoro_timer_text';
  static const _kPomodoroStatus = 'pomodoro_status';
  static const _kPomodoroBgColor = 'pomodoro_bg_color';
  static const _kPomodoroProgress = 'pomodoro_progress_percent';
  static const _kPomodoroSessions = 'pomodoro_completed_sessions';

  // NEW: Grade widget keys
  static const _kGradeData = 'grade_data';
  static const _kGradeCurrent = 'grade_current';
  static const _kGradeLetter = 'grade_letter';

  // NEW: Tasks/Assignments widget keys
  static const _kTasksData = 'tasks_data';
  static const _kTasksUrgentCount = 'tasks_urgent_count';
  static const _kTasksTotalCount = 'tasks_total_count';

  // ── Refresh both widgets ──
  static Future<void> refreshWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      final active = CountdownService.getActiveEvent(events, now);

      final smartFormat = await SettingsService.instance.getSmartFormatEnabled();
      final themeName = await SettingsService.instance.getSelectedThemeName();
      final theme = AppThemes.fromName(themeName);

      if (active != null) {
        final result = CountdownService.buildCountdownText(
          active,
          now,
          smartFormatEnabled: smartFormat,
        );

        final urgencyColorName = _colorName(active.getUrgencyColor(now));
        final progressPercent = _calculateProgress(active, now);

        // FIX: Use theme.option (AppThemeOption) not theme (ThemeInfo)
        final colors = AppThemes.gradientColorsFor(theme.option);
        final bgHex = _colorToHex(colors.first);
        final textHex = '#FFFFFF';

        await HomeWidget.saveWidgetData<String>(_kTitle, active.title);
        await HomeWidget.saveWidgetData<String>(_kCountdown, result.text);
        await HomeWidget.saveWidgetData<String>(_kBgColor, bgHex);
        await HomeWidget.saveWidgetData<String>(_kTextColor, textHex);
        await HomeWidget.saveWidgetData<int>(_kProgress, progressPercent);
        await HomeWidget.saveWidgetData<String>(_kUrgencyColor, urgencyColorName);
      } else {
        // No upcoming events
        // FIX: Use theme.option not theme
        final colors = AppThemes.gradientColorsFor(theme.option);
        final bgHex = _colorToHex(colors.first);

        await HomeWidget.saveWidgetData<String>(_kTitle, 'No upcoming events');
        await HomeWidget.saveWidgetData<String>(_kCountdown, '');
        await HomeWidget.saveWidgetData<String>(_kBgColor, bgHex);
        await HomeWidget.saveWidgetData<String>(_kTextColor, '#FFFFFF');
        await HomeWidget.saveWidgetData<int>(_kProgress, 0);
        await HomeWidget.saveWidgetData<String?>(_kUrgencyColor, null);
      }

      // NEW: Save grade data to widget
      await _refreshGradeWidget();

      // NEW: Save tasks/assignments data to widget
      await _refreshTasksWidget();

      await HomeWidget.updateWidget(
        name: 'EventCountdownWidgetProvider',
        androidName: 'EventCountdownWidgetProvider',
        iOSName: 'EventCountdownWidget',
        qualifiedAndroidName: 'com.example.event_countdown.EventCountdownWidgetProvider',
      );
    } catch (e) {
      debugPrint('Widget refresh error: $e');
    }
  }

  // NEW: Refresh grade widget data
  static Future<void> _refreshGradeWidget() async {
    try {
      final components = await DatabaseHelper.instance.getAllGradeComponents();
      
      double weightedScore = 0;
      double totalWeight = 0;
      for (final c in components) {
        weightedScore += ((c['score'] as num) / (c['totalPoints'] as num)) * (c['weight'] as num);
        totalWeight += (c['weight'] as num);
      }
      
      final currentGrade = totalWeight > 0 ? (weightedScore / totalWeight) * 100 : 0.0;
      
      String letterGrade;
      final g = currentGrade;
      if (g >= 97) letterGrade = 'A+';
      else if (g >= 93) letterGrade = 'A';
      else if (g >= 90) letterGrade = 'A-';
      else if (g >= 87) letterGrade = 'B+';
      else if (g >= 83) letterGrade = 'B';
      else if (g >= 80) letterGrade = 'B-';
      else if (g >= 77) letterGrade = 'C+';
      else if (g >= 73) letterGrade = 'C';
      else if (g >= 70) letterGrade = 'C-';
      else if (g >= 67) letterGrade = 'D+';
      else if (g >= 63) letterGrade = 'D';
      else if (g >= 60) letterGrade = 'D-';
      else letterGrade = 'F';

      await HomeWidget.saveWidgetData<String>(_kGradeData, jsonEncode(components));
      await HomeWidget.saveWidgetData<double>(_kGradeCurrent, currentGrade);
      await HomeWidget.saveWidgetData<String>(_kGradeLetter, letterGrade);
    } catch (e) {
      debugPrint('Grade widget refresh error: $e');
    }
  }

  // NEW: Refresh tasks/assignments widget data
  static Future<void> _refreshTasksWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      final nowMillis = now.millisecondsSinceEpoch;

      final assignments = events.where((e) {
        return e.subjectTag != null &&
               e.subjectTag!.isNotEmpty &&
               !e.isCompleted &&
               e.finalMillis > nowMillis;
      }).toList();

      final urgentCount = assignments.where((a) => a.priority == 4).length;
      final totalCount = assignments.length;

      // Build task list JSON for widget
      final taskList = assignments.take(5).map((a) => {
        'title': a.title,
        'subject': a.subjectTag,
        'priority': a.priority,
        'priorityLabel': a.priorityLabel,
        'daysLeft': ((a.finalMillis - nowMillis) ~/ 86400000).clamp(0, 999),
      }).toList();

      await HomeWidget.saveWidgetData<String>(_kTasksData, jsonEncode(taskList));
      await HomeWidget.saveWidgetData<int>(_kTasksUrgentCount, urgentCount);
      await HomeWidget.saveWidgetData<int>(_kTasksTotalCount, totalCount);
    } catch (e) {
      debugPrint('Tasks widget refresh error: $e');
    }
  }

  static Future<void> refreshPomodoroWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      final timerText = prefs.getString('pomodoro_timer_text') ?? 'Tap to start';
      final status = prefs.getString('pomodoro_status') ?? 'Focus';
      final themeName = await SettingsService.instance.getSelectedThemeName();
      final theme = AppThemes.fromName(themeName);
      // FIX: Use theme.option not theme
      final colors = AppThemes.gradientColorsFor(theme.option);
      final bgHex = _colorToHex(colors.first);
      final progressPercent = prefs.getDouble('pomodoro_progress_percent')?.round() ?? 0;
      final completedSessions = prefs.getInt('pomodoro_completed_sessions_total') ?? 0;

      await HomeWidget.saveWidgetData<String>(_kPomodoroSubject, subject);
      await HomeWidget.saveWidgetData<String>(_kPomodoroTimer, timerText);
      await HomeWidget.saveWidgetData<String>(_kPomodoroStatus, status);
      await HomeWidget.saveWidgetData<String>(_kPomodoroBgColor, bgHex);
      await HomeWidget.saveWidgetData<int>(_kPomodoroProgress, progressPercent);
      await HomeWidget.saveWidgetData<int>(_kPomodoroSessions, completedSessions);

      await HomeWidget.updateWidget(
        name: 'PomodoroWidgetProvider',
        androidName: 'PomodoroWidgetProvider',
        iOSName: 'PomodoroWidget',
        qualifiedAndroidName: 'com.example.event_countdown.PomodoroWidgetProvider',
      );
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }

  // ── Helpers ──

  static int _calculateProgress(Event event, DateTime now) {
    if (event.startTimeMillis == null || event.deadlineMillis == null) return 65;
    final total = event.deadlineMillis! - event.startTimeMillis!;
    final elapsed = now.millisecondsSinceEpoch - event.startTimeMillis!;
    if (total <= 0) return 65;
    return ((elapsed / total) * 100).clamp(0, 100).round();
  }

  static String _colorName(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.deepOrange) return 'deepOrange';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.green) return 'green';
    return 'grey';
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase().padLeft(6, '0')}';
  }
}
