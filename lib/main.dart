import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:workmanager/workmanager.dart';
import 'package:event_countdown/database_helper.dart';
import 'package:event_countdown/services/battery_service.dart';
import 'package:event_countdown/services/export_import_service.dart';
import 'package:event_countdown/screens/home_screen.dart';
import 'package:event_countdown/screens/main_screen.dart';
import 'package:event_countdown/screens/widget_settings_screen.dart';
import 'package:event_countdown/screens/stats_screen.dart';
import 'package:event_countdown/services/backup_service.dart';
import 'package:event_countdown/services/notification_service.dart';
import 'package:event_countdown/services/pomodoro_service.dart';
import 'package:event_countdown/services/settings_service.dart';
import 'package:event_countdown/services/widget_service.dart';
import 'package:event_countdown/services/theme_service.dart';
import 'package:event_countdown/theme/app_themes.dart';

const String kWidgetRefreshTaskName = 'event_countdown_widget_refresh';
const String kWidgetRefreshFrequentTaskName = 'event_countdown_widget_frequent';
const String kBackupTaskName = 'event_countdown_weekly_backup';
const String kAttendanceWidgetRefreshTaskName = 'event_countdown_attendance_widget_refresh';
const String kTimetableWidgetRefreshTaskName = 'event_countdown_timetable_widget_refresh';

// ── NEW: NEET Countdown Widget periodic refresh ──
const String kNeetCountdownTaskName = 'event_countdown_neet_widget_refresh';

// ── NEW: NEET Motivational Notification daily at 6 AM ──
const String kNeetMotivationTaskName = 'event_countdown_neet_motivation';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (task == kWidgetRefreshFrequentTaskName) {
      try {
        final prefs = await SettingsService.instance.getAdaptiveRefreshEnabled();
        if (prefs) {
          final shouldReduce = await BatteryService.instance.shouldReduceRefresh();
          if (shouldReduce) {
            debugPrint('Adaptive refresh: skipping frequent update due to low battery');
            return true;
          }
        }
        await WidgetService.refreshWidget();
        await WidgetService.refreshPomodoroWidget();
        await WidgetService.refreshAttendanceWidget();
        await WidgetService.refreshTimetableWidget();
        return true;
      } catch (e) {
        debugPrint('Background widget refresh error: $e');
        return false;
      }
    } else if (task == kWidgetRefreshTaskName) {
      try {
        await WidgetService.refreshWidget();
        await WidgetService.refreshPomodoroWidget();
        await WidgetService.refreshAttendanceWidget();
        await WidgetService.refreshTimetableWidget();
        return true;
      } catch (e) {
        debugPrint('Background widget refresh error: $e');
        return false;
      }
    } else if (task == kAttendanceWidgetRefreshTaskName) {
      try {
        await WidgetService.refreshAttendanceWidget();
        return true;
      } catch (e) {
        debugPrint('Attendance widget refresh error: $e');
        return false;
      }
    } else if (task == kTimetableWidgetRefreshTaskName) {
      try {
        await WidgetService.refreshTimetableWidget();
        return true;
      } catch (e) {
        debugPrint('Timetable widget refresh error: $e');
        return false;
      }
    } else if (task == kBackupTaskName) {
      return Future.value(await BackupService.executeBackup());
    }
    // ── NEW: NEET Countdown Widget Refresh ──
    else if (task == kNeetCountdownTaskName) {
      try {
        await WidgetService.refreshNeetCountdownWidget();
        await WidgetService.refreshSubjectStreakWidget();
        await WidgetService.refreshMcqTargetWidget();
        await WidgetService.refreshRevisionRoundWidget();
        return true;
      } catch (e) {
        debugPrint('NEET widget refresh error: $e');
        return false;
      }
    }
    // ── NEW: NEET Motivational Notification ──
    else if (task == kNeetMotivationTaskName) {
      try {
        await NotificationService.instance.showNeetMotivationNotification();
        return true;
      } catch (e) {
        debugPrint('NEET motivation notification error: $e');
        return false;
      }
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BatteryService.instance.initialize();

  await NotificationService.instance.init();
  await PomodoroService.instance.init();

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    kWidgetRefreshFrequentTaskName,
    kWidgetRefreshFrequentTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 1),
  );

  await Workmanager().registerPeriodicTask(
    kWidgetRefreshTaskName,
    kWidgetRefreshTaskName,
    frequency: const Duration(hours: 4),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  await Workmanager().registerPeriodicTask(
    kAttendanceWidgetRefreshTaskName,
    kAttendanceWidgetRefreshTaskName,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  await Workmanager().registerPeriodicTask(
    kTimetableWidgetRefreshTaskName,
    kTimetableWidgetRefreshTaskName,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // ── NEW: Register NEET Countdown Widget periodic refresh (hourly) ──
  await Workmanager().registerPeriodicTask(
    kNeetCountdownTaskName,
    kNeetCountdownTaskName,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // ── NEW: Register NEET Motivational Notification daily at 6 AM ──
  final now = DateTime.now();
  var next6AM = DateTime(now.year, now.month, now.day, 6, 0, 0);
  if (next6AM.isBefore(now)) {
    next6AM = next6AM.add(const Duration(days: 1));
  }
  await Workmanager().registerPeriodicTask(
    kNeetMotivationTaskName,
    kNeetMotivationTaskName,
    frequency: const Duration(hours: 24),
    initialDelay: next6AM.difference(now),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  await BackupService.registerWeeklyBackup();

  try {
    await WidgetService.refreshWidget();
    await WidgetService.refreshPomodoroWidget();
    await WidgetService.refreshAttendanceWidget();
    await WidgetService.refreshTimetableWidget();
    // ── NEW: Initial refresh of NEET widgets ──
    await WidgetService.refreshNeetCountdownWidget();
    await WidgetService.refreshSubjectStreakWidget();
    await WidgetService.refreshMcqTargetWidget();
    await WidgetService.refreshRevisionRoundWidget();
  } catch (e) {
    debugPrint('Widget refresh error: $e');
  }

  runApp(const EventCountdownApp());
}

class EventCountdownApp extends StatefulWidget {
  const EventCountdownApp({super.key});

  @override
  State<EventCountdownApp> createState() => EventCountdownAppState();
}

class EventCountdownAppState extends State<EventCountdownApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetService.refreshWidget();
      WidgetService.refreshPomodoroWidget();
      WidgetService.refreshAttendanceWidget();
      WidgetService.refreshTimetableWidget();
      // ── NEW: Refresh NEET widgets on app resume ──
      WidgetService.refreshNeetCountdownWidget();
      WidgetService.refreshSubjectStreakWidget();
      WidgetService.refreshMcqTargetWidget();
      WidgetService.refreshRevisionRoundWidget();
      PomodoroService.instance.recalculateFromEndTime();
    }
  }

  Future<void> _checkFirstLaunch() async {
    final isFirst = await SettingsService.instance.isFirstLaunch();
    if (!isFirst) return;

    await SettingsService.instance.setFirstLaunch(false);
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
        await WidgetService.refreshPomodoroWidget();
        await WidgetService.refreshAttendanceWidget();
        await WidgetService.refreshTimetableWidget();
        // ── NEW: Refresh NEET widgets after restore ──
        await WidgetService.refreshNeetCountdownWidget();
        await WidgetService.refreshSubjectStreakWidget();
        await WidgetService.refreshMcqTargetWidget();
        await WidgetService.refreshRevisionRoundWidget();

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (context, _) {
        final notifier = ThemeNotifier.instance;
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            return MaterialApp(
              title: 'StudyFlow',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              themeMode: notifier.themeMode,
              theme: notifier.getThemeData(
                Brightness.light,
                dynamicScheme: lightDynamic,
              ),
              darkTheme: notifier.getThemeData(
                Brightness.dark,
                dynamicScheme: darkDynamic,
              ),
              home: const MainScreen(),
              routes: {
                '/widget_settings': (context) => const WidgetSettingsScreen(),
                '/stats': (context) => const StatsScreen(),
              },
            );
          },
        );
      },
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
