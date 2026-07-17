import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:workmanager/workmanager.dart';
import 'db/database_helper.dart';
import 'services/export_import_service.dart';

import 'screens/home_screen.dart';
import 'screens/widget_settings_screen.dart';
import 'services/backup_service.dart';
import 'services/battery_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/widget_service.dart';
import 'theme/app_themes.dart';

const String kWidgetRefreshTaskName = 'event_countdown_widget_refresh';
const String kBackupTaskName = 'event_countdown_weekly_backup';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kWidgetRefreshTaskName) {
      await WidgetService.refreshWidget();
    } else if (task == kBackupTaskName) {
      return Future.value(await BackupService.executeBackup());
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
  await Workmanager().registerPeriodicTask(
    kWidgetRefreshTaskName,
    kWidgetRefreshTaskName,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // SESSION 6: Register weekly backup
  await BackupService.registerWeeklyBackup();

  // Push initial widget data immediately on launch.
  await WidgetService.refreshWidget();

  runApp(const EventCountdownApp());
}

class EventCountdownApp extends StatefulWidget {
  const EventCountdownApp({super.key});

  @override
  State<EventCountdownApp> createState() => EventCountdownAppState();
}

class EventCountdownAppState extends State<EventCountdownApp>
    with WidgetsBindingObserver {
  AppThemeOption _theme = AppThemeOption.defaultBlue;
  ThemeMode _themeMode = ThemeMode.system;
  Color? _customColor;
  bool _highContrast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllSettings();
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================
  // SESSION 9: Screen-state awareness
  // ============================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final home = _HomeScreenState.homeScreenKey.currentState;
    if (home == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      home.pauseRefresh();
    } else if (state == AppLifecycleState.resumed) {
      home.resumeRefresh();
    }
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

  // ============================================
  // SESSION 6: Restore prompt on first launch
  // ============================================
  Future<void> _checkFirstLaunch() async {
    final isFirst = await SettingsService.instance.isFirstLaunch();
    if (!isFirst) return;

    await SettingsService.instance.setFirstLaunch(false);

    // Delay to let UI build
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final backupPath = await BackupService.findRecentBackup();
    if (backupPath == null) return;

    if (!mounted) return;
    final shouldRestore = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'A previous backup was found. Would you like to restore your events?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (shouldRestore == true) {
      try {
        final count = await ExportImportService.importFromJson(backupPath);
        final events = await DatabaseHelper.instance.getAllEventsSorted();
        await NotificationService.instance.rescheduleAll(events);
        await WidgetService.refreshWidget();

        if (mounted) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text('Restored $count event(s)')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text('Restore failed: $e')),
          );
        }
      }
    }
  }

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
          navigatorKey: navigatorKey,
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
          routes: {
            '/widget_settings': (context) => const WidgetSettingsScreen(),
          },
        );
      },
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
