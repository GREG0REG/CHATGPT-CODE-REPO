import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Keys WITHOUT flutter. prefix — native side reads these directly
  static const String _kEventTitle = 'event_title';
  static const String _kCountdownText = 'countdown_text';
  static const String _kBgColor = 'widget_bg_color';
  static const String _kTextColor = 'widget_text_color';
  static const String _kProgress = 'widget_progress_percent';
  static const String _kUrgencyColor = 'widget_urgency_color';
  static const String _kEventDeadline = 'widget_event_deadline_millis';
  static const String _kEventStart = 'widget_event_start_millis';
  static const String _kSmartFormat = 'widget_smart_format_enabled';

  static const String _kPomodoroSubject = 'pomodoro_subject';
  static const String _kPomodoroTimer = 'pomodoro_timer_text';
  static const String _kPomodoroStatus = 'pomodoro_status';
  static const String _kPomodoroBgColor = 'pomodoro_bg_color';
  static const String _kPomodoroProgress = 'pomodoro_progress_percent';
  static const String _kPomodoroSessions = 'pomodoro_completed_sessions';

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

      // Write all prefs BEFORE calling native update
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

      // Force commit to disk before native read
      await prefs.reload();

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

  static Future<void> refreshPomodoroWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final phaseName = prefs.getString('pomodoro_phase') ?? 'idle';
      final remainingSeconds = prefs.getInt('pomodoro_remaining_seconds') ?? 0;
      final completedSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;
      final subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
      final status = prefs.getString('pomodoro_status') ?? 'Focus';

      final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
      final timerText = phaseName == 'idle' ? 'Tap to start' : '$minutes:$seconds';

      final progressPercent = prefs.getDouble('pomodoro_progress_percent') ?? 0.0;
      final progressInt = (progressPercent * 100).round().clamp(0, 100);

      String? bgColor;
      if (phaseName == 'focusing' || phaseName == 'idle' || phaseName == 'paused') {
        bgColor = '#FF6B6B';
      } else {
        bgColor = '#00BFA5';
      }

      await prefs.setString(_kPomodoroSubject, subject);
      await prefs.setString(_kPomodoroTimer, timerText);
      await prefs.setString(_kPomodoroStatus, status);
      await prefs.setString(_kPomodoroBgColor, bgColor);
      await prefs.setInt(_kPomodoroProgress, progressInt);
      await prefs.setInt(_kPomodoroSessions, completedSessions);
      await prefs.reload();

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
