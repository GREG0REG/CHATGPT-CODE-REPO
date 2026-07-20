// CHATGPT-CODE-REPO-TEST/lib/services/widget_service.dart
// COMPLETE REPLACEMENT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';
import '../theme/app_themes.dart';

/// Updates the Android home screen widgets with beautiful circular progress.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.event_countdown/widget');

  /// Calculate progress percentage for the circular ring (0-100)
  static int _calculateProgress(Event event, DateTime now) {
    try {
      final startMillis = event.startTimeMillis ?? event.dateMillis;
      final endMillis = event.deadlineMillis ?? event.dateMillis;
      
      if (startMillis == endMillis) return 65; // Default for date-only events
      
      final total = endMillis - startMillis;
      final elapsed = now.millisecondsSinceEpoch - startMillis;
      
      if (total <= 0) return 0;
      final progress = ((elapsed / total) * 100).round();
      return progress.clamp(0, 100);
    } catch (e) {
      return 65;
    }
  }

  /// Get urgency color name for widget
  static String _getUrgencyColorName(Event event, DateTime now) {
    final color = event.getUrgencyColor(now);
    return when (color) {
      Colors.green => 'green',
      Colors.orange => 'orange',
      Colors.deepOrange => 'deepOrange',
      Colors.red => 'red',
      Colors.grey => 'grey',
      _ => 'green',
    };
  }

  /// Refresh the Event Countdown widget with the next upcoming event.
  static Future<void> refreshWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      final smartFormat = await SettingsService.instance.getSmartFormatEnabled();

      String title = 'No upcoming events';
      String countdown = '';
      int progressPercent = 65;
      String urgencyColorName = 'grey';
      String? iconName;

      final activeEvent = CountdownService.getActiveEvent(events, now);
      if (activeEvent != null) {
        title = activeEvent.title;
        final result = CountdownService.buildCountdownText(
          activeEvent,
          now,
          smartFormatEnabled: smartFormat,
        );
        countdown = result.text;
        progressPercent = _calculateProgress(activeEvent, now);
        urgencyColorName = _getUrgencyColorName(activeEvent, now);
        iconName = activeEvent.iconName;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('event_title', title);
      await prefs.setString('countdown_text', countdown);
      await prefs.setInt('widget_progress_percent', progressPercent);
      await prefs.setString('widget_urgency_color', urgencyColorName);
      if (iconName != null) {
        await prefs.setString('widget_icon_name', iconName);
      }

      // Get theme color for the widget background
      final theme = await SettingsService.instance.getSelectedTheme();
      final Color themeColor;
      if (theme == AppThemeOption.customHex) {
        themeColor = await SettingsService.instance.getCustomColor() ??
            const Color(0xFF00BFA5);
      } else {
        themeColor = AppThemes.primaryColorFor(theme);
      }
      final bgColorHex = '#${themeColor.value.toRadixString(16).substring(2).toUpperCase()}';

      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'countdown': countdown,
        'bgColor': bgColorHex,
        'textColor': '#FFFFFF',
        'progressPercent': progressPercent,
        'urgencyColor': urgencyColorName,
        'iconName': iconName,
      });
    } catch (e) {
      debugPrint('Widget refresh error: $e');
    }
  }

  /// Refresh the Pomodoro widget with current timer state.
  static Future<void> refreshPomodoroWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      final timerText = prefs.getString('pomodoro_timer_text') ?? 'Tap to start';
      final status = prefs.getString('pomodoro_status') ?? 'Focus';
      final completedSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;

      // Calculate pomodoro progress
      final parts = timerText.split(':');
      int progressPercent = 45;
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 25;
        final seconds = int.tryParse(parts[1]) ?? 0;
        final totalSeconds = minutes * 60 + seconds;
        progressPercent = ((totalSeconds / 1500) * 100).round().clamp(0, 100);
      }

      // Resolve theme color
      final theme = await SettingsService.instance.getSelectedTheme();
      final Color themeColor;
      if (theme == AppThemeOption.customHex) {
        themeColor = await SettingsService.instance.getCustomColor() ??
            const Color(0xFF00BFA5);
      } else {
        themeColor = AppThemes.primaryColorFor(theme);
      }
      final bgColorHex = '#${themeColor.value.toRadixString(16).substring(2).toUpperCase()}';

      await prefs.setString('pomodoro_bg_color', bgColorHex);
      await prefs.setInt('pomodoro_progress_percent', progressPercent);
      await prefs.setInt('pomodoro_completed_sessions', completedSessions);

      await _channel.invokeMethod('updatePomodoroWidget', {
        'subject': subject,
        'timerText': timerText,
        'status': status,
        'bgColor': bgColorHex,
        'progressPercent': progressPercent,
        'completedSessions': completedSessions,
      });
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }
}
