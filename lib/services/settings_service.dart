// FILE: lib/services/settings_service.dart
// COMPLETE REPLACEMENT — copy and paste entire file
// FIXED: All getters/setters now use correct types (AppThemeOption, ThemeMode, Color?)
// ADDED: Widget background type, image path, quiet hours settings

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_themes.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  static SettingsService get instance => _instance;
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  // ── Theme helpers ──
  static AppThemeOption _parseAppThemeOption(String? raw) {
    if (raw == null || raw == 'default') return AppThemeOption.auroraBorealis;
    try {
      return AppThemeOption.values.byName(raw);
    } catch (_) {
      return AppThemeOption.auroraBorealis;
    }
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // ============================================
  // THEME SETTINGS
  // ============================================

  /// Returns the currently selected [AppThemeOption]. Defaults to auroraBorealis.
  Future<AppThemeOption> getSelectedTheme() async {
    final prefs = await _preferences;
    final raw = prefs.getString('selectedTheme');
    return _parseAppThemeOption(raw);
  }

  /// Stores the selected [AppThemeOption] as its enum name string.
  Future<void> setSelectedTheme(AppThemeOption theme) async {
    final prefs = await _preferences;
    await prefs.setString('selectedTheme', theme.name);
  }

  /// Returns the current [ThemeMode]. Defaults to [ThemeMode.system].
  Future<ThemeMode> getThemeMode() async {
    final prefs = await _preferences;
    final raw = prefs.getString('themeMode');
    return _parseThemeMode(raw);
  }

  /// Stores the [ThemeMode] as 'light', 'dark', or 'system'.
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await _preferences;
    await prefs.setString('themeMode', _themeModeToString(mode));
  }

  /// Returns the custom accent color, or `null` if none is set.
  /// Stored as int; `0` is treated as null.
  Future<Color?> getCustomColor() async {
    final prefs = await _preferences;
    final value = prefs.getInt('customColor');
    if (value == null || value == 0) return null;
    return Color(value);
  }

  /// Stores a [Color] as int, or clears the entry if `null`.
  Future<void> setCustomColor(Color? color) async {
    final prefs = await _preferences;
    if (color == null) {
      await prefs.remove('customColor');
    } else {
      await prefs.setInt('customColor', color.value);
    }
  }

  /// Returns whether high contrast mode is enabled. Defaults to `false`.
  Future<bool> getHighContrast() async {
    final prefs = await _preferences;
    return prefs.getBool('highContrast') ?? false;
  }

  /// Sets high contrast mode.
  Future<void> setHighContrast(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('highContrast', value);
  }

  /// Returns whether adaptive refresh is enabled. Defaults to `true`.
  Future<bool> getAdaptiveRefreshEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('adaptiveRefreshEnabled') ?? true;
  }

  Future<void> setAdaptiveRefreshEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('adaptiveRefreshEnabled', value);
  }

  // ============================================
  // FIRST LAUNCH
  // ============================================

  /// Returns `true` if this is the first app launch. Defaults to `true`.
  Future<bool> isFirstLaunch() async {
    final prefs = await _preferences;
    return prefs.getBool('isFirstLaunch') ?? true;
  }

  /// Marks first launch as completed (or resets it).
  Future<void> setFirstLaunch(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('isFirstLaunch', value);
  }

  // ============================================
  // FORMAT SETTINGS
  // ============================================

  Future<bool> getSmartFormatEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('smartFormatEnabled') ?? true;
  }

  Future<void> setSmartFormatEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('smartFormatEnabled', value);
  }

  /// Returns whether 24-hour time format is used. Defaults to `false`.
  Future<bool> getUse24HourFormat() async {
    final prefs = await _preferences;
    return prefs.getBool('use24HourFormat') ?? false;
  }

  Future<void> setUse24HourFormat(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('use24HourFormat', value);
  }

  // ============================================
  // NOTIFICATION SETTINGS
  // ============================================

  Future<bool> getNotificationsEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('notificationsEnabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('notificationsEnabled', value);
  }

  Future<bool> getSoundEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('soundEnabled') ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('soundEnabled', value);
  }

  /// Returns the default reminder lead time in minutes. Defaults to `15`.
  Future<int> getDefaultReminderMinutes() async {
    final prefs = await _preferences;
    return prefs.getInt('defaultReminderMinutes') ?? 15;
  }

  Future<void> setDefaultReminderMinutes(int value) async {
    final prefs = await _preferences;
    await prefs.setInt('defaultReminderMinutes', value);
  }

  // ============================================
  // QUIET HOURS SETTINGS (NEW)
  // ============================================

  /// Returns whether quiet hours are enabled. Defaults to `false`.
  Future<bool> getQuietHoursEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('quietHoursEnabled') ?? false;
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('quietHoursEnabled', value);
  }

  /// Returns quiet hours start time as minutes from midnight. Defaults to `22:00` (1320).
  Future<int> getQuietHoursStart() async {
    final prefs = await _preferences;
    return prefs.getInt('quietHoursStart') ?? 1320;
  }

  Future<void> setQuietHoursStart(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('quietHoursStart', minutes);
  }

  /// Returns quiet hours end time as minutes from midnight. Defaults to `07:00` (420).
  Future<int> getQuietHoursEnd() async {
    final prefs = await _preferences;
    return prefs.getInt('quietHoursEnd') ?? 420;
  }

  Future<void> setQuietHoursEnd(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('quietHoursEnd', minutes);
  }

  // ============================================
  // STUDY GOAL SETTINGS
  // ============================================

  Future<int> getDailyStudyGoal() async {
    final prefs = await _preferences;
    return prefs.getInt('dailyStudyGoal') ?? 120; // Default 120 min (2 hours)
  }

  Future<void> setDailyStudyGoal(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('dailyStudyGoal', minutes);
  }

  Future<int> getWeeklyStudyGoal() async {
    final prefs = await _preferences;
    return prefs.getInt('weeklyStudyGoal') ?? 600; // Default 600 min (10 hours)
  }

  Future<void> setWeeklyStudyGoal(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('weeklyStudyGoal', minutes);
  }

  Future<int> getPomodoroDuration() async {
    final prefs = await _preferences;
    return prefs.getInt('pomodoroDuration') ?? 25;
  }

  Future<void> setPomodoroDuration(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('pomodoroDuration', minutes);
  }

  Future<int> getShortBreakDuration() async {
    final prefs = await _preferences;
    return prefs.getInt('shortBreakDuration') ?? 5;
  }

  Future<void> setShortBreakDuration(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('shortBreakDuration', minutes);
  }

  Future<int> getLongBreakDuration() async {
    final prefs = await _preferences;
    return prefs.getInt('longBreakDuration') ?? 15;
  }

  Future<void> setLongBreakDuration(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('longBreakDuration', minutes);
  }

  // ============================================
  // SUBJECT GOAL SETTINGS
  // ============================================

  Future<int> getSubjectWeeklyGoal(String subject) async {
    final prefs = await _preferences;
    return prefs.getInt('subjectGoal_$subject') ?? 120; // Default 120 min/week
  }

  Future<void> setSubjectWeeklyGoal(String subject, int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('subjectGoal_$subject', minutes);
  }

  Future<void> removeSubjectGoal(String subject) async {
    final prefs = await _preferences;
    await prefs.remove('subjectGoal_$subject');
  }

  // ============================================
  // WIDGET SETTINGS
  // ============================================

  Future<bool> getHomeWidgetEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('homeWidgetEnabled') ?? true;
  }

  Future<void> setHomeWidgetEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('homeWidgetEnabled', value);
  }

  Future<bool> getWidgetProgressBar() async {
    final prefs = await _preferences;
    return prefs.getBool('widgetProgressBar') ?? true;
  }

  Future<void> setWidgetProgressBar(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('widgetProgressBar', value);
  }

  Future<bool> getWidgetPulseAnimation() async {
    final prefs = await _preferences;
    return prefs.getBool('widgetPulseAnimation') ?? true;
  }

  Future<void> setWidgetPulseAnimation(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('widgetPulseAnimation', value);
  }

  /// Returns the widget background type as a string.
  /// Typical values: 'themeColor' or 'customImage'. Defaults to 'themeColor'.
  Future<String> getWidgetBackgroundType() async {
    final prefs = await _preferences;
    return prefs.getString('widgetBackgroundType') ?? 'themeColor';
  }

  Future<void> setWidgetBackgroundType(String type) async {
    final prefs = await _preferences;
    await prefs.setString('widgetBackgroundType', type);
  }

  /// Returns the path to the custom widget background image, or `null` if none.
  Future<String?> getWidgetImagePath() async {
    final prefs = await _preferences;
    return prefs.getString('widgetImagePath');
  }

  /// Sets the custom widget background image path, or clears it if `null`.
  Future<void> setWidgetImagePath(String? path) async {
    final prefs = await _preferences;
    if (path == null) {
      await prefs.remove('widgetImagePath');
    } else {
      await prefs.setString('widgetImagePath', path);
    }
  }

  // ============================================
  // EXPORT/IMPORT SETTINGS
  // ============================================

  Future<bool> getAutoBackup() async {
    final prefs = await _preferences;
    return prefs.getBool('autoBackup') ?? false;
  }

  Future<void> setAutoBackup(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('autoBackup', value);
  }

  Future<DateTime?> getLastVacuum() async {
    final prefs = await _preferences;
    final ms = prefs.getInt('lastVacuum');
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastVacuum(DateTime value) async {
    final prefs = await _preferences;
    await prefs.setInt('lastVacuum', value.millisecondsSinceEpoch);
  }

  // ============================================
  // RESET ALL SETTINGS
  // ============================================

  Future<void> resetAll() async {
    final prefs = await _preferences;
    await prefs.clear();
  }
}
