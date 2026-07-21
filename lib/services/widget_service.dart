import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';
import '../theme/app_themes.dart';

/// Service that updates Android home screen widgets via MethodChannel.
/// Also persists widget data to SharedPreferences so the native widget
/// provider can read it when the app is not running.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const MethodChannel _channel = MethodChannel('com.example.event_countdown/widget');

  // SharedPreferences keys (must match Android Kotlin code)
  static const String _kEventTitle = 'event_title';
  static const String _kCountdownText = 'countdown_text';
  static const String _kBgColor = 'widget_bg_color';
  static const String _kTextColor = 'widget_text_color';
  static const String _kProgress = 'widget_progress_percent';
  static const String _kUrgencyColor = 'widget_urgency_color';

  // Pomodoro widget keys
  static const String _kPomodoroSubject = 'pomodoro_subject';
  static const String _kPomodoroTimer = 'pomodoro_timer_text';
  static const String _kPomodoroStatus = 'pomodoro_status';
  static const String _kPomodoroBgColor = 'pomodoro_bg_color';
  static const String _kPomodoroProgress = 'pomodoro_progress_percent';
  static const String _kPomodoroSessions = 'pomodoro_completed_sessions';

  /// Refresh the Event Countdown widget with the next upcoming event.
  static Future<void> refreshWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

      // Find next non-completed event
      Event? nextEvent;
      for (final e in events) {
        if (!e.isCompleted && e.finalMillis > now.millisecondsSinceEpoch) {
          nextEvent = e;
          break;
        }
      }

      final smartFormat = await SettingsService.instance.getSmartFormatEnabled();
      final theme = await SettingsService.instance.getSelectedTheme();
      final customColor = await SettingsService.instance.getCustomColor();

      String title;
      String countdownText;
      String? bgColor;
      String? textColor;
      int progressPercent;
      String? urgencyColorName;

      if (nextEvent == null) {
        title = 'No upcoming events';
        countdownText = '';
        progressPercent = 0;
        urgencyColorName = null;
      } else {
        title = nextEvent.title;
        final result = CountdownService.buildCountdownText(nextEvent, now, smartFormatEnabled: smartFormat);
        countdownText = result.text;

        // Calculate progress percentage
        if (nextEvent.startTimeMillis != null && nextEvent.deadlineMillis != null) {
          final total = nextEvent.deadlineMillis! - nextEvent.startTimeMillis!;
          final elapsed = now.millisecondsSinceEpoch - nextEvent.startTimeMillis!;
          progressPercent = total > 0 ? ((elapsed / total) * 100).round().clamp(0, 100) : 65;
        } else {
          progressPercent = 65;
        }

        // Get urgency color name for widget indicator
        final urgencyColor = nextEvent.getUrgencyColor(now);
        urgencyColorName = _colorToName(urgencyColor);

        // Theme colors
        final themeColors = _getThemeColors(theme, customColor);
        bgColor = themeColors['bg'];
        textColor = themeColors['text'];
      }

      // Persist to SharedPreferences for native widget to read
      await prefs.setString(_kEventTitle, title);
      await prefs.setString(_kCountdownText, countdownText);
      if (bgColor != null) await prefs.setString(_kBgColor, bgColor);
      if (textColor != null) await prefs.setString(_kTextColor, textColor);
      await prefs.setInt(_kProgress, progressPercent);
      if (urgencyColorName != null) {
        await prefs.setString(_kUrgencyColor, urgencyColorName);
      } else {
        await prefs.remove(_kUrgencyColor);
      }

      // Also persist grade and tasks data if available
      await _persistGradeAndTasksData(prefs);

      // Notify native widget via MethodChannel
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'countdown': countdownText,
        'bgColor': bgColor,
        'textColor': textColor,
        'progressPercent': progressPercent,
        'urgencyColor': urgencyColorName,
      });
    } catch (e) {
      debugPrint('WidgetService.refreshWidget error: $e');
    }
  }

  /// Refresh the Pomodoro widget with current timer state.
  static Future<void> refreshPomodoroWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Read current pomodoro state from SharedPreferences
      final phaseName = prefs.getString('pomodoro_phase') ?? 'idle';
      final remainingSeconds = prefs.getInt('pomodoro_remaining_seconds') ?? 0;
      final completedSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;
      final subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      final status = prefs.getString('pomodoro_status') ?? 'Focus';

      // Format timer text
      final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
      final timerText = phaseName == 'idle' ? 'Tap to start' : '$minutes:$seconds';

      // Calculate progress
      final progressPercent = prefs.getDouble('pomodoro_progress_percent') ?? 0.0;
      final progressInt = (progressPercent * 100).round().clamp(0, 100);

      // Determine background color based on phase
      String? bgColor;
      if (phaseName == 'focusing' || phaseName == 'idle' || phaseName == 'paused') {
        bgColor = '#FF6B6B'; // Coral/red for focus
      } else {
        bgColor = '#00BFA5'; // Teal for break
      }

      // Persist for native widget
      await prefs.setString(_kPomodoroSubject, subject);
      await prefs.setString(_kPomodoroTimer, timerText);
      await prefs.setString(_kPomodoroStatus, status);
      await prefs.setString(_kPomodoroBgColor, bgColor);
      await prefs.setInt(_kPomodoroProgress, progressInt);
      await prefs.setInt(_kPomodoroSessions, completedSessions);

      // Notify native widget
      await _channel.invokeMethod('updatePomodoroWidget', {
        'subject': subject,
        'timerText': timerText,
        'status': status,
        'bgColor': bgColor,
        'progressPercent': progressInt,
        'completedSessions': completedSessions,
      });
    } catch (e) {
      debugPrint('WidgetService.refreshPomodoroWidget error: $e');
    }
  }

  /// Persist grade and tasks data for widget display
  static Future<void> _persistGradeAndTasksData(SharedPreferences prefs) async {
    try {
      // Get grade components
      final components = await DatabaseHelper.instance.getAllGradeComponents();
      double weightedScore = 0;
      double totalWeight = 0;
      for (final c in components) {
        weightedScore += ((c['score'] as num) / (c['totalPoints'] as num)) * (c['weight'] as num);
        totalWeight += (c['weight'] as num);
      }
      final grade = totalWeight > 0 ? (weightedScore / totalWeight) * 100 : 0;

      // Determine letter grade
      String letter;
      if (grade >= 93) letter = 'A';
      else if (grade >= 90) letter = 'A-';
      else if (grade >= 87) letter = 'B+';
      else if (grade >= 83) letter = 'B';
      else if (grade >= 80) letter = 'B-';
      else if (grade >= 77) letter = 'C+';
      else if (grade >= 73) letter = 'C';
      else if (grade >= 70) letter = 'C-';
      else if (grade >= 67) letter = 'D+';
      else if (grade >= 63) letter = 'D';
      else if (grade >= 60) letter = 'D-';
      else letter = 'F';

      await prefs.setDouble('grade_current', grade.toDouble());
      await prefs.setString('grade_letter', letter);

      // Count urgent tasks
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      int urgentCount = 0;
      int totalTasks = 0;
      for (final e in events) {
        if (e.subjectTag != null && e.subjectTag!.isNotEmpty && !e.isCompleted) {
          totalTasks++;
          final diff = DateTime.fromMillisecondsSinceEpoch(e.finalMillis).difference(now);
          if (diff.inDays < 7 && !diff.isNegative) {
            urgentCount++;
          }
        }
      }

      await prefs.setInt('tasks_urgent_count', urgentCount);
      await prefs.setInt('tasks_total_count', totalTasks);
    } catch (e) {
      debugPrint('WidgetService._persistGradeAndTasksData error: $e');
    }
  }

  /// Convert a Color to a named urgency color for the widget
  static String? _colorToName(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.deepOrange) return 'deepOrange';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.green) return 'green';
    if (color == Colors.grey) return 'grey';
    return null;
  }

  /// Get theme colors as hex strings
  static Map<String, String> _getThemeColors(AppThemeOption theme, Color? customColor) {
    switch (theme) {
      case AppThemeOption.auroraBorealis:
        return {'bg': '#00BFA5', 'text': '#FFFFFF'};
      case AppThemeOption.oceanBreeze:
        return {'bg': '#2196F3', 'text': '#FFFFFF'};
      case AppThemeOption.sunsetGlow:
        return {'bg': '#FF7043', 'text': '#FFFFFF'};
      case AppThemeOption.midnightForest:
        return {'bg': '#2E7D32', 'text': '#FFFFFF'};
      case AppThemeOption.cherryBlossom:
        return {'bg': '#E91E63', 'text': '#FFFFFF'};
      case AppThemeOption.customHex:
        if (customColor != null) {
          final hex = '#${customColor.value.toRadixString(16).substring(2).toUpperCase()}';
          return {'bg': hex, 'text': '#FFFFFF'};
        }
        return {'bg': '#00BFA5', 'text': '#FFFFFF'};
      case AppThemeOption.materialYou:
        return {'bg': '#6750A4', 'text': '#FFFFFF'};
    }
  }
}
