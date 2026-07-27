// FILE: lib/theme/app_themes.dart
// COMPLETE REPLACEMENT — Added 8 new cute pastel themes
// All existing themes preserved. New themes are unique and different.

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
}
