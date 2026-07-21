// CHATGPT-CODE-REPO-TEST/lib/services/widget_service.dart
// COMPLETE FILE - Fixed ThemeInfo type mismatch + Added Grade & Task Widgets

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../theme/app_themes.dart';

class WidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.example.event_countdown/widget');

  static DateTime? _lastWidgetUpdate;
  static DateTime? _lastPomodoroWidgetUpdate;

  /// Refresh the home screen widget with the next upcoming event.
  static Future<void> refreshWidget() async {
    // Throttle: max once per 15 seconds
    if (_lastWidgetUpdate != null &&
        DateTime.now().difference(_lastWidgetUpdate!).inSeconds < 15) {
      return;
    }
    _lastWidgetUpdate = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

      String title = 'No upcoming events';
      String countdown = 'Tap to add one';
      String? bgColor;
      String textColor = '#FFFFFF';
      int progressPercent = 65;
      bool isAssignment = false;
      String? subjectTag;
      String? priorityLabel;
      String? urgencyColorName;

      final activeEvent = _getActiveEvent(events, now);

      if (activeEvent != null) {
        isAssignment = activeEvent.subjectTag != null &&
            activeEvent.subjectTag!.isNotEmpty;
        subjectTag = activeEvent.subjectTag;

        if (isAssignment) {
          title = '${activeEvent.title} • $subjectTag';
        } else {
          title = activeEvent.title;
        }

        final result = CountdownService.buildCountdownText(
          activeEvent,
          now,
          smartFormatEnabled: prefs.getBool('smart_countdown_format') ?? false,
        );
        countdown = result.text;

        // Theme color - FIX: Use theme.option to get AppThemeOption from ThemeInfo
        final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
        final theme = AppThemes.fromName(themeName);
        final colors = AppThemes.gradientColorsFor(theme.option);
        if (colors != null && colors.isNotEmpty) {
          bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
        }

        // Progress calculation
        if (activeEvent.deadlineMillis != null &&
            activeEvent.startTimeMillis != null) {
          final deadline = DateTime.fromMillisecondsSinceEpoch(
              activeEvent.deadlineMillis!);
          final startOfDeadlineDay =
              DateTime(deadline.year, deadline.month, deadline.day);
          final total = deadline.difference(startOfDeadlineDay).inMilliseconds;
          final elapsed = now.difference(startOfDeadlineDay).inMilliseconds;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).round().clamp(0, 100);
          }
        } else {
          // For date-only events, progress through the day
          final eventDate =
              DateTime.fromMillisecondsSinceEpoch(activeEvent.dateMillis);
          final startOfDay =
              DateTime(eventDate.year, eventDate.month, eventDate.day);
          final endOfDay = DateTime(
              eventDate.year, eventDate.month, eventDate.day, 23, 59, 59);
          final total = endOfDay.difference(startOfDay).inMilliseconds;
          final elapsed = now.difference(startOfDay).inMilliseconds;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).round().clamp(0, 100);
          }
        }

        // Urgency color
        if (activeEvent.isCompleted) {
          urgencyColorName = 'grey';
          priorityLabel = 'Completed';
        } else {
          switch (activeEvent.priority) {
            case 4:
              urgencyColorName = 'red';
              priorityLabel = 'Urgent';
              break;
            case 3:
              urgencyColorName = 'deepOrange';
              priorityLabel = 'High Priority';
              break;
            case 2:
              urgencyColorName = 'orange';
              priorityLabel = 'Normal';
              break;
            case 1:
              urgencyColorName = 'green';
              priorityLabel = 'Low Priority';
              break;
            default:
              final urgency = activeEvent.getUrgencyColor(now);
              urgencyColorName = _colorToName(urgency);
          }
        }
      } else {
        title = 'No upcoming events';
        countdown = 'Tap to add one';
        // FIX: Use theme.option to get AppThemeOption from ThemeInfo
        final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
        final theme = AppThemes.fromName(themeName);
        final colors = AppThemes.gradientColorsFor(theme.option);
        if (colors != null && colors.isNotEmpty) {
          bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
        }
      }

      // Save ALL widget data to SharedPreferences for native widget provider
      await prefs.setString('widget_event_title', title);
      await prefs.setString('widget_countdown_text', countdown);
      await prefs.setString('widget_bg_color', bgColor ?? '#00BFA5');
      await prefs.setString('widget_text_color', textColor);
      await prefs.setInt('widget_progress_percent', progressPercent);
      await prefs.setBool('widget_is_assignment', isAssignment);

      if (subjectTag != null) {
        await prefs.setString('widget_subject_tag', subjectTag);
      } else {
        await prefs.remove('widget_subject_tag');
      }
      if (priorityLabel != null) {
        await prefs.setString('widget_priority_label', priorityLabel);
      } else {
        await prefs.remove('widget_priority_label');
      }
      if (urgencyColorName != null) {
        await prefs.setString('widget_urgency_color', urgencyColorName);
      } else {
        await prefs.remove('widget_urgency_color');
      }

      // Trigger native widget update with complete data including assignment fields
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'countdown': countdown,
        'bgColor': bgColor,
        'textColor': textColor,
        'progressPercent': progressPercent,
        'urgencyColor': urgencyColorName,
        'isAssignment': isAssignment,
        'subjectTag': subjectTag,
        'priorityLabel': priorityLabel,
      });
    } catch (e, stackTrace) {
      debugPrint('Widget refresh error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Refresh the Pomodoro widget with current timer state.
  static Future<void> refreshPomodoroWidget() async {
    // Throttle: max once per 15 seconds
    if (_lastPomodoroWidgetUpdate != null &&
        DateTime.now().difference(_lastPomodoroWidgetUpdate!).inSeconds < 15) {
      return;
    }
    _lastPomodoroWidgetUpdate = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Read Pomodoro state from SharedPreferences (written by PomodoroService)
      String subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      String timerText =
          prefs.getString('pomodoro_timer_text') ?? 'Tap to start';
      String status = prefs.getString('pomodoro_status') ?? 'Focus';
      // FIX: Read as double since PomodoroService saves progressPercent via setDouble
      double rawProgress = prefs.getDouble('pomodoro_progress_percent') ?? 0.0;
      int progressPercent = (rawProgress * 100).round().clamp(0, 100);
      int completedSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;

      // Get theme color - FIX: Use theme.option
      String? bgColor;
      final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
      final theme = AppThemes.fromName(themeName);
      final colors = AppThemes.gradientColorsFor(theme.option);
      if (colors != null && colors.isNotEmpty) {
        bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
      }

      // Phase-specific colors for Pomodoro widget
      String phaseColor;
      switch (status) {
        case 'Focus':
          phaseColor = '#FF6B6B'; // Red for focus
          break;
        case 'Short Break':
          phaseColor = '#4ECDC4'; // Teal for short break
          break;
        case 'Long Break':
          phaseColor = '#45B7D1'; // Blue for long break
          break;
        case 'Paused':
          phaseColor = '#FFA726'; // Orange for paused
          break;
        default:
          phaseColor = bgColor ?? '#00BFA5';
      }

      // Save Pomodoro widget data
      await prefs.setString('pomodoro_widget_subject', subject);
      await prefs.setString('pomodoro_widget_timer', timerText);
      await prefs.setString('pomodoro_widget_status', status);
      await prefs.setString('pomodoro_widget_bg_color', phaseColor);
      await prefs.setInt('pomodoro_widget_progress_percent', progressPercent);
      await prefs.setInt('pomodoro_widget_completed_sessions', completedSessions);

      await _channel.invokeMethod('updatePomodoroWidget', {
        'subject': subject,
        'timerText': timerText,
        'status': status,
        'bgColor': phaseColor,
        'progressPercent': progressPercent,
        'completedSessions': completedSessions,
      });
    } catch (e, stackTrace) {
      debugPrint('Pomodoro widget refresh error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Refresh Grade widget with current grade data
  static Future<void> refreshGradeWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final components = await DatabaseHelper.instance.getAllGradeComponents();

      double weightedScore = 0;
      double totalWeight = 0;
      for (final c in components) {
        weightedScore +=
            ((c['score'] as num) / (c['totalPoints'] as num)) *
                (c['weight'] as num);
        totalWeight += (c['weight'] as num);
      }
      final grade = totalWeight > 0 ? (weightedScore / totalWeight) * 100 : 0.0;

      String letterGrade;
      if (grade >= 97) letterGrade = 'A+';
      else if (grade >= 93) letterGrade = 'A';
      else if (grade >= 90) letterGrade = 'A-';
      else if (grade >= 87) letterGrade = 'B+';
      else if (grade >= 83) letterGrade = 'B';
      else if (grade >= 80) letterGrade = 'B-';
      else if (grade >= 77) letterGrade = 'C+';
      else if (grade >= 73) letterGrade = 'C';
      else if (grade >= 70) letterGrade = 'C-';
      else if (grade >= 67) letterGrade = 'D+';
      else if (grade >= 63) letterGrade = 'D';
      else if (grade >= 60) letterGrade = 'D-';
      else letterGrade = 'F';

      // Save to SharedPreferences for native widget
      await prefs.setDouble('grade_widget_current_grade', grade);
      await prefs.setString('grade_widget_letter_grade', letterGrade);
      await prefs.setInt('grade_widget_component_count', components.length);

      await _channel.invokeMethod('updateGradeWidget', {
        'grade': grade.toStringAsFixed(1),
        'letterGrade': letterGrade,
        'componentCount': components.length,
      });
    } catch (e) {
      debugPrint('Grade widget refresh error: $e');
    }
  }

  /// Refresh Task widget with upcoming assignments
  static Future<void> refreshTaskWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

      // Get upcoming assignments (events with subject tags, not completed, future)
      final assignments = events.where((e) {
        return e.subjectTag != null &&
            e.subjectTag!.isNotEmpty &&
            !e.isCompleted &&
            e.finalMillis > now.millisecondsSinceEpoch;
      }).toList();
      assignments.sort((a, b) => a.finalMillis.compareTo(b.finalMillis));

      // Take top 3 upcoming
      final topTasks = assignments.take(3).toList();

      // Build task list for widget
      List<Map<String, dynamic>> taskList = [];
      for (final task in topTasks) {
        final diff = DateTime.fromMillisecondsSinceEpoch(task.finalMillis)
            .difference(now);
        String timeLeft;
        if (diff.inDays > 0) {
          timeLeft = '${diff.inDays}d left';
        } else if (diff.inHours > 0) {
          timeLeft = '${diff.inHours}h left';
        } else {
          timeLeft = '${diff.inMinutes}m left';
        }

        taskList.add({
          'title': task.title,
          'subject': task.subjectTag,
          'priority': task.priority,
          'timeLeft': timeLeft,
        });
      }

      // Save to SharedPreferences
      await prefs.setString('task_widget_json', taskList.toString());
      await prefs.setInt('task_widget_count', topTasks.length);

      await _channel.invokeMethod('updateTaskWidget', {
        'tasks': taskList,
        'totalCount': assignments.length,
      });
    } catch (e) {
      debugPrint('Task widget refresh error: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────

  static Event? _getActiveEvent(List<Event> sortedEvents, DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    for (final e in sortedEvents) {
      if (e.finalMillis > nowMillis && !e.isCompleted) return e;
    }
    return sortedEvents.isNotEmpty ? sortedEvents.first : null;
  }

  static String _colorToName(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.deepOrange) return 'deepOrange';
    if (color == Colors.green) return 'green';
    if (color == Colors.grey) return 'grey';
    return 'green';
  }
}
