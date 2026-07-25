import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_themes.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

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
  static const _kQuietHoursEnabled = 'quiet_hours_enabled';
  static const _kQuietHoursStart = 'quiet_hours_start';
  static const _kQuietHoursEnd = 'quiet_hours_end';
  static const _kAdaptiveRefresh = 'adaptive_refresh_enabled';
  static const _kLastVacuum = 'last_vacuum_millis';
  static const _kFirstLaunch = 'first_launch';
  static const _kDefaultReminderMinutes = 'default_reminder_minutes';
  static const _kBatteryOptPrompted = 'battery_opt_prompted';
  static const _kLastViewedAttendanceSubject = 'last_viewed_attendance_subject';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<bool> getSmartFormatEnabled() async {
    final p = await _prefs;
    return p.getBool(_kSmartFormat) ?? false;
  }

  Future<void> setSmartFormatEnabled(bool v) async {
    final p = await _prefs;
    await p.setBool(_kSmartFormat, v);
  }

  Future<bool> getUse24HourFormat() async {
    final p = await _prefs;
    return p.getBool(_kUse24Hour) ?? true;
  }

  Future<void> setUse24HourFormat(bool v) async {
    final p = await _prefs;
    await p.setBool(_kUse24Hour, v);
  }

  Future<AppThemeOption> getSelectedTheme() async {
    final p = await _prefs;
    final name = p.getString(_kThemeName) ?? 'auroraBorealis';
    return AppThemeOption.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppThemeOption.auroraBorealis,
    );
  }

  Future<void> setSelectedTheme(AppThemeOption option) async {
    final p = await _prefs;
    await p.setString(_kThemeName, option.name);
  }

  Future<WidgetBackgroundType> getWidgetBackgroundType() async {
    final p = await _prefs;
    final name = p.getString(_kWidgetBgType) ?? 'themeColor';
    return WidgetBackgroundType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => WidgetBackgroundType.themeColor,
    );
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
    final name = p.getString(_kThemeMode) ?? 'system';
    return ThemeMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final p = await _prefs;
    await p.setString(_kThemeMode, mode.name);
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

  Future<bool> getHighContrast() async {
    final p = await _prefs;
    return p.getBool(_kHighContrast) ?? false;
  }

  Future<void> setHighContrast(bool v) async {
    final p = await _prefs;
    await p.setBool(_kHighContrast, v);
  }

  Future<bool> getWidgetProgressBar() async {
    final p = await _prefs;
    return p.getBool(_kWidgetProgressBar) ?? false;
  }

  Future<void> setWidgetProgressBar(bool v) async {
    final p = await _prefs;
    await p.setBool(_kWidgetProgressBar, v);
  }

  Future<bool> getWidgetPulseAnimation() async {
    final p = await _prefs;
    return p.getBool(_kWidgetPulseAnimation) ?? false;
  }

  Future<void> setWidgetPulseAnimation(bool v) async {
    final p = await _prefs;
    await p.setBool(_kWidgetPulseAnimation, v);
  }

  Future<bool> getQuietHoursEnabled() async {
    final p = await _prefs;
    return p.getBool(_kQuietHoursEnabled) ?? false;
  }

  Future<void> setQuietHoursEnabled(bool v) async {
    final p = await _prefs;
    await p.setBool(_kQuietHoursEnabled, v);
  }

  Future<int> getQuietHoursStart() async {
    final p = await _prefs;
    return p.getInt(_kQuietHoursStart) ?? 1320;
  }

  Future<void> setQuietHoursStart(int minutes) async {
    final p = await _prefs;
    await p.setInt(_kQuietHoursStart, minutes);
  }

  Future<int> getQuietHoursEnd() async {
    final p = await _prefs;
    return p.getInt(_kQuietHoursEnd) ?? 420;
  }

  Future<void> setQuietHoursEnd(int minutes) async {
    final p = await _prefs;
    await p.setInt(_kQuietHoursEnd, minutes);
  }

  Future<bool> getAdaptiveRefreshEnabled() async {
    final p = await _prefs;
    return p.getBool(_kAdaptiveRefresh) ?? true;
  }

  Future<void> setAdaptiveRefreshEnabled(bool v) async {
    final p = await _prefs;
    await p.setBool(_kAdaptiveRefresh, v);
  }

  Future<DateTime?> getLastVacuum() async {
    final p = await _prefs;
    final millis = p.getInt(_kLastVacuum);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastVacuum(DateTime dt) async {
    final p = await _prefs;
    await p.setInt(_kLastVacuum, dt.millisecondsSinceEpoch);
  }

  Future<bool> isFirstLaunch() async {
    final p = await _prefs;
    return p.getBool(_kFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunch(bool v) async {
    final p = await _prefs;
    await p.setBool(_kFirstLaunch, v);
  }

  Future<int> getDefaultReminderMinutes() async {
    final p = await _prefs;
    return p.getInt(_kDefaultReminderMinutes) ?? 60;
  }

  Future<void> setDefaultReminderMinutes(int v) async {
    final p = await _prefs;
    await p.setInt(_kDefaultReminderMinutes, v);
  }

  Future<bool> getBatteryOptPrompted() async {
    final p = await _prefs;
    return p.getBool(_kBatteryOptPrompted) ?? false;
  }

  Future<void> setBatteryOptPrompted(bool v) async {
    final p = await _prefs;
    await p.setBool(_kBatteryOptPrompted, v);
  }

  // ==================== ATTENDANCE WIDGET ====================
  
  Future<String?> getLastViewedAttendanceSubject() async {
    final p = await _prefs;
    return p.getString(_kLastViewedAttendanceSubject);
  }

  Future<void> setLastViewedAttendanceSubject(String? subject) async {
    final p = await _prefs;
    if (subject == null) {
      await p.remove(_kLastViewedAttendanceSubject);
    } else {
      await p.setString(_kLastViewedAttendanceSubject, subject);
    }
  }
}
