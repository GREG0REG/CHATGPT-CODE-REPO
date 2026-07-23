// CHATGPT-CODE-REPO-TEST/lib/services/widget_service.dart
// COMPLETE FILE - Fixed widget data writing and refresh logic

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _widgetDataFileName = 'widget_data.json';
  static const String _channel = 'com.example.event_countdown/widget';

  static final MethodChannel _platform = MethodChannel(_channel);

  /// Write widget data to the JSON file that the Android widget reads.
  /// This is the CRITICAL fix - the Kotlin widget provider reads this file.
  static Future<void> refreshWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

      // Find the next upcoming event
      Event? nextEvent;
      for (final e in events) {
        if (e.isCompleted) continue;
        if (e.finalMillis > now.millisecondsSinceEpoch) {
          nextEvent = e;
          break;
        }
      }

      final data = <String, dynamic>{};

      if (nextEvent != null) {
        final result = CountdownService.buildCountdownText(
          nextEvent,
          now,
          smartFormatEnabled: await SettingsService.instance.getSmartFormatEnabled(),
        );

        // Calculate progress percentage
        int progressPercent = 65; // default
        if (nextEvent.startTimeMillis != null && nextEvent.deadlineMillis != null) {
          final total = nextEvent.deadlineMillis! - nextEvent.startTimeMillis!;
          final elapsed = now.millisecondsSinceEpoch - nextEvent.startTimeMillis!;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).toInt().clamp(0, 100);
          }
        } else if (nextEvent.deadlineMillis != null) {
          // Use date as start, deadline as end
          final total = nextEvent.deadlineMillis! - nextEvent.dateMillis;
          final elapsed = now.millisecondsSinceEpoch - nextEvent.dateMillis;
          if (total > 0) {
            progressPercent = ((elapsed / total) * 100).toInt().clamp(0, 100);
          }
        }

        // Urgency color based on time remaining
        final diff = Duration(milliseconds: nextEvent.finalMillis - now.millisecondsSinceEpoch);
        String? urgencyColor;
        if (diff.inDays < 1) {
          urgencyColor = 'red';
        } else if (diff.inDays < 3) {
          urgencyColor = 'deepOrange';
        } else if (diff.inDays < 7) {
          urgencyColor = 'orange';
        } else if (diff.inDays < 30) {
          urgencyColor = 'green';
        }

        data['title'] = nextEvent.title;
        data['countdown'] = result.text;
        data['deadlineMillis'] = nextEvent.finalMillis;
        data['startMillis'] = nextEvent.startTimeMillis ?? nextEvent.dateMillis;
        data['progressPercent'] = progressPercent;
        data['urgencyColor'] = urgencyColor;
        data['smartFormat'] = true;

        // Theme colors
        final theme = await SettingsService.instance.getSelectedTheme();
        final customColor = await SettingsService.instance.getCustomColor();
        final cs = await _getColorScheme(theme, customColor);

        data['bgColor'] = '#${cs.primary.value.toRadixString(16).substring(2).toUpperCase()}';
        data['textColor'] = '#FFFFFF';
      } else {
        data['title'] = 'No upcoming events';
        data['countdown'] = '';
        data['progressPercent'] = 0;
      }

      // Write to app files directory where Kotlin can read it
      final dir = await HomeWidget.getWidgetData<String>('appDir');
      final filePath = '${await _getFilesDir()}/$_widgetDataFileName';
      final file = File(filePath);
      await file.writeAsString(jsonEncode(data));

      debugPrint('Widget data written: $data');

      // Trigger platform widget update
      await _platform.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('Widget refresh error: $e');
    }
  }

  /// Refresh the Pomodoro widget with current timer state
  static Future<void> refreshPomodoroWidget() async {
    try {
      await _platform.invokeMethod('updatePomodoroWidget');
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }

  static Future<String> _getFilesDir() async {
    try {
      final result = await _platform.invokeMethod<String>('getFilesDir');
      return result ?? '/data/data/com.example.event_countdown/files';
    } catch (e) {
      return '/data/data/com.example.event_countdown/files';
    }
  }

  static Future<ColorScheme> _getColorScheme(AppThemeOption theme, Color? customColor) async {
    // Return a basic color scheme based on theme
    switch (theme) {
      case AppThemeOption.customHex:
        return ColorScheme.fromSeed(seedColor: customColor ?? const Color(0xFF00BFA5));
      case AppThemeOption.materialYou:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      default:
        return ColorScheme.fromSeed(seedColor: const Color(0xFF00BFA5));
    }
  }
}

// Stub for AppThemeOption if not imported
enum AppThemeOption {
  auroraBorealis,
  midnightOcean,
  sunsetGlow,
  forestMist,
  materialYou,
  customHex,
}
