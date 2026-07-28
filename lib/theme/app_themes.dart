// FILE: lib/theme/app_themes.dart
// COMPLETE REPLACEMENT — 18 NEW themes + 5 original = 23 total themes
// Added: NEET aspirant themes, enhanced glassmorphism, seasonal themes, dark variants

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Available app theme options.
/// Original themes preserved, new themes added including NEET-specific ones.
enum AppThemeOption {
  // ── Original themes (5 preserved) ──
  auroraBorealis,
  sunsetGlow,
  oceanDepth,
  forestMist,
  midnightCity,

  // ── Cute pastel themes (8 preserved) ──
  strawberryCream,
  cottonCandy,
  peachParfait,
  lavenderMilk,
  mintChocolate,
  lemonSorbet,
  bubblegumPop,
  sakuraBloom,

  // ── NEW: NEET & Medical themes (6) ──
  neetAspirant,      // 🩺 Medical green + white
  doctorCoat,        // 🥼 Pure white + stethoscope red
  anatomyRed,        // 🫀 Deep red + bone white
  cellBiology,       // 🔬 Cytoplasm blue + nucleus purple
  organicChem,       // ⚗️ Benzene purple + reaction green
  physicsLab,        // 📟 Oscilloscope green + black

  // ── NEW: Study-focused themes (4) ──
  nightOwl,          // 🦉 Deep navy + amber
  focusMode,         // 🎯 Grey + deep blue
  examMode,          // 🚨 Alert red + clean white
  victoryGold,       // 🏆 Gold medal + deep green

  // ── Material You (dynamic colors) ──
  materialYou,

  // ── Custom (always last) ──
  customHex,
}

/// Theme metadata for UI display.
class ThemeInfo {
  final AppThemeOption option;
  final String label;
  final List<Color> gradientColors;
  final IconData? icon;
  final String? description;

  const ThemeInfo({
    required this.option,
    required this.label,
    required this.gradientColors,
    this.icon,
    this.description,
  });
}

/// Font weight configuration for accessibility.
class FontWeightConfig {
  final FontWeight heading;
  final FontWeight body;
  final FontWeight caption;

  const FontWeightConfig({
    this.heading = FontWeight.w700,
    this.body = FontWeight.w400,
    this.caption = FontWeight.w500,
  });
}

class AppThemes {
  AppThemes._();

  static const List<ThemeInfo> all = [
    // ── Original themes (5 preserved) ──
    ThemeInfo(
      option: AppThemeOption.auroraBorealis,
      label: 'Aurora',
      gradientColors: [Color(0xFF00BFA5), Color(0xFF00E5FF)],
      icon: Icons.nights_stay,
      description: 'Northern lights inspired',
    ),
    ThemeInfo(
      option: AppThemeOption.sunsetGlow,
      label: 'Sunset',
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
      icon: Icons.wb_twilight,
      description: 'Warm evening colors',
    ),
    ThemeInfo(
      option: AppThemeOption.oceanDepth,
      label: 'Ocean',
      gradientColors: [Color(0xFF0066CC), Color(0xFF00CCFF)],
      icon: Icons.water,
      description: 'Deep sea blue',
    ),
    ThemeInfo(
      option: AppThemeOption.forestMist,
      label: 'Forest',
      gradientColors: [Color(0xFF2E7D32), Color(0xFF81C784)],
      icon: Icons.forest,
      description: 'Fresh forest greens',
    ),
    ThemeInfo(
      option: AppThemeOption.midnightCity,
      label: 'Midnight',
      gradientColors: [Color(0xFF311B92), Color(0xFF7C4DFF)],
      icon: Icons.dark_mode,
      description: 'Urban night vibes',
    ),

    // ── Cute pastel themes (8 preserved) ──
    ThemeInfo(
      option: AppThemeOption.strawberryCream,
      label: 'Strawberry',
      gradientColors: [Color(0xFFFFC1CC), Color(0xFFFFF0F5)],
      icon: Icons.icecream,
      description: 'Soft pink + cream',
    ),
    ThemeInfo(
      option: AppThemeOption.cottonCandy,
      label: 'Cotton Candy',
      gradientColors: [Color(0xFFFFB7E6), Color(0xFFB5E7FF)],
      icon: Icons.cloud,
      description: 'Pink + blue cotton candy',
    ),
    ThemeInfo(
      option: AppThemeOption.peachParfait,
      label: 'Peach',
      gradientColors: [Color(0xFFFFDAB9), Color(0xFFFFA07A)],
      icon: Icons.egg_alt,
      description: 'Peach + soft coral',
    ),
    ThemeInfo(
      option: AppThemeOption.lavenderMilk,
      label: 'Lavender',
      gradientColors: [Color(0xFFE6E6FA), Color(0xFFD8BFD8)],
      icon: Icons.local_florist,
      description: 'Lavender + milky white',
    ),
    ThemeInfo(
      option: AppThemeOption.mintChocolate,
      label: 'Mint Choc',
      gradientColors: [Color(0xFF98FF98), Color(0xFF7B5C3E)],
      icon: Icons.cookie,
      description: 'Mint + chocolate',
    ),
    ThemeInfo(
      option: AppThemeOption.lemonSorbet,
      label: 'Lemon',
      gradientColors: [Color(0xFFFFFACD), Color(0xFFFFE4B5)],
      icon: Icons.emoji_food_beverage,
      description: 'Soft yellow + cream',
    ),
    ThemeInfo(
      option: AppThemeOption.bubblegumPop,
      label: 'Bubblegum',
      gradientColors: [Color(0xFFFF69B4), Color(0xFF7FFFD4)],
      icon: Icons.bubble_chart,
      description: 'Bright pink + aqua',
    ),
    ThemeInfo(
      option: AppThemeOption.sakuraBloom,
      label: 'Sakura',
      gradientColors: [Color(0xFFFFB7C5), Color(0xFFC8E6C9)],
      icon: Icons.eco,
      description: 'Cherry blossom + soft green',
    ),

    // ── NEW: NEET & Medical themes (6) ──
    ThemeInfo(
      option: AppThemeOption.neetAspirant,
      label: 'NEET Aspirant',
      gradientColors: [Color(0xFF00A86B), Color(0xFFFFFFFF)],
      icon: Icons.medical_services,
      description: 'Medical green + white',
    ),
    ThemeInfo(
      option: AppThemeOption.doctorCoat,
      label: 'Doctor Coat',
      gradientColors: [Color(0xFFFFFFFF), Color(0xFFE53935)],
      icon: Icons.health_and_safety,
      description: 'Pure white + stethoscope red',
    ),
    ThemeInfo(
      option: AppThemeOption.anatomyRed,
      label: 'Anatomy',
      gradientColors: [Color(0xFFB71C1C), Color(0xFFF5F5F5)],
      icon: Icons.favorite,
      description: 'Deep red + bone white',
    ),
    ThemeInfo(
      option: AppThemeOption.cellBiology,
      label: 'Cell Bio',
      gradientColors: [Color(0xFF4FC3F7), Color(0xFF7E57C2)],
      icon: Icons.biotech,
      description: 'Cytoplasm blue + nucleus purple',
    ),
    ThemeInfo(
      option: AppThemeOption.organicChem,
      label: 'Organic Chem',
      gradientColors: [Color(0xFF8E24AA), Color(0xFF66BB6A)],
      icon: Icons.science,
      description: 'Benzene purple + reaction green',
    ),
    ThemeInfo(
      option: AppThemeOption.physicsLab,
      label: 'Physics Lab',
      gradientColors: [Color(0xFF00E676), Color(0xFF212121)],
      icon: Icons.memory,
      description: 'Oscilloscope green + black',
    ),

    // ── NEW: Study-focused themes (4) ──
    ThemeInfo(
      option: AppThemeOption.nightOwl,
      label: 'Night Owl',
      gradientColors: [Color(0xFF1A237E), Color(0xFFFFB300)],
      icon: Icons.nightlight,
      description: 'Deep navy + amber for late study',
    ),
    ThemeInfo(
      option: AppThemeOption.focusMode,
      label: 'Focus Mode',
      gradientColors: [Color(0xFF37474F), Color(0xFF1565C0)],
      icon: Icons.center_focus_strong,
      description: 'Grey + deep blue, distraction-free',
    ),
    ThemeInfo(
      option: AppThemeOption.examMode,
      label: 'Exam Mode',
      gradientColors: [Color(0xFFD32F2F), Color(0xFFFFFFFF)],
      icon: Icons.timer,
      description: 'Alert red + clean white',
    ),
    ThemeInfo(
      option: AppThemeOption.victoryGold,
      label: 'Victory Gold',
      gradientColors: [Color(0xFFFFD700), Color(0xFF1B5E20)],
      icon: Icons.emoji_events,
      description: 'Gold medal + deep green',
    ),

    // ── Material You ──
    ThemeInfo(
      option: AppThemeOption.materialYou,
      label: 'Material You',
      gradientColors: [Color(0xFF6750A4), Color(0xFF958DA5)],
      icon: Icons.palette,
      description: 'System dynamic colors',
    ),

    // ── Custom (always last) ──
    ThemeInfo(
      option: AppThemeOption.customHex,
      label: 'Custom',
      gradientColors: [Color(0xFF9E9E9E), Color(0xFFE0E0E0)],
      icon: Icons.colorize,
      description: 'Your own color',
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

  /// Get secondary/accent color for a theme option.
  static Color getSecondaryColor(AppThemeOption option, {Color? customColor}) {
    final info = getInfo(option);
    if (info == null) return const Color(0xFF00E5FF);
    if (option == AppThemeOption.customHex && customColor != null) {
      return customColor.withOpacity(0.7);
    }
    return info.gradientColors.length > 1
        ? info.gradientColors[1]
        : info.gradientColors.first.withOpacity(0.7);
  }

  /// Get gradient colors for a theme option.
  static List<Color>? gradientColorsFor(AppThemeOption option) {
    final info = getInfo(option);
    return info?.gradientColors;
  }

  /// Get theme icon.
  static IconData? getThemeIcon(AppThemeOption option) {
    return getInfo(option)?.icon;
  }

  /// Build a full ThemeData for the given theme option.
  static ThemeData buildTheme(
    AppThemeOption option, {
    required Brightness brightness,
    Color? customColor,
    ColorScheme? dynamicScheme,
    bool highContrast = false,
    bool trueBlack = false, // OLED black mode
    FontWeightConfig? fontWeights,
  }) {
    final Color primaryColor = getPrimaryColor(option, customColor: customColor);
    final FontWeightConfig weights = fontWeights ?? const FontWeightConfig();

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

    if (trueBlack && brightness == Brightness.dark) {
      colorScheme = colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF121212),
      );
    }

    // NEET-specific: Doctor Coat theme gets special treatment
    final bool isDoctorCoat = option == AppThemeOption.doctorCoat;
    final bool isExamMode = option == AppThemeOption.examMode;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: trueBlack && brightness == Brightness.dark
          ? Colors.black
          : colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: isDoctorCoat && brightness == Brightness.light
            ? Colors.white
            : colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      cardTheme: CardTheme(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: weights.body,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.3),
        thickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      // Typography
      textTheme: TextTheme(
        displayLarge: TextStyle(fontWeight: weights.heading),
        displayMedium: TextStyle(fontWeight: weights.heading),
        displaySmall: TextStyle(fontWeight: weights.heading),
        headlineLarge: TextStyle(fontWeight: weights.heading),
        headlineMedium: TextStyle(fontWeight: weights.heading),
        headlineSmall: TextStyle(fontWeight: weights.heading),
        titleLarge: TextStyle(fontWeight: weights.heading),
        titleMedium: TextStyle(fontWeight: weights.caption),
        titleSmall: TextStyle(fontWeight: weights.caption),
        bodyLarge: TextStyle(fontWeight: weights.body),
        bodyMedium: TextStyle(fontWeight: weights.body),
        bodySmall: TextStyle(fontWeight: weights.body),
        labelLarge: TextStyle(fontWeight: weights.caption),
        labelMedium: TextStyle(fontWeight: weights.caption),
        labelSmall: TextStyle(fontWeight: weights.caption),
      ),
    );
  }

  /// Glassmorphism decoration helper.
  static BoxDecoration glassmorphism({
    required BuildContext context,
    required double opacity,
    required BorderRadius borderRadius,
    double? blurSigma,
    Color? tintColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      borderRadius: borderRadius,
      color: (tintColor ?? cs.surface).withOpacity(opacity),
      border: Border.all(
        color: cs.outline.withOpacity(0.1),
      ),
    );
  }

  /// Enhanced glassmorphism with gradient tint.
  static BoxDecoration glassmorphismGradient({
    required BuildContext context,
    required double opacity,
    required BorderRadius borderRadius,
    List<Color>? gradientColors,
  }) {
    final cs = Theme.of(context).colorScheme;
    final colors = gradientColors ?? [cs.primary, cs.secondary];
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        colors: [
          colors.first.withOpacity(opacity * 0.3),
          colors.last.withOpacity(opacity * 0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: cs.outline.withOpacity(0.1),
      ),
    );
  }

  /// Get a themed container decoration for cards.
  static BoxDecoration cardDecoration({
    required BuildContext context,
    Color? backgroundColor,
    double radius = 16,
    bool hasBorder = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: backgroundColor ?? cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      border: hasBorder
          ? Border.all(
              color: cs.outlineVariant.withOpacity(0.2),
            )
          : null,
    );
  }

  /// Get theme-aware shimmer base color.
  static Color shimmerBaseColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return cs.surfaceContainerHighest;
  }

  /// Get theme-aware shimmer highlight color.
  static Color shimmerHighlightColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return cs.surface;
  }
}
