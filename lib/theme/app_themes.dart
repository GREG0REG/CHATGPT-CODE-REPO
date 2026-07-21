// CHATGPT-CODE-REPO-TEST/lib/theme/app_themes.dart
// COMPLETE FILE - Fixed high contrast support

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

    // FIXED: Generate high-contrast color scheme when enabled
    ColorScheme colorScheme;
    
    if (option == AppThemeOption.materialYou && dynamicScheme != null) {
      // Use dynamic color with high contrast override
      colorScheme = highContrast 
        ? _applyHighContrast(dynamicScheme, brightness)
        : dynamicScheme;
    } else {
      // Generate from seed color with high contrast
      colorScheme = _generateColorScheme(
        primaryColor, 
        brightness, 
        highContrast: highContrast,
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
        elevation: highContrast ? 2 : 0, // FIXED: More elevation in high contrast
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // FIXED: Add border in high contrast mode
          side: highContrast 
            ? BorderSide(color: colorScheme.outline, width: 1.5)
            : BorderSide.none,
        ),
        color: colorScheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highContrast ? colorScheme.onSurface : colorScheme.outline,
            width: highContrast ? 2.0 : 1.0, // FIXED: Thicker borders in high contrast
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
            width: highContrast ? 3.0 : 2.0, // FIXED: Thicker focus border
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
          // FIXED: Higher contrast filled buttons
          backgroundColor: highContrast ? colorScheme.primary : null,
          foregroundColor: highContrast ? colorScheme.onPrimary : null,
        ),
      ),
      textTheme: _buildTextTheme(brightness, highContrast: highContrast),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: highContrast ? 1.5 : 1.0, // FIXED: Thicker dividers
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
            : colorScheme.surfaceContainerHighest;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast ? colorScheme.onPrimary : colorScheme.primary;
          }
          return highContrast ? colorScheme.surface : colorScheme.outline;
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
        backgroundColor: colorScheme.surfaceContainerHighest,
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
        inactiveTrackColor: highContrast ? colorScheme.onSurface.withOpacity(0.3) : colorScheme.surfaceContainerHighest,
        thumbColor: highContrast ? colorScheme.onPrimary : colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.1),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: highContrast ? colorScheme.primary : colorScheme.primary,
        linearTrackColor: highContrast ? colorScheme.onSurface.withOpacity(0.2) : colorScheme.surfaceContainerHighest,
        circularTrackColor: highContrast ? colorScheme.onSurface.withOpacity(0.2) : colorScheme.surfaceContainerHighest,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
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
        backgroundColor: highContrast ? colorScheme.inverseSurface : colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: highContrast ? colorScheme.onInverseSurface : colorScheme.onInverseSurface,
          fontWeight: highContrast ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  // FIXED: Generate high-contrast color scheme
  static ColorScheme _generateColorScheme(
    Color seedColor, 
    Brightness brightness, {
    required bool highContrast,
  }) {
    if (highContrast) {
      // FIXED: Use high contrast variant of ColorScheme
      return ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        contrastLevel: 1.0, // Maximum contrast for Material 3
      );
    }
    
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: 0.0,
    );
  }

  // FIXED: Apply high contrast modifications to dynamic color scheme
  static ColorScheme _applyHighContrast(ColorScheme scheme, Brightness brightness) {
    // Increase contrast by adjusting colors to be more distinct
    return scheme.copyWith(
      // Ensure surface and background have strong contrast with text
      surface: brightness == Brightness.light 
        ? scheme.surface 
        : scheme.surface,
      onSurface: brightness == Brightness.light 
        ? Colors.black 
        : Colors.white,
      surfaceContainerHighest: brightness == Brightness.light
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHighest,
      // Stronger primary colors
      primary: _ensureContrast(scheme.primary, scheme.onPrimary, brightness),
      onPrimary: scheme.onPrimary,
      // Stronger error colors
      error: brightness == Brightness.light 
        ? const Color(0xFFB00020) 
        : const Color(0xFFCF6679),
      onError: Colors.white,
      // Ensure outline is visible
      outline: brightness == Brightness.light 
        ? Colors.black54 
        : Colors.white70,
      outlineVariant: brightness == Brightness.light 
        ? Colors.black38 
        : Colors.white38,
    );
  }

  // Helper to ensure color has enough contrast
  static Color _ensureContrast(Color color, Color onColor, Brightness brightness) {
    // For high contrast, use more saturated/vivid colors
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(
      brightness == Brightness.light 
        ? (hsl.lightness * 0.85).clamp(0.3, 0.5)  // Darker in light mode
        : (hsl.lightness * 1.15).clamp(0.5, 0.7)  // Lighter in dark mode
    ).toColor();
  }

  // FIXED: Build text theme with high contrast support
  static TextTheme _buildTextTheme(Brightness brightness, {required bool highContrast}) {
    final baseTextTheme = brightness == Brightness.light 
      ? ThemeData.light().textTheme 
      : ThemeData.dark().textTheme;
    
    if (!highContrast) return baseTextTheme;

    // FIXED: Apply high contrast text styles
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
}
