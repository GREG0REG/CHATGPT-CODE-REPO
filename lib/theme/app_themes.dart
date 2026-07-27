// FILE: lib/theme/app_themes.dart
// COMPLETE REPLACEMENT — Added missing buildTheme, glassmorphism, gradientColorsFor, materialYou

import 'package:flutter/material.dart';

/// Available app theme options.
/// Existing themes preserved, new cute pastel themes added.
enum AppThemeOption {
  // ── Original themes ──
  auroraBorealis,
  sunsetGlow,
  oceanDepth,
  forestMist,
  midnightCity,
  customHex,

  // ── NEW: Cute pastel themes ──
  strawberryCream,   // 🍓 Soft pink + cream
  cottonCandy,       // 🍬 Pink + blue cotton candy
  peachParfait,      // 🍑 Peach + soft coral
  lavenderMilk,      // 💜 Lavender + milky white
  mintChocolate,     // 🍫 Mint + chocolate
  lemonSorbet,       // 🍋 Soft yellow + cream
  bubblegumPop,      // 🫧 Bright pink + aqua
  sakuraBloom,       // 🌸 Cherry blossom pink + soft green

  // ── Material You (dynamic colors) ──
  materialYou,       // 🎨 System dynamic colors
}

/// Theme metadata for UI display.
class ThemeInfo {
  final AppThemeOption option;
  final String label;
  final List<Color> gradientColors;

  const ThemeInfo({
    required this.option,
    required this.label,
    required this.gradientColors,
  });
}

class AppThemes {
  AppThemes._();

  static const List<ThemeInfo> all = [
    // ── Original themes (preserved) ──
    ThemeInfo(
      option: AppThemeOption.auroraBorealis,
      label: 'Aurora',
      gradientColors: [Color(0xFF00BFA5), Color(0xFF00E5FF)],
    ),
    ThemeInfo(
      option: AppThemeOption.sunsetGlow,
      label: 'Sunset',
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
    ),
    ThemeInfo(
      option: AppThemeOption.oceanDepth,
      label: 'Ocean',
      gradientColors: [Color(0xFF0066CC), Color(0xFF00CCFF)],
    ),
    ThemeInfo(
      option: AppThemeOption.forestMist,
      label: 'Forest',
      gradientColors: [Color(0xFF2E7D32), Color(0xFF81C784)],
    ),
    ThemeInfo(
      option: AppThemeOption.midnightCity,
      label: 'Midnight',
      gradientColors: [Color(0xFF311B92), Color(0xFF7C4DFF)],
    ),

    // ── NEW: Cute pastel themes ──
    ThemeInfo(
      option: AppThemeOption.strawberryCream,
      label: 'Strawberry',
      gradientColors: [Color(0xFFFFC1CC), Color(0xFFFFF0F5)],
    ),
    ThemeInfo(
      option: AppThemeOption.cottonCandy,
      label: 'Cotton Candy',
      gradientColors: [Color(0xFFFFB7E6), Color(0xFFB5E7FF)],
    ),
    ThemeInfo(
      option: AppThemeOption.peachParfait,
      label: 'Peach',
      gradientColors: [Color(0xFFFFDAB9), Color(0xFFFFA07A)],
    ),
    ThemeInfo(
      option: AppThemeOption.lavenderMilk,
      label: 'Lavender',
      gradientColors: [Color(0xFFE6E6FA), Color(0xFFD8BFD8)],
    ),
    ThemeInfo(
      option: AppThemeOption.mintChocolate,
      label: 'Mint Choc',
      gradientColors: [Color(0xFF98FF98), Color(0xFF7B5C3E)],
    ),
    ThemeInfo(
      option: AppThemeOption.lemonSorbet,
      label: 'Lemon',
      gradientColors: [Color(0xFFFFFACD), Color(0xFFFFE4B5)],
    ),
    ThemeInfo(
      option: AppThemeOption.bubblegumPop,
      label: 'Bubblegum',
      gradientColors: [Color(0xFFFF69B4), Color(0xFF7FFFD4)],
    ),
    ThemeInfo(
      option: AppThemeOption.sakuraBloom,
      label: 'Sakura',
      gradientColors: [Color(0xFFFFB7C5), Color(0xFFC8E6C9)],
    ),

    // ── Material You ──
    ThemeInfo(
      option: AppThemeOption.materialYou,
      label: 'Material You',
      gradientColors: [Color(0xFF6750A4), Color(0xFF958DA5)],
    ),

    // ── Custom (always last) ──
    ThemeInfo(
      option: AppThemeOption.customHex,
      label: 'Custom',
      gradientColors: [Color(0xFF9E9E9E), Color(0xFFE0E0E0)],
    ),
  ];

  /// Get theme info by option.
  static ThemeInfo? getInfo(AppThemeOption option) {
    for (final info in all) {
      if (info.option == option) return info;
    }
    return null;
  }

  /// Get the primary color for a theme option.
  static Color getPrimaryColor(AppThemeOption option, {Color? customColor}) {
    final info = getInfo(option);
    if (info == null) return const Color(0xFF00BFA5);
    if (option == AppThemeOption.customHex && customColor != null) {
      return customColor;
    }
    return info.gradientColors.first;
  }

  /// Get gradient colors for a theme option.
  static List<Color>? gradientColorsFor(AppThemeOption option) {
    final info = getInfo(option);
    return info?.gradientColors;
  }

  /// Build a full ThemeData for the given theme option.
  static ThemeData buildTheme(
    AppThemeOption option, {
    required Brightness brightness,
    Color? customColor,
    ColorScheme? dynamicScheme,
    bool highContrast = false,
  }) {
    final Color primaryColor = getPrimaryColor(option, customColor: customColor);

    ColorScheme colorScheme;
    if (option == AppThemeOption.materialYou && dynamicScheme != null) {
      colorScheme = dynamicScheme.copyWith(brightness: brightness);
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      );
    }

    if (highContrast) {
      colorScheme = colorScheme.copyWith(
        surface: brightness == Brightness.dark ? Colors.black : Colors.white,
        onSurface: brightness == Brightness.dark ? Colors.white : Colors.black,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Glassmorphism decoration helper.
  static BoxDecoration glassmorphism({
    required BuildContext context,
    required double opacity,
    required BorderRadius borderRadius,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      borderRadius: borderRadius,
      color: cs.surface.withOpacity(opacity),
      border: Border.all(
        color: cs.outline.withOpacity(0.1),
      ),
    );
  }
}
