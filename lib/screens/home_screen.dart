import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/event.dart';
import '../services/battery_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../widgets/event_card.dart';
import 'add_edit_event_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  static final GlobalKey<_HomeScreenState> homeScreenKey =
      GlobalKey<_HomeScreenState>();
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Event> _events = [];
  bool _smartFormat = false;
  bool _use24Hour = true;
  bool _loading = true;
  Timer? _refreshTimer;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // SESSION 9: Lifecycle pause/resume
  // ============================================
  void pauseRefresh() {
    _paused = true;
    _refreshTimer?.cancel();
  }

  void resumeRefresh() {
    _paused = false;
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (_paused) return;
    await _loadEventsOnly();
    await _generateRecurringEvents();
    await WidgetService.refreshWidget();
    _setupAdaptiveRefresh();
  }

  // ============================================
  // SESSION 5: Auto-generate recurring events
  // ============================================
  Future<void> _generateRecurringEvents() async {
    final now = DateTime.now();
    final nowMillis = now.millisecondsSinceEpoch;
    final recurringPassed = _events.where((e) {
      return e.isRecurring && e.finalMillis < nowMillis;
    }).toList();

    for (final event in recurringPassed) {
      final next = event.generateNextOccurrence();
      if (next != null) {
        // Delete old completed event and insert next occurrence
        if (event.id != null) {
          await DatabaseHelper.instance.deleteEvent(event.id!);
          await NotificationService.instance.cancelForEvent(event.id!);
        }
        final newId = await DatabaseHelper.instance.insertEvent(next);
        final savedNext = next.copyWith(id: newId);
        try {
          await NotificationService.instance.scheduleForEvent(savedNext);
        } catch (e) {
          debugPrint('Notification schedule error: $e');
        }
      }
    }

    if (recurringPassed.isNotEmpty) {
      // Reload events if any were regenerated
      final refreshed = await DatabaseHelper.instance.getAllEventsSorted();
      if (mounted) {
        setState(() => _events = refreshed);
      }
    }
  }

  // ============================================
  // SESSION 9: Adaptive refresh based on nearest event
  // ============================================
  void _setupAdaptiveRefresh() async {
    _refreshTimer?.cancel();

    final adaptiveEnabled = await SettingsService.instance.getAdaptiveRefreshEnabled();
    if (!adaptiveEnabled) {
      // Fallback to fixed 60s
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _loadEventsOnly(),
      );
      return;
    }

    final now = DateTime.now();
    final activeEvents = _events.where((e) => e.finalMillis > now.millisecondsSinceEpoch).toList();
    if (activeEvents.isEmpty) {
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _loadEventsOnly(),
      );
      return;
    }

    final nearest = activeEvents.map((e) => e.finalMillis).reduce((a, b) => a < b ? a : b);
    final diff = Duration(milliseconds: nearest - now.millisecondsSinceEpoch);

    Duration interval;
    if (diff.inHours > 24) {
      interval = const Duration(minutes: 5);
    } else if (diff.inHours > 1) {
      interval = const Duration(minutes: 1);
    } else {
      interval = const Duration(seconds: 5);
    }

    // Battery optimization: slow down if low battery and not charging
    final isLow = await BatteryService.instance.isLowBattery();
    final isCharging = await BatteryService.instance.isCharging();
    if (isLow && !isCharging) {
      interval = interval > const Duration(minutes: 5) ? interval : const Duration(minutes: 5);
    }

    _refreshTimer = Timer.periodic(interval, (_) => _loadEventsOnly());
  }

  Future<void> _loadEventsOnly() async {
    if (_paused) return;
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final use24 = await SettingsService.instance.getUse24HourFormat();
    if (!mounted) return;
    setState(() {
      _events = events;
      _smartFormat = smart;
      _use24Hour = use24;
      _loading = false;
    });
  }

  Future<void> _openAddEdit({Event? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditEventScreen(existing: existing),
      ),
    );
    if (result == true) {
      await _loadAll();
    }
  }

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    HapticFeedback.mediumImpact();

    if (event.id != null) {
      setState(() {
        _events.removeWhere((e) => e.id == event.id);
      });

      await DatabaseHelper.instance.deleteEvent(event.id!);
      await NotificationService.instance.cancelForEvent(event.id!);
      await WidgetService.refreshWidget();
    }
  }

  // ============================================
  // SESSION 6: Share all events summary
  // ============================================
  Future<void> _shareEvents() async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events to share')),
      );
      return;
    }

    final now = DateTime.now();
    final buffer = StringBuffer('My Event Countdowns\n\n');
    for (final e in _events.take(10)) {
      final text = e.getCountdownText(now, smartFormatEnabled: _smartFormat);
      buffer.writeln('• ${e.title}: $text');
    }
    await Share.share(buffer.toString(), subject: 'My Event Countdowns');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Countdown'),
        actions: [
          // SESSION 6: Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareEvents,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadAll();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No exams yet!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first exam.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return EventCard(
                        key: ValueKey(event.id),
                        event: event,
                        smartFormatEnabled: _smartFormat,
                        use24HourFormat: _use24Hour,
                        onTap: () => _openAddEdit(existing: event),
                        onDelete: () => _deleteEvent(event),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
