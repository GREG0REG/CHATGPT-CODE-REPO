import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/home_screen.dart';
import 'screens/widget_settings_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/widget_service.dart';
import 'theme/app_themes.dart';

/// Unique name for the periodic background task that refreshes the home
/// screen widget every 30-60 minutes (battery efficient - no polling loop).
const String kWidgetRefreshTaskName = 'event_countdown_widget_refresh';

/// Entry point for workmanager background tasks. Must be a top-level or
/// static function annotated so it can run in a separate background isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kWidgetRefreshTaskName) {
      await WidgetService.refreshWidget();
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  // Battery-efficient periodic refresh: workmanager's Android minimum
  // periodic interval is 15 minutes; we use 30 minutes to stay within the
  // requested 30-60 minute battery-efficient window.
  await Workmanager().registerPeriodicTask(
    kWidgetRefreshTaskName,
    kWidgetRefreshTaskName,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // Push initial widget data immediately on launch too.
  await WidgetService.refreshWidget();

  runApp(const EventCountdownApp());
}

class EventCountdownApp extends StatefulWidget {
  const EventCountdownApp({super.key});

  @override
  State<EventCountdownApp> createState() => EventCountdownAppState();
}

class EventCountdownAppState extends State<EventCountdownApp> {
  AppThemeOption _theme = AppThemeOption.defaultBlue;
  ThemeMode _themeMode = ThemeMode.system;
  Color? _customColor;
  bool _highContrast = false;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final theme = await SettingsService.instance.getSelectedTheme();
    final mode = await SettingsService.instance.getThemeMode();
    final custom = await SettingsService.instance.getCustomColor();
    final hc = await SettingsService.instance.getHighContrast();
    if (mounted) {
      setState(() {
        _theme = theme;
        _themeMode = mode;
        _customColor = custom;
        _highContrast = hc;
      });
    }
  }

  /// Called by the Settings screen after the user changes the theme so the
  /// whole app rebuilds with the new colors immediately.
  static EventCountdownAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<EventCountdownAppState>();

  void updateTheme(AppThemeOption theme) {
    setState(() => _theme = theme);
  }

  void updateThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void updateCustomColor(Color? color) {
    setState(() => _customColor = color);
  }

  void updateHighContrast(bool value) {
    setState(() => _highContrast = value);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Event Countdown',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode,
          theme: AppThemes.buildTheme(
            _theme,
            brightness: Brightness.light,
            customColor: _customColor,
            dynamicScheme: _theme == AppThemeOption.materialYou ? lightDynamic : null,
            highContrast: _highContrast,
          ),
          darkTheme: AppThemes.buildTheme(
            _theme,
            brightness: Brightness.dark,
            customColor: _customColor,
            dynamicScheme: _theme == AppThemeOption.materialYou ? darkDynamic : null,
            highContrast: _highContrast,
          ),
          home: const HomeScreen(),
          // ============================================
          // SESSION 3: Handle widget settings deep link
          // ============================================
          routes: {
            '/widget_settings': (context) => const WidgetSettingsScreen(),
          },
        );
      },
    );
  }
}
