import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../db/database_helper.dart';
import '../models/event.dart';
import '../theme/app_themes.dart';
import 'countdown_service.dart';
import 'settings_service.dart';

/// Pushes the currently-active event's countdown data into the shared
/// storage that the native Android AppWidgetProvider reads, then asks
/// Android to redraw the widget. This is called:
///  - once right after the app starts / an event changes
///  - periodically from the workmanager background task (every 30-60 min)
class WidgetService {
  WidgetService._();
  static const String androidWidgetName = 'EventCountdownWidgetProvider';

  static const _kTitle = 'event_title';
  static const _kCountdown = 'countdown_text';
  static const _kBgType = 'widget_bg_type'; // "theme" | "image"
  static const _kBgColor = 'widget_bg_color'; // ARGB int as string
  static const _kTextColor = 'widget_text_color'; // ARGB int as string
  static const _kImagePath = 'widget_image_path';

  static Future<void> refreshWidget() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    final active = CountdownService.getActiveEvent(events, now);

    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final theme = await SettingsService.instance.getSelectedTheme();
    final bgType = await SettingsService.instance.getWidgetBackgroundType();
    final imagePath = await SettingsService.instance.getWidgetImagePath();

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
    if (imagePath != null &&
        bgType == WidgetBackgroundType.customImage) {
      await HomeWidget.saveWidgetData<String>(_kImagePath, imagePath);
    } else {
      await HomeWidget.saveWidgetData<String>(_kImagePath, '');
    }

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
    );
  }

  /// Registers the callback used when the widget itself is tapped/interacted
  /// with while the app is backgrounded. Tapping simply opens the app, which
  /// is handled natively via the PendingIntent set on the widget's root view,
  /// so no special background callback logic is required here.
  static Future<void> registerInteractivityCallback() async {
    // No-op: tap-to-open is handled by a plain launch PendingIntent in the
    // native AppWidgetProvider. Kept as an explicit hook for clarity.
  }
}
