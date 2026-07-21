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
      String? textColor;
      int progressPercent = 65;
      String? urgencyColorName;

      if (activeEvent != null) {
        title = activeEvent.title;

        final result = CountdownService.buildCountdownText(
          activeEvent,
          now,
          smartFormatEnabled: prefs.getBool('smart_countdown_format') ?? false,
        );
        countdown = result.text;

        // Theme color - FIX: use fromName not fromNameString
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
        }

        // Urgency color
        final urgency = activeEvent.getUrgencyColor(now);
        if (urgency == Colors.red) urgencyColorName = 'red';
        else if (urgency == Colors.orange) urgencyColorName = 'orange';
        else if (urgency == Colors.deepOrange) urgencyColorName = 'deepOrange';
        else if (urgency == Colors.green) urgencyColorName = 'green';
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

      // Save to SharedPreferences for widget provider
      await prefs.setString('event_title', title);
      await prefs.setString('countdown_text', countdown);
      await prefs.setString('widget_bg_color', bgColor ?? '#00BFA5');
      await prefs.setString('widget_text_color', textColor ?? '#FFFFFF');
      await prefs.setInt('widget_progress_percent', progressPercent);
      if (urgencyColorName != null) {
        await prefs.setString('widget_urgency_color', urgencyColorName);
      } else {
        await prefs.remove('widget_urgency_color');
      }

      // Trigger native widget update
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'countdown': countdown,
        'bgColor': bgColor,
        'textColor': textColor,
        'progressPercent': progressPercent,
        'urgencyColor': urgencyColorName,
      });
    } catch (e) {
      debugPrint('Widget refresh error: $e');
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

      String subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      String timerText = prefs.getString('pomodoro_timer_text') ?? 'Tap to start';
      String status = prefs.getString('pomodoro_status') ?? 'Focus';
      int progressPercent = prefs.getInt('pomodoro_progress_percent') ?? 45;
      int completedSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;

      // Get theme color - FIX: use fromName not fromNameString
      String? bgColor;
      final themeName = prefs.getString('selected_theme') ?? 'auroraBorealis';
      final theme = AppThemes.fromName(themeName);
      final colors = AppThemes.gradientColorsFor(theme);
      if (colors != null && colors.isNotEmpty) {
        bgColor = '#${colors[0].value.toRadixString(16).substring(2)}';
      }

      await _channel.invokeMethod('updatePomodoroWidget', {
        'subject': subject,
        'timerText': timerText,
        'status': status,
        'bgColor': bgColor,
        'progressPercent': progressPercent,
        'completedSessions': completedSessions,
      });
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }
}
