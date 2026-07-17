import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

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

    // EXPAND recurring events for widget
    final expanded = RecurrenceService.expandEvents(rawEvents, now);

    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final theme = await SettingsService.instance.getSelectedTheme();
    final bgType = await SettingsService.instance.getWidgetBackgroundType();
    final imagePath = await SettingsService.instance.getWidgetImagePath();
    final progressBarEnabled =
        await SettingsService.instance.getWidgetProgressBar();
    final pulseEnabled =
        await SettingsService.instance.getWidgetPulseAnimation();

    // Find first active event from expanded list
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

    await HomeWidget.saveWidgetData<String>(_kTitle, title);
    await HomeWidget.saveWidgetData<String>(_kCountdown, countdownText);
    await HomeWidget.saveWidgetData<String>(
      _kBgType,
      bgType == WidgetBackgroundType.customImage ? 'image' : 'theme',
    );
    await HomeWidget.saveWidgetData<String>(
        _kBgColor, themeColor.value.toString());
    await HomeWidget.saveWidgetData<String>(
        _kTextColor, textColor.value.toString());
    if (imagePath != null && bgType == WidgetBackgroundType.customImage) {
      await HomeWidget.saveWidgetData<String>(_kImagePath, imagePath);
    } else {
      await HomeWidget.saveWidgetData<String>(_kImagePath, '');
    }

    await HomeWidget.saveWidgetData<int>(_kProgressPercent, progressPercent);
    await HomeWidget.saveWidgetData<bool>(_kPulseEnabled, pulseEnabled);
    await HomeWidget.saveWidgetData<bool>(_kIsUrgent, isUrgent);

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
    );
  }

  static Future<void> registerInteractivityCallback() async {
    // No-op: tap-to-open is handled natively.
  }
}
