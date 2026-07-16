import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../db/database_helper.dart';
import '../models/event.dart';
import '../theme/app_themes.dart';
import 'countdown_service.dart';
import 'settings_service.dart';

/// Pushes the currently-active event's countdown data into the shared
/// storage that the native Android AppWidgetProvider reads, then asks
/// Android to redraw the widget.
class WidgetService {
  WidgetService._();
  static const String androidWidgetName = 'EventCountdownWidgetProvider';

  static const _kTitle = 'event_title';
  static const _kCountdown = 'countdown_text';
  static const _kBgType = 'widget_bg_type'; // "theme" | "image"
  static const _kBgColor = 'widget_bg_color'; // ARGB int as string
  static const _kTextColor = 'widget_text_color'; // ARGB int as string
  static const _kImagePath = 'widget_image_path';
  static const _kProgressPercent = 'widget_progress_percent';
  static const _kPulseEnabled = 'widget_pulse_enabled';
  static const _kIsUrgent = 'widget_is_urgent';

  static Future<void> refreshWidget() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    final active = CountdownService.getActiveEvent(events, now);

    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final theme = await SettingsService.instance.getSelectedTheme();
    final bgType = await SettingsService.instance.getWidgetBackgroundType();
    final imagePath = await SettingsService.instance.getWidgetImagePath();
    final progressBarEnabled = await SettingsService.instance.getWidgetProgressBar();
    final pulseEnabled = await SettingsService.instance.getWidgetPulseAnimation();

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

      // SESSION 3: Calculate progress percentage
      if (progressBarEnabled && active.startTimeMillis != null && active.deadlineMillis != null) {
        final start = active.startTimeMillis!;
        final deadline = active.deadlineMillis!;
        final total = deadline - start;
        final elapsed = now.millisecondsSinceEpoch - start;
        if (total > 0) {
          progressPercent = ((elapsed / total) * 100).clamp(0, 100).toInt();
        }
      }

      // SESSION 3: Check if under 24 hours (urgent)
      final target = active.deadlineMillis ?? active.startTimeMillis ?? active.dateMillis;
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
      _kBgColor,
      themeColor.value.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      _kTextColor,
      textColor.value.toString(),
    );
    if (imagePath != null && bgType == WidgetBackgroundType.customImage) {
      await HomeWidget.saveWidgetData<String>(_kImagePath, imagePath);
    } else {
      await HomeWidget.saveWidgetData<String>(_kImagePath, '');
    }

    // SESSION 3: Save progress and pulse data
    await HomeWidget.saveWidgetData<int>(_kProgressPercent, progressPercent);
    await HomeWidget.saveWidgetData<bool>(_kPulseEnabled, pulseEnabled && isUrgent);
    await HomeWidget.saveWidgetData<bool>(_kIsUrgent, isUrgent);

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
    );
  }

  static Future<void> registerInteractivityCallback() async {
    // No-op: tap-to-open is handled natively. Kept for clarity.
  }
}
