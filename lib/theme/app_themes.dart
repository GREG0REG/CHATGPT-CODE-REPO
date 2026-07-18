import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Redesigned theme options — 5 beautiful presets + Material You + Custom
enum AppThemeOption {
  auroraBorealis,      // Teal → Purple gradient (matches your image)
  sunsetGlow,          // Orange → Pink gradient
  midnightOcean,       // Deep blue → Cyan
  emeraldForest,       // Green → Lime
  roseQuartz,          // Pink → Rose
  materialYou,         // Android 12+ dynamic
  customHex,           // User-defined
}

class AppThemeInfo {
  final AppThemeOption option;
  final String label;
  final Color primaryColor;
  final List<Color> gradientColors;
  final IconData icon;
  final Color accentColor;

  const AppThemeInfo({
    required this.option,
    required this.label,
    required this.primaryColor,
    required this.gradientColors,
    required this.icon,
    required this.accentColor,
  });
}

class AppThemes {
  AppThemes._();

  static const List<AppThemeInfo> all = [
    AppThemeInfo(
      option: AppThemeOption.auroraBorealis,
      label: 'Aurora Borealis',
      primaryColor: Color(0xFF00BFA5),
      gradientColors: [Color(0xFF00BFA5), Color(0xFF7C4DFF)],
      icon: Icons.north,
      accentColor: Color(0xFF7C4DFF),
    ),
    AppThemeInfo(
      option: AppThemeOption.sunsetGlow,
      label: 'Sunset Glow',
      primaryColor: Color(0xFFFF6D00),
      gradientColors: [Color(0xFFFF6D00), Color(0xFFFF4081)],
      icon: Icons.wb_twilight,
      accentColor: Color(0xFFFF4081),
    ),
    AppThemeInfo(
      option: AppThemeOption.midnightOcean,
      label: 'Midnight Ocean',
      primaryColor: Color(0xFF1565C0),
      gradientColors: [Color(0xFF1565C0), Color(0xFF00E5FF)],
      icon: Icons.water,
      accentColor: Color(0xFF00E5FF),
    ),
    AppThemeInfo(
      option: AppThemeOption.emeraldForest,
      label: 'Emerald Forest',
      primaryColor: Color(0xFF2E7D32),
      gradientColors: [Color(0xFF2E7D32), Color(0xFF76FF03)],
      icon: Icons.forest,
      accentColor: Color(0xFF76FF03),
    ),
    AppThemeInfo(
      option: AppThemeOption.roseQuartz,
      label: 'Rose Quartz',
      primaryColor: Color(0xFFE91E63),
      gradientColors: [Color(0xFFE91E63), Color(0xFFFF80AB)],
      icon: Icons.diamond,
      accentColor: Color(0xFFFF80AB),
    ),
    AppThemeInfo(
      option: AppThemeOption.materialYou,
      label: 'Material You',
      primaryColor: Color(0xFF2196F3),
      gradientColors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
      icon: Icons.auto_awesome,
      accentColor: Color(0xFF03A9F4),
    ),
    AppThemeInfo(
      option: AppThemeOption.customHex,
      label: 'Custom Color',
      primaryColor: Color(0xFF2196F3),
      gradientColors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
      icon: Icons.colorize,
      accentColor: Color(0xFF64B5F6),
    ),
  ];

  static AppThemeInfo infoFor(AppThemeOption option) {
    return all.firstWhere(
      (t) => t.option == option,
      orElse: () => all.first,
    );
  }

  static Color primaryColorFor(AppThemeOption option) => infoFor(option).primaryColor;
  static List<Color> gradientColorsFor(AppThemeOption option) => infoFor(option).gradientColors;
  static Color accentColorFor(AppThemeOption option) => infoFor(option).accentColor;
  static String nameOf(AppThemeOption option) => option.name;

  static AppThemeOption fromName(String? name) {
    return all
        .map((t) => t.option)
        .firstWhere((o) => o.name == name, orElse: () => AppThemeOption.auroraBorealis);
  }

  /// Build complete ThemeData for light or dark mode
  static ThemeData buildTheme(
    AppThemeOption option, {
    Brightness brightness = Brightness.light,
    Color? customColor,
    ColorScheme? dynamicScheme,
    bool highContrast = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final info = infoFor(option);
    
    ColorScheme colorScheme;
    Color primaryColor;
    List<Color> gradientColors = info.gradientColors;

    switch (option) {
      case AppThemeOption.materialYou:
        colorScheme = dynamicScheme ?? _defaultScheme(brightness);
        primaryColor = colorScheme.primary;
        break;

      case AppThemeOption.customHex:
        final seed = customColor ?? Colors.blue;
        primaryColor = seed;
        colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
        gradientColors = [seed, seed.withOpacity(0.7)];
        break;

      case AppThemeOption.auroraBorealis:
      case AppThemeOption.sunsetGlow:
      case AppThemeOption.midnightOcean:
      case AppThemeOption.emeraldForest:
      case AppThemeOption.roseQuartz:
        primaryColor = info.primaryColor;
        colorScheme = ColorScheme.fromSeed(
          seedColor: info.primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? info.primaryColor.withOpacity(0.9) : info.primaryColor,
          secondary: isDark ? info.accentColor.withOpacity(0.9) : info.accentColor,
          tertiary: info.gradientColors.length > 1 ? info.gradientColors[1] : info.primaryColor,
        );
        break;
    }

    // High contrast override
    if (highContrast) {
      colorScheme = colorScheme.copyWith(
        surface: isDark ? Colors.black : Colors.white,
        onSurface: isDark ? Colors.white : Colors.black,
      );
    }

    final surfaceColor = isDark ? const Color(0xFF0F0F1B) : const Color(0xFFF8F9FE);
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final scaffoldBg = isDark ? const Color(0xFF0F0F1B) : const Color(0xFFF0F2F8);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      
      // ── Cards with glassmorphism feel ──
      cardTheme: CardTheme(
        elevation: isDark ? 0 : 2,
        color: cardColor,
        shadowColor: primaryColor.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide(color: Colors.white.withOpacity(0.06), width: 1)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      
      // ── AppBar ──
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      
      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      // ── List Tiles ──
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      
      // ── Dividers ──
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        thickness: 1,
        indent: 16,
        endIndent: 16,
      ),
      
      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFF323232),
      ),
      
      // ── Bottom Navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      // ── Dialogs ──
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: cardColor,
      ),
      
      // ── Bottom Sheets ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      
      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      // ── Switches & Sliders ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return isDark ? Colors.white54 : Colors.black38;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor.withOpacity(0.3);
          return isDark ? Colors.white12 : Colors.black12;
        }),
      ),
      
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
        overlayColor: primaryColor.withOpacity(0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      
      // ── Page Transitions ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      
      // ── Typography ──
      textTheme: _buildTextTheme(colorScheme.onSurface, isDark),
    );
  }

  static TextTheme _buildTextTheme(Color onSurface, bool isDark) {
    final baseColor = onSurface;
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: baseColor, letterSpacing: -0.5),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: baseColor, letterSpacing: -0.5),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: baseColor),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: baseColor),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: baseColor),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: baseColor),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor.withOpacity(0.7)),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: baseColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: baseColor),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: baseColor.withOpacity(0.7)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: baseColor),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor.withOpacity(0.7)),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: baseColor.withOpacity(0.5)),
    );
  }

  static ColorScheme _defaultScheme(Brightness brightness) {
    return ColorScheme.fromSeed(seedColor: const Color(0xFF00BFA5), brightness: brightness);
  }

  /// Auto-contrast text color for any background
  static Color autoContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Get glassmorphism decoration for widgets
  static BoxDecoration glassmorphism({
    required BuildContext context,
    double opacity = 0.15,
    double blurRadius = 20,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? Colors.white.withOpacity(opacity) : Colors.white.withOpacity(opacity + 0.4),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
          blurRadius: blurRadius,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Get circular progress gradient for the current theme
  static Gradient circularProgressGradient(AppThemeOption option, {bool isDark = false}) {
    final colors = gradientColorsFor(option);
    return SweepGradient(
      colors: colors,
      startAngle: 0,
      endAngle: 3.14159 * 2,
    );
  }
}
