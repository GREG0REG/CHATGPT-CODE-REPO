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
  static const _kBgType = 'widget_bg_type';
  static const _kBgColor = 'widget_bg_color';
  static const _kTextColor = 'widget_text_color';
  static const _kImagePath = 'widget_image_path';
  static const _kProgressPercent = 'widget_progress_percent';
  static const _kPulseEnabled = 'widget_pulse_enabled';
  static const _kIsUrgent = 'widget_is_urgent';

  static Future<void> refreshWidget() async {
    final rawEvents = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();

    final expanded = RecurrenceService.expandEvents(rawEvents, now);

    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final theme = await SettingsService.instance.getSelectedTheme();
    final bgType = await SettingsService.instance.getWidgetBackgroundType();
    final progressBarEnabled =
        await SettingsService.instance.getWidgetProgressBar();
    final pulseEnabled =
        await SettingsService.instance.getWidgetPulseAnimation();

    Event? active;
    for (final e in expanded) {
      if (e.finalMillis > now.millisecondsSinceEpoch) {
        active = e;
        break;
      }
    }

    String title;
    String countdownText;
    int progressPercent = -1;
    bool isUrgent = false;

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

      if (progressBarEnabled) {
        final start = active.startTimeMillis ?? active.dateMillis;
        final deadline =
            active.deadlineMillis ?? active.startTimeMillis ?? active.dateMillis;

        if (deadline > start) {
          final total = deadline - start;
          final elapsed = now.millisecondsSinceEpoch - start;
          progressPercent = ((elapsed / total) * 100).clamp(0, 100).toInt();
        }
      }

      final target =
          active.deadlineMillis ?? active.startTimeMillis ?? active.dateMillis;
      final diff = Duration(milliseconds: target - now.millisecondsSinceEpoch);
      isUrgent = diff.inHours < 24 && !diff.isNegative;
    }

    final themeColor = AppThemes.colorFor(theme);
    final textColor = AppThemes.autoContrastColor(themeColor);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTitle, title);
    await prefs.setString(_kCountdown, countdownText);
    await prefs.setString(_kBgType,
        bgType == WidgetBackgroundType.customImage ? 'image' : 'theme');
    await prefs.setString(_kBgColor, themeColor.value.toString());
    await prefs.setString(_kTextColor, textColor.value.toString());
    await prefs.setString(_kImagePath, '');
    await prefs.setInt(_kProgressPercent, progressPercent);
    await prefs.setBool(_kPulseEnabled, pulseEnabled);
    await prefs.setBool(_kIsUrgent, isUrgent);

    // Note: Widget will update on next system refresh or when user adds it
    // For immediate update, we'd need a platform channel - not critical
  }

  static Future<void> registerInteractivityCallback() async {
    // No-op
  }
}
