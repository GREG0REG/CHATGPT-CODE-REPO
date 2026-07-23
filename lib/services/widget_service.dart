import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';
import '../theme/app_themes.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const MethodChannel _channel = MethodChannel('com.example.event_countdown/widget');

  // Keys for SharedPreferences (used as fallback)
  static const String _kEventTitle = 'flutter.event_title';
  static const String _kCountdownText = 'flutter.countdown_text';
  static const String _kBgColor = 'flutter.widget_bg_color';
  static const String _kTextColor = 'flutter.widget_text_color';
  static const String _kProgress = 'flutter.widget_progress_percent';
  static const String _kUrgencyColor = 'flutter.widget_urgency_color';
  static const String _kEventDeadline = 'flutter.widget_event_deadline_millis';
  static const String _kEventStart = 'flutter.widget_event_start_millis';
  static const String _kSmartFormat = 'flutter.widget_smart_format_enabled';

  // Write widget data to a JSON file that Android can read
  static Future<void> _writeWidgetData(Map<String, dynamic> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/widget_data.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('WidgetService._writeWidgetData error: $e');
    }
  }

  static Future<void> refreshWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

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
      int? deadlineMillis;
      int? startMillis;

      if (nextEvent == null) {
        title = 'No upcoming events';
        countdownText = '';
        progressPercent = 0;
        urgencyColorName = null;
        deadlineMillis = null;
        startMillis = null;
      } else {
        title = nextEvent.title;
        deadlineMillis = nextEvent.finalMillis;
        startMillis = nextEvent.startTimeMillis;
        final result = CountdownService.buildCountdownText(nextEvent, now, smartFormatEnabled: smartFormat);
        countdownText = result.text;

        if (nextEvent.startTimeMillis != null && nextEvent.deadlineMillis != null) {
          final total = nextEvent.deadlineMillis! - nextEvent.startTimeMillis!;
          final elapsed = now.millisecondsSinceEpoch - nextEvent.startTimeMillis!;
          progressPercent = total > 0 ? ((elapsed / total) * 100).round().clamp(0, 100) : 65;
        } else {
          progressPercent = 65;
        }

        final urgencyColor = nextEvent.getUrgencyColor(now);
        urgencyColorName = _colorToName(urgencyColor);

        final themeColors = _getThemeColors(theme, customColor);
        bgColor = themeColors['bg'];
        textColor = themeColors['text'];
      }

      // Save to SharedPreferences
      await prefs.setString(_kEventTitle, title);
      await prefs.setString(_kCountdownText, countdownText);
      if (bgColor != null) await prefs.setString(_kBgColor, bgColor);
      if (textColor != null) await prefs.setString(_kTextColor, textColor);
      await prefs.setInt(_kProgress, progressPercent);
      await prefs.setBool(_kSmartFormat, smartFormat);

      if (deadlineMillis != null) {
        await prefs.setInt(_kEventDeadline, deadlineMillis);
      } else {
        await prefs.remove(_kEventDeadline);
      }
      if (startMillis != null) {
        await prefs.setInt(_kEventStart, startMillis);
      } else {
        await prefs.remove(_kEventStart);
      }

      if (urgencyColorName != null) {
        await prefs.setString(_kUrgencyColor, urgencyColorName);
      } else {
        await prefs.remove(_kUrgencyColor);
      }

      // ALSO write to JSON file for reliable Android access
      await _writeWidgetData({
        'title': title,
        'countdown': countdownText,
        'bgColor': bgColor,
        'textColor': textColor,
        'progressPercent': progressPercent,
        'urgencyColor': urgencyColorName,
        'deadlineMillis': deadlineMillis,
        'startMillis': startMillis,
        'smartFormat': smartFormat,
      });

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

  static String? _colorToName(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.deepOrange) return 'deepOrange';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.green) return 'green';
    if (color == Colors.grey) return 'grey';
    return null;
  }

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
