import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';

/// Updates the Android home screen widgets via SharedPreferences + MethodChannel.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.event_countdown/widget');

  /// Refresh the Event Countdown widget with the next upcoming event.
  static Future<void> refreshWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();
      final smartFormat = await SettingsService.instance.getSmartFormatEnabled();

      String title = 'No upcoming events';
      String countdown = '';

      final activeEvent = CountdownService.getActiveEvent(events, now);
      if (activeEvent != null) {
        title = activeEvent.title;
        final result = CountdownService.buildCountdownText(
          activeEvent,
          now,
          smartFormatEnabled: smartFormat,
        );
        countdown = result.text;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('event_title', title);
      await prefs.setString('countdown_text', countdown);

      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'countdown': countdown,
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

      await _channel.invokeMethod('updatePomodoroWidget', {
        'subject': subject,
        'timerText': timerText,
        'status': status,
      });
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }
}
