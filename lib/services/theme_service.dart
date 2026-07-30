// FILE: lib/services/theme_service.dart
// NEW FILE — ThemeNotifier that triggers MaterialApp rebuilds dynamically
// Uses ValueNotifier so MaterialApp can listen and rebuild with new ThemeData

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_themes.dart';

/// Global singleton notifier that MaterialApp listens to for theme changes.
/// Call [setTheme] from anywhere (e.g. SettingsScreen) and the entire app
/// will animate to the new theme instantly.
class ThemeNotifier extends ValueNotifier<_ThemeState> {
  static final ThemeNotifier _instance = ThemeNotifier._internal();
  static ThemeNotifier get instance => _instance;

  ThemeNotifier._internal() : super(_ThemeState(
    themeOption: AppThemeOption.auroraBorealis,
    themeMode: ThemeMode.system,
    customColor: null,
    highContrast: false,
  )) {
    _loadFromPrefs();
  }

  AppThemeOption get themeOption => value.themeOption;
  ThemeMode get themeMode => value.themeMode;
  Color? get customColor => value.customColor;
  bool get highContrast => value.highContrast;

  /// Load saved preferences on startup.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final themeRaw = prefs.getString('selectedTheme');
    final modeRaw = prefs.getString('themeMode');
    final customRaw = prefs.getInt('customColor');
    final hcRaw = prefs.getBool('highContrast');

    AppThemeOption theme = AppThemeOption.auroraBorealis;
    if (themeRaw != null && themeRaw != 'default') {
      try {
        theme = AppThemeOption.values.byName(themeRaw);
      } catch (_) {}
    }

    ThemeMode mode = ThemeMode.system;
    switch (modeRaw) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
    }

    Color? custom;
    if (customRaw != null && customRaw != 0) {
      custom = Color(customRaw);
    }

    value = _ThemeState(
      themeOption: theme,
      themeMode: mode,
      customColor: custom,
      highContrast: hcRaw ?? false,
    );
  }

  /// Change the app theme and persist it.
  Future<void> setTheme(AppThemeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTheme', option.name);
    value = value.copyWith(themeOption: option);
  }

  /// Change theme mode (light/dark/system) and persist it.
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString('themeMode', modeStr);
    value = value.copyWith(themeMode: mode);
  }

  /// Set custom accent color.
  Future<void> setCustomColor(Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove('customColor');
    } else {
      await prefs.setInt('customColor', color.value);
    }
    value = value.copyWith(customColor: color);
  }

  /// Toggle high contrast.
  Future<void> setHighContrast(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrast', enabled);
    value = value.copyWith(highContrast: enabled);
  }

  /// Convenience: get current ThemeData for given brightness.
  ThemeData getThemeData(Brightness brightness, {ColorScheme? dynamicScheme}) {
    return AppThemes.buildTheme(
      value.themeOption,
      brightness: brightness,
      customColor: value.customColor,
      dynamicScheme: value.themeOption == AppThemeOption.materialYou ? dynamicScheme : null,
      highContrast: value.highContrast,
    );
  }
}

/// Immutable state object for ThemeNotifier.
class _ThemeState {
  final AppThemeOption themeOption;
  final ThemeMode themeMode;
  final Color? customColor;
  final bool highContrast;

  const _ThemeState({
    required this.themeOption,
    required this.themeMode,
    this.customColor,
    required this.highContrast,
  });

  _ThemeState copyWith({
    AppThemeOption? themeOption,
    ThemeMode? themeMode,
    Color? customColor,
    bool? highContrast,
  }) {
    return _ThemeState(
      themeOption: themeOption ?? this.themeOption,
      themeMode: themeMode ?? this.themeMode,
      customColor: customColor ?? this.customColor,
      highContrast: highContrast ?? this.highContrast,
    );
  }
}
