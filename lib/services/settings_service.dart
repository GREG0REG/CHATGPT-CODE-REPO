import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_themes.dart';

enum WidgetBackgroundType { themeColor, customImage }

/// Wraps shared_preferences for all app settings. Everything here is
/// local-only; nothing is ever sent over the network.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  // --- Existing keys (Session 1) ---
  static const _kSmartFormat = 'smart_countdown_format';
  static const _kUse24Hour = 'use_24_hour_time';
  static const _kThemeName = 'selected_theme';
  static const _kWidgetBgType = 'widget_background_type';
  static const _kWidgetImagePath = 'widget_custom_image_path';

  // --- New keys (Session 2) ---
  static const _kThemeMode = 'theme_mode'; // 0=system, 1=light, 2=dark
  static const _kCustomColor = 'custom_color'; // ARGB int
  static const _kHighContrast = 'high_contrast'; // bool

  // --- New keys (Session 3) ---
  static const _kWidgetProgressBar = 'widget_progress_bar'; // bool
  static const _kWidgetPulseAnimation = 'widget_pulse_animation'; // bool

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ============================================
  // EXISTING SETTINGS (Session 1) — preserved
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

  // ============================================
  // SESSION 2 SETTINGS
  // ============================================

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

  // ============================================
  // SESSION 3: WIDGET ENHANCEMENTS
  // ============================================

  /// Whether to show progress bar on widget (default: false)
  Future<bool> getWidgetProgressBar() async {
    final p = await _prefs;
    return p.getBool(_kWidgetProgressBar) ?? false;
  }

  Future<void> setWidgetProgressBar(bool value) async {
    final p = await _prefs;
    await p.setBool(_kWidgetProgressBar, value);
  }

  /// Whether to enable pulse animation on widget when under 24h (default: false)
  Future<bool> getWidgetPulseAnimation() async {
    final p = await _prefs;
    return p.getBool(_kWidgetPulseAnimation) ?? false;
  }

  Future<void> setWidgetPulseAnimation(bool value) async {
    final p = await _prefs;
    await p.setBool(_kWidgetPulseAnimation, value);
  }
}
