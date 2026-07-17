import 'package:flutter/material.dart';
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

  static Future<void> refreshWidget() async {
    final rawEvents = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();

    final expanded = RecurrenceService.expandEvents(rawEvents, now);

    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final theme = await SettingsService.instance.getSelectedTheme();

    Event? active;
    for (final e in expanded) {
      if (e.finalMillis > now.millisecondsSinceEpoch) {
        active = e;
        break;
      }
    }

    String title;
    String countdownText;

    if (active == null) {
      title = 'No upcoming events';
      countdownText = '';
    } else {
      title = active.title;
      countdownText = CountdownService.buildCountdownText(
        active,
        now,
        smartFormatEnabled: smart,
      ).text;
    }

    final themeColor = AppThemes.colorFor(theme);
    final textColor = AppThemes.autoContrastColor(themeColor);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTitle, title);
    await prefs.setString(_kCountdown, countdownText);
    await prefs.setString(_kBgColor, themeColor.value.toString());
    await prefs.setString(_kTextColor, textColor.value.toString());
  }

  static Future<void> registerInteractivityCallback() async {}
}
