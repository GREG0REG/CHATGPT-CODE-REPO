import 'package:flutter/material.dart';

/// Expanded theme options for Session 2.
/// Existing names preserved for backward compatibility with SharedPreferences.
enum AppThemeOption {
  defaultBlue,
  sunsetOrange, // Now a true gradient: orange → purple
  forestGreen, // Now a true gradient: green → lime
  oceanTeal, // Now a true gradient: teal → blue
  midnightPurple,
  amoledBlack, // NEW: Pitch black #000000
  customHex, // NEW: User-defined color
  materialYou, // NEW: Android 12+ dynamic colors
}

class AppThemeInfo {
  final AppThemeOption option;
  final String label;
  final Color color; // Primary/seed color
  final bool isGradient;
  final List<Color>? gradientColors;
  final IconData icon;

  const AppThemeInfo({
    required this.option,
    required this.label,
    required this.color,
    this.isGradient = false,
    this.gradientColors,
    required this.icon,
  });
}

class AppThemes {
  AppThemes._();

  static const List<AppThemeInfo> all = [
    AppThemeInfo(
      option: AppThemeOption.defaultBlue,
      label: 'Default Blue',
      color: Color(0xFF2196F3),
      icon: Icons.color_lens,
    ),
    AppThemeInfo(
      option: AppThemeOption.sunsetOrange,
      label: 'Sunset Gradient',
      color: Color(0xFFFF5722),
      isGradient: true,
      gradientColors: [Color(0xFFFF9800), Color(0xFF9C27B0)],
      icon: Icons.wb_twilight,
    ),
    AppThemeInfo(
      option: AppThemeOption.forestGreen,
      label: 'Forest Gradient',
      color: Color(0xFF4CAF50),
      isGradient: true,
      gradientColors: [Color(0xFF4CAF50), Color(0xFFCDDC39)],
      icon: Icons.forest,
    ),
    AppThemeInfo(
      option: AppThemeOption.oceanTeal,
      label: 'Ocean Gradient',
      color: Color(0xFF009688),
      isGradient: true,
      gradientColors: [Color(0xFF009688), Color(0xFF2196F3)],
      icon: Icons.water,
    ),
    AppThemeInfo(
      option: AppThemeOption.midnightPurple,
      label: 'Midnight Purple',
      color: Color(0xFF673AB7),
      icon: Icons.nightlight_round,
    ),
    AppThemeInfo(
      option: AppThemeOption.amoledBlack,
      label: 'AMOLED Black',
      color: Color(0xFF000000),
      icon: Icons.dark_mode,
    ),
    AppThemeInfo(
      option: AppThemeOption.customHex,
      label: 'Custom Color',
      color: Color(0xFF2196F3), // Fallback
      icon: Icons.colorize,
    ),
    AppThemeInfo(
      option: AppThemeOption.materialYou,
      label: 'Material You',
      color: Color(0xFF2196F3), // Fallback
      icon: Icons.auto_awesome,
    ),
  ];

  static AppThemeInfo infoFor(AppThemeOption option) {
    return all.firstWhere(
      (t) => t.option == option,
      orElse: () => all.first,
    );
  }

  static Color colorFor(AppThemeOption option) => infoFor(option).color;

  static String nameOf(AppThemeOption option) => option.name;

  static AppThemeOption fromName(String? name) {
    return all
        .map((t) => t.option)
        .firstWhere((o) => o.name == name, orElse: () => AppThemeOption.defaultBlue);
  }

  /// Build theme data. For light/dark mode support, [brightness] should be
  /// provided. [customColor] is required when [option] is [customHex].
  /// [dynamicScheme] is used when [option] is [materialYou].
  static ThemeData buildTheme(
    AppThemeOption option, {
    Brightness brightness = Brightness.light,
    Color? customColor,
    ColorScheme? dynamicScheme,
    bool highContrast = false,
  }) {
    final isDark = brightness == Brightness.dark;

    // Determine base color scheme
    ColorScheme colorScheme;
    Color primaryColor;

    switch (option) {
      case AppThemeOption.materialYou:
        colorScheme = dynamicScheme ?? _defaultScheme(brightness);
        primaryColor = colorScheme.primary;
        break;

      case AppThemeOption.customHex:
        final seed = customColor ?? Colors.blue;
        primaryColor = seed;
        colorScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        );
        break;

      case AppThemeOption.amoledBlack:
        colorScheme = _amoledScheme(isDark);
        primaryColor = colorScheme.primary;
        break;

      case AppThemeOption.sunsetOrange:
      case AppThemeOption.forestGreen:
      case AppThemeOption.oceanTeal:
        final info = infoFor(option);
        primaryColor = info.color;
        colorScheme = ColorScheme.fromSeed(
          seedColor: info.color,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? info.color.withOpacity(0.9) : info.color,
          secondary: isDark
              ? info.gradientColors?.last.withOpacity(0.9)
              : info.gradientColors?.last,
        );
        break;

      case AppThemeOption.defaultBlue:
      case AppThemeOption.midnightPurple:
        primaryColor = colorFor(option);
        colorScheme = ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: brightness,
        );
        break;
    }

    // Apply high contrast if enabled
    if (highContrast) {
      colorScheme = colorScheme.copyWith(
        surface: isDark ? Colors.black : Colors.white,
        onSurface: isDark ? Colors.white : Colors.black,
      );
    }

    // AMOLED-specific overrides
    final scaffoldBg = option == AppThemeOption.amoledBlack && isDark
        ? Colors.black
        : colorScheme.surface;

    final cardColor = option == AppThemeOption.amoledBlack && isDark
        ? const Color(0xFF0A0A0A)
        : colorScheme.surfaceContainerHighest;

    final cardElevation = option == AppThemeOption.amoledBlack && isDark ? 0.0 : 1.0;

    final dividerColor = option == AppThemeOption.amoledBlack && isDark
        ? Colors.grey.shade900
        : colorScheme.outlineVariant;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      cardTheme: CardTheme(
        elevation: cardElevation,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: option == AppThemeOption.amoledBlack && isDark
              ? BorderSide(color: Colors.grey.shade900, width: 1)
              : BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: option == AppThemeOption.amoledBlack && isDark
            ? Colors.black
            : colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: dividerColor),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ColorScheme _defaultScheme(Brightness brightness) {
    return ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness);
  }

  static ColorScheme _amoledScheme(bool isDark) {
    if (!isDark) {
      return _defaultScheme(Brightness.light);
    }
    return const ColorScheme.dark(
      primary: Color(0xFF90CAF9),
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF1565C0),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF80CBC4),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF00695C),
      onSecondaryContainer: Colors.white,
      surface: Colors.black,
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF0A0A0A),
      onSurfaceVariant: Colors.white70,
      outline: Colors.grey,
      outlineVariant: Color(0xFF1A1A1A),
      error: Color(0xFFEF5350),
      onError: Colors.black,
      errorContainer: Color(0xFFB71C1C),
      onErrorContainer: Colors.white,
      brightness: Brightness.dark,
    );
  }

  /// Auto-contrast: white text on dark backgrounds, black text on light ones.
  static Color autoContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Get gradient colors for the current theme option.
  static List<Color>? gradientColorsFor(AppThemeOption option) {
    final info = infoFor(option);
    return info.gradientColors;
  }

  /// Check if the option is a gradient theme.
  static bool isGradient(AppThemeOption option) {
    return infoFor(option).isGradient;
  }
}
