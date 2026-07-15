import 'package:flutter/material.dart';

/// EXACTLY 5 themes. Do not add more.
enum AppThemeOption {
  defaultBlue,
  sunsetOrange,
  forestGreen,
  oceanTeal,
  midnightPurple,
}

class AppThemeInfo {
  final AppThemeOption option;
  final String label;
  final Color color;

  const AppThemeInfo(this.option, this.label, this.color);
}

class AppThemes {
  AppThemes._();

  static const List<AppThemeInfo> all = [
    AppThemeInfo(AppThemeOption.defaultBlue, 'Default Blue', Color(0xFF2196F3)),
    AppThemeInfo(AppThemeOption.sunsetOrange, 'Sunset Orange', Color(0xFFFF5722)),
    AppThemeInfo(AppThemeOption.forestGreen, 'Forest Green', Color(0xFF4CAF50)),
    AppThemeInfo(AppThemeOption.oceanTeal, 'Ocean Teal', Color(0xFF009688)),
    AppThemeInfo(AppThemeOption.midnightPurple, 'Midnight Purple', Color(0xFF673AB7)),
  ];

  static AppThemeInfo infoFor(AppThemeOption option) {
    return all.firstWhere((t) => t.option == option);
  }

  static Color colorFor(AppThemeOption option) => infoFor(option).color;

  static String nameOf(AppThemeOption option) => option.name;

  static AppThemeOption fromName(String? name) {
    return all
        .map((t) => t.option)
        .firstWhere((o) => o.name == name, orElse: () => AppThemeOption.defaultBlue);
  }

  static ThemeData buildTheme(AppThemeOption option) {
    final seed = colorFor(option);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: _autoContrastColor(seed),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: _autoContrastColor(seed),
      ),
    );
  }

  /// Auto-contrast: white text on dark backgrounds, black text on light ones.
  static Color _autoContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static Color autoContrastColor(Color background) => _autoContrastColor(background);
}
