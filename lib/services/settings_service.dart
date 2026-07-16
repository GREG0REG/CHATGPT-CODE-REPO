import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_themes.dart';

enum WidgetBackgroundType { themeColor, customImage }

/// Wraps shared_preferences for all app settings.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  // --- Existing keys (Session 1-3) ---
  static const _kSmartFormat = 'smart_countdown_format';
  static const _kUse24Hour = 'use_24_hour_time';
  static const _kThemeName = 'selected_theme';
  static const _kWidgetBgType = 'widget_background_type';
  static const _kWidgetImagePath = 'widget_custom_image_path';
  static const _kThemeMode = 'theme_mode';
  static const _kCustomColor = 'custom_color';
  static const _kHighContrast = 'high_contrast';
  static const _kWidgetProgressBar = 'widget_progress_bar';
  static const _kWidgetPulseAnimation = 'widget_pulse_animation';

  // --- Session 4 keys ---
  static const _kQuietHoursEnabled = 'quiet_hours_enabled';
  static const _kQuietHoursStart = 'quiet_hours_start'; // minutes from midnight
  static const _kQuietHoursEnd = 'quiet_hours_end'; // minutes from midnight
  static const _kDefaultReminderMinutes = 'default_reminder_minutes'; // default custom reminder

  // --- Session 9 keys ---
  static const _kBatteryOptimization = 'battery_optimization_enabled';
  static const _kAdaptiveRefresh = 'adaptive_refresh_enabled';
  static const _kLastVacuumMillis = 'last_vacuum_millis';
  static const _kFirstLaunch = 'first_launch';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ============================================
  // EXISTING SETTINGS (Sessions 1-3)
  // ============================================

  Future<bool> getSmartFormatEnabled() async {
    final p = await _prefs;
    return p.getBool(_kSmartFormat) ?? false;
  }

  Future<void> setSmartFormatEnabled(bool value) async {
    final p = await _prefs;
    await p.setBool(_kSmartFormat, value);
  }

  Future<bool> getUse24HourFormat() async {
    final p = await _prefs;
    return p.getBool(_kUse24Hour) ?? true;
  }

  Future<void> setUse24HourFormat(bool value) async {
    final p = await _prefs;
    await p.setBool(_kUse24Hour, value);
  }

  Future<AppThemeOption> getSelectedTheme() async {
    final p = await _prefs;
    return AppThemes.fromName(p.getString(_kThemeName));
  }

  Future<void> setSelectedTheme(AppThemeOption option) async {
    final p = await _prefs;
    await p.setString(_kThemeName, AppThemes.nameOf(option));
  }

  Future<WidgetBackgroundType> getWidgetBackgroundType() async {
    final p = await _prefs;
    final raw = p.getString(_kWidgetBgType);
    if (raw == WidgetBackgroundType.customImage.name) {
      return WidgetBackgroundType.customImage;
    }
    return WidgetBackgroundType.themeColor;
  }

  Future<void> setWidgetBackgroundType(WidgetBackgroundType type) async {
    final p = await _prefs;
    await p.setString(_kWidgetBgType, type.name);
  }

  Future<String?> getWidgetImagePath() async {
    final p = await _prefs;
    return p.getString(_kWidgetImagePath);
  }

  Future<void> setWidgetImagePath(String? path) async {
    final p = await _prefs;
    if (path == null) {
      await p.remove(_kWidgetImagePath);
    } else {
      await p.setString(_kWidgetImagePath, path);
    }
  }

  Future<ThemeMode> getThemeMode() async {
    final p = await _prefs;
    final index = p.getInt(_kThemeMode) ?? 0;
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final p = await _prefs;
    await p.setInt(_kThemeMode, mode.index);
  }

  Future<Color?> getCustomColor() async {
    final p = await _prefs;
    final value = p.getInt(_kCustomColor);
    if (value == null) return null;
    return Color(value);
  }

  Future<void> setCustomColor(Color color) async {
    final p = await _prefs;
    await p.setInt(_kCustomColor, color.value);
  }

  Future<void> clearCustomColor() async {
    final p = await _prefs;
    await p.remove(_kCustomColor);
  }

  Future<bool> getHighContrast() async {
    final p = await _prefs;
    return p.getBool(_kHighContrast) ?? false;
  }

  Future<void> setHighContrast(bool value) async {
    final p = await _prefs;
    await p.setBool(_kHighContrast, value);
  }

  Future<bool> getWidgetProgressBar() async {
    final p = await _prefs;
    return p.getBool(_kWidgetProgressBar) ?? false;
  }

  Future<void> setWidgetProgressBar(bool value) async {
    final p = await _prefs;
    await p.setBool(_kWidgetProgressBar, value);
  }

  Future<bool> getWidgetPulseAnimation() async {
    final p = await _prefs;
    return p.getBool(_kWidgetPulseAnimation) ?? false;
  }

  Future<void> setWidgetPulseAnimation(bool value) async {
    final p = await _prefs;
    await p.setBool(_kWidgetPulseAnimation, value);
  }

  // ============================================
  // SESSION 4: Quiet Hours
  // ============================================

  Future<bool> getQuietHoursEnabled() async {
    final p = await _prefs;
    return p.getBool(_kQuietHoursEnabled) ?? false;
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    final p = await _prefs;
    await p.setBool(_kQuietHoursEnabled, value);
  }

  /// Returns quiet hours start as minutes from midnight (default 22:00 = 1320).
  Future<int> getQuietHoursStart() async {
    final p = await _prefs;
    return p.getInt(_kQuietHoursStart) ?? 1320;
  }

  Future<void> setQuietHoursStart(int minutes) async {
    final p = await _prefs;
    await p.setInt(_kQuietHoursStart, minutes);
  }

  /// Returns quiet hours end as minutes from midnight (default 07:00 = 420).
  Future<int> getQuietHoursEnd() async {
    final p = await _prefs;
    return p.getInt(_kQuietHoursEnd) ?? 420;
  }

  Future<void> setQuietHoursEnd(int minutes) async {
    final p = await _prefs;
    await p.setInt(_kQuietHoursEnd, minutes);
  }

  Future<int> getDefaultReminderMinutes() async {
    final p = await _prefs;
    return p.getInt(_kDefaultReminderMinutes) ?? 60;
  }

  Future<void> setDefaultReminderMinutes(int minutes) async {
    final p = await _prefs;
    await p.setInt(_kDefaultReminderMinutes, minutes);
  }

  // ============================================
  // SESSION 9: Battery & Performance
  // ============================================

  Future<bool> getBatteryOptimizationEnabled() async {
    final p = await _prefs;
    return p.getBool(_kBatteryOptimization) ?? true;
  }

  Future<void> setBatteryOptimizationEnabled(bool value) async {
    final p = await _prefs;
    await p.setBool(_kBatteryOptimization, value);
  }

  Future<bool> getAdaptiveRefreshEnabled() async {
    final p = await _prefs;
    return p.getBool(_kAdaptiveRefresh) ?? true;
  }

  Future<void> setAdaptiveRefreshEnabled(bool value) async {
    final p = await _prefs;
    await p.setBool(_kAdaptiveRefresh, value);
  }

  Future<DateTime?> getLastVacuum() async {
    final p = await _prefs;
    final millis = p.getInt(_kLastVacuumMillis);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastVacuum(DateTime time) async {
    final p = await _prefs;
    await p.setInt(_kLastVacuumMillis, time.millisecondsSinceEpoch);
  }

  Future<bool> isFirstLaunch() async {
    final p = await _prefs;
    return p.getBool(_kFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunch(bool value) async {
    final p = await _prefs;
    await p.setBool(_kFirstLaunch, value);
  }

  // ============================================
  // SESSION 4: Quiet hours check
  // ============================================

  /// Returns true if current time falls within quiet hours.
  Future<bool> isInQuietHours(DateTime now) async {
    if (!await getQuietHoursEnabled()) return false;

    final start = await getQuietHoursStart();
    final end = await getQuietHoursEnd();
    final nowMinutes = now.hour * 60 + now.minute;

    if (start < end) {
      // Same day range (e.g. 10:00 - 14:00)
      return nowMinutes >= start && nowMinutes < end;
    } else {
      // Overnight range (e.g. 22:00 - 07:00)
      return nowMinutes >= start || nowMinutes < end;
    }
  }
}
