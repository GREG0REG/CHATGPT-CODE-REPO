import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await SettingsService.instance.getSelectedTheme();
    if (mounted) setState(() => _theme = theme);
  }

  /// Called by the Settings screen after the user changes the theme so the
  /// whole app rebuilds with the new colors immediately.
  static EventCountdownAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<EventCountdownAppState>();

  void updateTheme(AppThemeOption theme) {
    setState(() => _theme = theme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Countdown',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.buildTheme(_theme),
      home: const HomeScreen(),
    );
  }
}
