import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/event.dart';
import 'recurrence_service.dart';
import '../theme/app_themes.dart';
import 'countdown_service.dart';
import 'settings_service.dart';

class WidgetService {
  WidgetService._();
  static const String androidWidgetName = 'EventCountdownWidgetProvider';

  static const _kTitle = 'event_title';
  static const _kCountdown = 'countdown_text';
  static const _kBgColor = 'widget_bg_color';
  static const _kTextColor = 'widget_text_color';
  
  static const MethodChannel _channel = MethodChannel('com.example.event_countdown/widget');

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<void> refreshWidget() async {
    developer.log('WIDGET: Starting refreshWidget()', name: 'WidgetService');
    
    final rawEvents = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    developer.log('WIDGET: Found ${rawEvents.length} raw events', name: 'WidgetService');

    final expanded = RecurrenceService.expandEvents(rawEvents, now);
    developer.log('WIDGET: Expanded to ${expanded.length} events', name: 'WidgetService');

    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final theme = await SettingsService.instance.getSelectedTheme();

    Event? active;
    for (final e in expanded) {
      if (e.finalMillis > now.millisecondsSinceEpoch) {
        active = e;
        developer.log('WIDGET: Found active event: ${e.title}', name: 'WidgetService');
        break;
      }
    }

    String title;
    String countdownText;

    if (active == null) {
      title = 'No upcoming events';
      countdownText = '';
      developer.log('WIDGET: No active event found', name: 'WidgetService');
    } else {
      title = active.title;
      countdownText = CountdownService.buildCountdownText(
        active,
        now,
        smartFormatEnabled: smart,
      ).text;
      developer.log('WIDGET: Active event title=$title countdown=$countdownText', name: 'WidgetService');
    }

    final themeColor = AppThemes.colorFor(theme);
    final textColor = AppThemes.autoContrastColor(themeColor);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTitle, title);
    await prefs.setString(_kCountdown, countdownText);
    await prefs.setString(_kBgColor, _colorToHex(themeColor));
    await prefs.setString(_kTextColor, _colorToHex(textColor));
    
    developer.log('WIDGET: Saved to SharedPreferences', name: 'WidgetService');

    // Send data directly to Android so it updates right now
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'countdown': countdownText,
        'bgColor': _colorToHex(themeColor),
        'textColor': _colorToHex(textColor),
      });
      developer.log('WIDGET: Platform channel update triggered', name: 'WidgetService');
    } catch (e) {
      developer.log('WIDGET: Platform channel failed: $e', name: 'WidgetService');
    }
  }

  static Future<void> registerInteractivityCallback() async {}
}
