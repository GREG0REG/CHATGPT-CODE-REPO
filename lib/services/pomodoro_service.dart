import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/recurrence_service.dart';
import '../theme/app_themes.dart';
import '../main.dart';

/// Background update task name
const String kWidgetBackgroundUpdateTask = 'event_countdown_widget_bg_update';

/// Service that bridges Flutter data to Android home-screen widgets.
/// Enhanced with more frequent background updates and battery-aware scheduling.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.example.event_countdown/widget');

  // Track last update time to prevent excessive updates
  static DateTime? _lastEventWidgetUpdate;
  static DateTime? _lastPomodoroWidgetUpdate;

  /// Initialize background updates - call this in main.dart
  static Future<void> initializeBackgroundUpdates() async {
    // Register more frequent periodic task for widget updates (every 15 minutes minimum)
    await Workmanager().registerPeriodicTask(
      kWidgetBackgroundUpdateTask,
      kWidgetBackgroundUpdateTask,
      frequency: const Duration(minutes: 15), // More frequent than 4 hours
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false, // Update even on low battery
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace, // Replace to ensure fresh schedule
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }

  /// Call from background task dispatcher
  static Future<bool> handleBackgroundUpdate(String task) async {
    if (task == kWidgetBackgroundUpdateTask) {
      try {
        await refreshWidget();
        await refreshPomodoroWidget();
        return true;
      } catch (e) {
        debugPrint('Background widget update failed: $e');
        return false;
      }
    }
    return true;
  }

  /// Refresh the event countdown widget with the nearest upcoming event.
  static Future<void> refreshWidget() async {
    // Throttle: max once per 30 seconds
    if (_lastEventWidgetUpdate != null &&
        DateTime.now().difference(_lastEventWidgetUpdate!).inSeconds < 30) {
      return;
    }
    _lastEventWidgetUpdate = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();

      final rawEvents = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      final expanded = RecurrenceService.expandEvents(rawEvents, now);

      final activeEvent = CountdownService.getActiveEvent(expanded, now);

      String title;
      String countdown;
      String? bgColor;
      String textColor = '#FFFFFF';
      int progressPercent = 0;
      String? urgencyColorName;
      String? subjectTag;
      String? priorityLabel;
      bool isAssignment = false;

      if (activeEvent != null) {
        // FIX: Detect assignments (events with subjectTag)
        subjectTag = activeEvent.subjectTag;
        isAssignment = subjectTag != null && subjectTag.isNotEmpty;

        // FIX: Show subject tag in title for assignments
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

        // Theme color
        final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
        final theme = AppThemes.fromName(themeName);
        final colors = AppThemes.gradientColorsFor(theme);
        if (colors != null && colors.isNotEmpty) {
          bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
        }

        // Progress calculation
        if (activeEvent.startTimeMillis != null && activeEvent.deadlineMillis != null) {
          final total = activeEvent.deadlineMillis! - activeEvent.startTimeMillis!;
          final elapsed = now.millisecondsSinceEpoch - activeEvent.startTimeMillis!;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).round().clamp(0, 100);
          }
        } else if (activeEvent.deadlineMillis != null) {
          // For deadline-only events, calculate progress from start of deadline day
          final deadline = DateTime.fromMillisecondsSinceEpoch(activeEvent.deadlineMillis!);
          final startOfDeadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
          final total = deadline.difference(startOfDeadlineDay).inMilliseconds;
          final elapsed = now.difference(startOfDeadlineDay).inMilliseconds;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).round().clamp(0, 100);
          }
        } else {
          // For date-only events, progress through the day
          final eventDate = DateTime.fromMillisecondsSinceEpoch(activeEvent.dateMillis);
          final startOfDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
          final endOfDay = DateTime(eventDate.year, eventDate.month, eventDate.day, 23, 59, 59);
          final total = endOfDay.difference(startOfDay).inMilliseconds;
          final elapsed = now.difference(startOfDay).inMilliseconds;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).round().clamp(0, 100);
          }
        }

        // FIX: Priority-based urgency detection for assignments
        if (isAssignment && activeEvent.priority != null) {
          switch (activeEvent.priority) {
            case 'high':
              urgencyColorName = 'red';
              priorityLabel = 'High Priority';
              break;
            case 'medium':
              urgencyColorName = 'orange';
              priorityLabel = 'Medium Priority';
              break;
            case 'low':
              urgencyColorName = 'green';
              priorityLabel = 'Low Priority';
              break;
            default:
              final urgency = activeEvent.getUrgencyColor(now);
              urgencyColorName = _colorToName(urgency);
          }
        } else {
          final urgency = activeEvent.getUrgencyColor(now);
          urgencyColorName = _colorToName(urgency);
        }
      } else {
        title = 'No upcoming events';
        countdown = 'Tap to add one';
        final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
        final theme = AppThemes.fromName(themeName);
        final colors = AppThemes.gradientColorsFor(theme);
        if (colors != null && colors.isNotEmpty) {
          bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
        }
      }

      // FIX: Save ALL widget data to SharedPreferences for native widget provider
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

      // FIX: Trigger native widget update with complete data including assignment fields
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
      String timerText = prefs.getString('pomodoro_timer_text') ?? 'Tap to start';
      String status = prefs.getString('pomodoro_status') ?? 'Focus';
      // FIX: Read as double since PomodoroService saves progressPercent via setDouble
      double rawProgress = prefs.getDouble('pomodoro_progress_percent') ?? 0.0;
      int progressPercent = (rawProgress * 100).round().clamp(0, 100);
      int completedSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;

      // Get theme color
      String? bgColor;
      final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
      final theme = AppThemes.fromName(themeName);
      final colors = AppThemes.gradientColorsFor(theme);
      if (colors != null && colors.isNotEmpty) {
        bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
      }

      // FIX: Phase-specific colors for Pomodoro widget
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
          phaseColor = '#FFD93D'; // Yellow for paused
          break;
        default:
          phaseColor = bgColor ?? '#00BFA5';
      }

      // FIX: Save all Pomodoro widget data to SharedPreferences with consistent keys
      await prefs.setString('pomodoro_widget_subject', subject);
      await prefs.setString('pomodoro_widget_timer_text', timerText);
      await prefs.setString('pomodoro_widget_status', status);
      await prefs.setInt('pomodoro_widget_progress_percent', progressPercent);
      await prefs.setInt('pomodoro_widget_completed_sessions', completedSessions);
      await prefs.setString('pomodoro_widget_phase_color', phaseColor);

      // FIX: Trigger native widget update with complete Pomodoro data
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

  /// Helper to convert Color to string name for widget
  static String? _colorToName(Color? color) {
    if (color == null) return null;
    if (color == Colors.red) return 'red';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.deepOrange) return 'deepOrange';
    if (color == Colors.green) return 'green';
    if (color == Colors.yellow) return 'yellow';
    if (color == Colors.blue) return 'blue';
    return null;
  }
}
