// FILE: lib/theme/app_themes.dart
// COMPLETE REPLACEMENT — copy and paste entire file
// ADDED: 4 new immersive themes (Neon Cyberpunk, Midnight Ocean, Sunset Boulevard, Nordic Frost)
// EXISTING: All 7 original themes preserved exactly as-is
// ENHANCED: Animated gradient helper, surfaceContainer overrides, better contrast

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

enum AppThemeOption {
  auroraBorealis,
  oceanBreeze,
  sunsetGlow,
  midnightForest,
  cherryBlossom,
  materialYou,
  customHex,
  // NEW THEMES:
  neonCyberpunk,
  midnightOcean,
  sunsetBoulevard,
  nordicFrost,
}

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

enum WidgetBackgroundType { themeColor, customImage }

class AppThemes {
  // ── Theme definitions ──
  // EXISTING 7 themes preserved exactly as-is
  static const List<ThemeInfo> all = [
    ThemeInfo(
      option: AppThemeOption.auroraBorealis,
      label: 'Aurora Borealis',
      gradientColors: [Color(0xFF00BFA5), Color(0xFF00E5FF)],
    ),
    ThemeInfo(
      option: AppThemeOption.oceanBreeze,
      label: 'Ocean Breeze',
      gradientColors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
    ),
    ThemeInfo(
      option: AppThemeOption.sunsetGlow,
      label: 'Sunset Glow',
      gradientColors: [Color(0xFFFF7043), Color(0xFFFFCA28)],
    ),
    ThemeInfo(
      option: AppThemeOption.midnightForest,
      label: 'Midnight Forest',
      gradientColors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    ),
    ThemeInfo(
      option: AppThemeOption.cherryBlossom,
      label: 'Cherry Blossom',
      gradientColors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
    ),
    ThemeInfo(
      option: AppThemeOption.materialYou,
      label: 'Material You',
      gradientColors: [Color(0xFF6750A4), Color(0xFF7B61FF)],
    ),
    ThemeInfo(
      option: AppThemeOption.customHex,
      label: 'Custom Color',
      gradientColors: [Color(0xFF00BFA5), Color(0xFF00E5FF)],
    ),
    // ═══════════════════════════════════════════════════════════════
    // NEW IMMERSIVE THEMES
    // ═══════════════════════════════════════════════════════════════
    ThemeInfo(
      option: AppThemeOption.neonCyberpunk,
      label: 'Neon Cyberpunk',
      gradientColors: [Color(0xFFFF00FF), Color(0xFF00FFFF), Color(0xFF9D00FF)],
    ),
    ThemeInfo(
      option: AppThemeOption.midnightOcean,
      label: 'Midnight Ocean',
      gradientColors: [Color(0xFF0A1628), Color(0xFF1E3A5F), Color(0xFF00B4D8)],
    ),
    ThemeInfo(
      option: AppThemeOption.sunsetBoulevard,
      label: 'Sunset Boulevard',
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFFFF8E53)],
    ),
    ThemeInfo(
      option: AppThemeOption.nordicFrost,
      label: 'Nordic Frost',
      gradientColors: [Color(0xFFE3F2FD), Color(0xFF90CAF9), Color(0xFF5C6BC0)],
    ),
  ];

  static ThemeInfo fromName(String name) {
    return all.firstWhere(
      (t) => t.option.name == name,
      orElse: () => all.first,
    );
  }

  static List<Color>? gradientColorsFor(AppThemeOption option) {
    final info = all.firstWhere((t) => t.option == option, orElse: () => all.first);
    return info.gradientColors;
  }

  // ── FIXED: High contrast support ──
  static ThemeData buildTheme(
    AppThemeOption option, {
    required Brightness brightness,
    Color? customColor,
    ColorScheme? dynamicScheme,
    bool highContrast = false,
  }) {
    final baseColors = gradientColorsFor(option) ?? all.first.gradientColors;
    final primaryColor = customColor ?? baseColors.first;

    // SPECIAL HANDLING FOR NEW DARK THEMES
    // Neon Cyberpunk and Midnight Ocean default to dark mode for immersion
    final bool forceDark = option == AppThemeOption.neonCyberpunk || 
                          option == AppThemeOption.midnightOcean;
    final effectiveBrightness = forceDark ? Brightness.dark : brightness;

    ColorScheme colorScheme;
    
    if (option == AppThemeOption.materialYou && dynamicScheme != null) {
      colorScheme = highContrast 
        ? _applyHighContrast(dynamicScheme, effectiveBrightness)
        : dynamicScheme;
    } else {
      colorScheme = _generateColorScheme(
        primaryColor, 
        effectiveBrightness, 
        highContrast: highContrast,
      );
    }

    // SPECIAL: Override surface colors for immersive dark themes
    Color surfaceColor = colorScheme.surface;
    Color surfaceContainerHighestColor = colorScheme.surfaceContainerHighest;
    Color surfaceContainerColor = colorScheme.surfaceContainer;
    
    if (option == AppThemeOption.neonCyberpunk && !highContrast) {
      surfaceColor = const Color(0xFF0D0221);
      surfaceContainerHighestColor = const Color(0xFF1A0B2E);
      surfaceContainerColor = const Color(0xFF14082A);
    } else if (option == AppThemeOption.midnightOcean && !highContrast) {
      surfaceColor = const Color(0xFF070F1F);
      surfaceContainerHighestColor = const Color(0xFF0F1F3A);
      surfaceContainerColor = const Color(0xFF0A1830);
    } else if (option == AppThemeOption.sunsetBoulevard && !highContrast) {
      surfaceColor = effectiveBrightness == Brightness.dark 
          ? const Color(0xFF1A0F0A) 
          : colorScheme.surface;
      surfaceContainerHighestColor = effectiveBrightness == Brightness.dark
          ? const Color(0xFF2A1A10)
          : colorScheme.surfaceContainerHighest;
      surfaceContainerColor = effectiveBrightness == Brightness.dark
          ? const Color(0xFF22140C)
          : colorScheme.surfaceContainer;
    } else if (option == AppThemeOption.nordicFrost && !highContrast) {
      surfaceColor = effectiveBrightness == Brightness.dark
          ? const Color(0xFF0D1B2A)
          : const Color(0xFFF0F7FF);
      surfaceContainerHighestColor = effectiveBrightness == Brightness.dark
          ? const Color(0xFF1B2838)
          : const Color(0xFFE3F2FD);
      surfaceContainerColor = effectiveBrightness == Brightness.dark
          ? const Color(0xFF152232)
          : const Color(0xFFE8F4FD);
    }

    return ThemeData(
      useMaterial3: true,
      brightness: effectiveBrightness,
      colorScheme: colorScheme.copyWith(
        surface: surfaceColor,
        surfaceContainerHighest: surfaceContainerHighestColor,
        surfaceContainer: surfaceContainerColor,
      ),
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        elevation: highContrast ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast 
            ? BorderSide(color: colorScheme.outline, width: 1.5)
            : BorderSide.none,
        ),
        color: surfaceContainerHighestColor,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHighestColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highContrast ? colorScheme.onSurface : colorScheme.outline,
            width: highContrast ? 2.0 : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highContrast ? colorScheme.onSurface.withOpacity(0.7) : colorScheme.outline,
            width: highContrast ? 2.0 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: highContrast ? 3.0 : 2.0,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: highContrast ? colorScheme.primary : null,
          foregroundColor: highContrast ? colorScheme.onPrimary : null,
        ),
      ),
      textTheme: _buildTextTheme(effectiveBrightness, highContrast: highContrast, option: option),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: highContrast ? 1.5 : 1.0,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast 
              ? colorScheme.primary.withOpacity(0.9) 
              : colorScheme.primaryContainer;
          }
          return highContrast 
            ? colorScheme.onSurface.withOpacity(0.4)
            : surfaceContainerHighestColor;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast ? colorScheme.onPrimary : colorScheme.primary;
          }
          return highContrast ? surfaceColor : colorScheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast ? colorScheme.primary : colorScheme.primaryContainer;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast ? colorScheme.onPrimary : colorScheme.onPrimaryContainer;
          }
          return null;
        }),
        side: BorderSide(
          color: highContrast ? colorScheme.onSurface : colorScheme.outline,
          width: highContrast ? 2.5 : 2.0,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHighestColor,
        selectedColor: highContrast ? colorScheme.primary : colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: highContrast ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          fontWeight: highContrast ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: highContrast 
            ? BorderSide(color: colorScheme.outline, width: 1.5)
            : BorderSide.none,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: highContrast ? colorScheme.primary : colorScheme.primaryContainer,
        inactiveTrackColor: highContrast ? colorScheme.onSurface.withOpacity(0.3) : surfaceContainerHighestColor,
        thumbColor: highContrast ? colorScheme.onPrimary : colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.1),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: highContrast ? colorScheme.primary : colorScheme.primary,
        linearTrackColor: highContrast ? colorScheme.onSurface.withOpacity(0.2) : surfaceContainerHighestColor,
        circularTrackColor: highContrast ? colorScheme.onSurface.withOpacity(0.2) : surfaceContainerHighestColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: highContrast ? colorScheme.primary : colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: highContrast ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: highContrast ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: highContrast ? colorScheme.onPrimary : colorScheme.onSecondaryContainer,
              size: 24,
            );
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontWeight: highContrast ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  static ColorScheme _generateColorScheme(
    Color seedColor, 
    Brightness brightness, {
    required bool highContrast,
  }) {
    if (highContrast) {
      return ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        contrastLevel: 1.0,
      );
    }
    
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: 0.0,
    );
  }

  static ColorScheme _applyHighContrast(ColorScheme scheme, Brightness brightness) {
    return scheme.copyWith(
      surface: brightness == Brightness.light 
        ? scheme.surface 
        : scheme.surface,
      onSurface: brightness == Brightness.light 
        ? Colors.black 
        : Colors.white,
      surfaceContainerHighest: brightness == Brightness.light
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHighest,
      surfaceContainer: brightness == Brightness.light
        ? scheme.surfaceContainer
        : scheme.surfaceContainer,
      primary: _ensureContrast(scheme.primary, scheme.onPrimary, brightness),
      onPrimary: scheme.onPrimary,
      error: brightness == Brightness.light 
        ? const Color(0xFFB00020) 
        : const Color(0xFFCF6679),
      onError: Colors.white,
      outline: brightness == Brightness.light 
        ? Colors.black54 
        : Colors.white70,
      outlineVariant: brightness == Brightness.light 
        ? Colors.black38 
        : Colors.white38,
    );
  }

  static Color _ensureContrast(Color color, Color onColor, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(
      brightness == Brightness.light 
        ? (hsl.lightness * 0.85).clamp(0.3, 0.5)
        : (hsl.lightness * 1.15).clamp(0.5, 0.7)
    ).toColor();
  }

  static TextTheme _buildTextTheme(Brightness brightness, {required bool highContrast, AppThemeOption? option}) {
    final baseTextTheme = brightness == Brightness.light 
      ? ThemeData.light().textTheme 
      : ThemeData.dark().textTheme;
    
    if (!highContrast) {
      // SPECIAL: Neon Cyberpunk gets slightly brighter text for readability
      if (option == AppThemeOption.neonCyberpunk) {
        return baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.85),
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: Colors.white.withOpacity(0.95),
          ),
        );
      }
      return baseTextTheme;
    }

    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: brightness == Brightness.light ? Colors.black87 : Colors.white,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: brightness == Brightness.light ? Colors.black87 : Colors.white,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: brightness == Brightness.light ? Colors.black87 : Colors.white,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: brightness == Brightness.light ? Colors.black87 : Colors.white,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Glassmorphism helper ──
  static BoxDecoration glassmorphism({
    required BuildContext context,
    double opacity = 0.1,
    BorderRadius? borderRadius,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          cs.primary.withOpacity(opacity),
          cs.secondary.withOpacity(opacity * 0.5),
        ],
      ),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: cs.outline.withOpacity(0.2),
        width: 1,
      ),
    );
  }

  // ── ENHANCED: Animated gradient background for immersive themes ──
  static BoxDecoration animatedGradient({
    required AppThemeOption option,
    required Brightness brightness,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final colors = gradientColorsFor(option) ?? all.first.gradientColors;
    
    // For dark immersive themes, add depth layers
    if (option == AppThemeOption.neonCyberpunk) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            const Color(0xFF0D0221),
            colors[0].withOpacity(0.3),
            const Color(0xFF1A0B2E),
            colors[1].withOpacity(0.2),
            const Color(0xFF0D0221),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
      );
    }
    
    if (option == AppThemeOption.midnightOcean) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            const Color(0xFF070F1F),
            colors[1].withOpacity(0.4),
            const Color(0xFF0F1F3A),
            colors[2].withOpacity(0.3),
            const Color(0xFF070F1F),
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ),
      );
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ),
    );
  }

  // ── ENHANCED: Get theme-appropriate card glow color ──
  static Color? glowColor(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.neonCyberpunk:
        return const Color(0xFFFF00FF).withOpacity(0.15);
      case AppThemeOption.midnightOcean:
        return const Color(0xFF00B4D8).withOpacity(0.15);
      case AppThemeOption.sunsetBoulevard:
        return const Color(0xFFFF6B6B).withOpacity(0.1);
      case AppThemeOption.nordicFrost:
        return const Color(0xFF90CAF9).withOpacity(0.15);
      default:
        return null;
    }
  }
}
