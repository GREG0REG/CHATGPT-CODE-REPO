import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../services/notification_service.dart';
import '../services/recurrence_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../theme/app_themes.dart';
import '../event_card.dart';
import 'add_edit_event_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Event> _events = [];
  bool _smartFormat = false;
  bool _use24Hour = true;
  bool _loading = true;
  Timer? _refreshTimer;
  final Set<int> _expandedParents = {};

  final _studyQuotes = const [
    'The future belongs to those who believe in the beauty of their dreams.',
    'Success is the sum of small efforts, repeated day in and day out.',
    'Don\'t watch the clock; do what it does. Keep going.',
    'The only place where success comes before work is in the dictionary.',
    'Your time is limited, don\'t waste it living someone else\'s life.',
    'Education is the passport to the future.',
    'Strive for progress, not perfection.',
    'The expert in anything was once a beginner.',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void pauseRefresh() => _refreshTimer?.cancel();

  void resumeRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) { if (mounted) setState(() {}); },
    );
    _loadEventsOnly();
  }

  Future<void> _loadAll() async {
    await _loadEventsOnly();
    await WidgetService.refreshWidget();
  }

  Future<void> _loadEventsOnly() async {
    final rawEvents = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    final smart = await SettingsService.instance.getSmartFormatEnabled();
    final use24 = await SettingsService.instance.getUse24HourFormat();
    final expanded = RecurrenceService.expandEvents(rawEvents, now);

    if (!mounted) return;
    setState(() {
      _events = expanded;
      _smartFormat = smart;
      _use24Hour = use24;
      _loading = false;
    });
  }

  Future<void> _toggleComplete(Event event, bool completed) async {
    HapticFeedback.lightImpact();
    final updated = event.copyWith(isCompleted: completed);
    await DatabaseHelper.instance.updateEvent(updated);
    await WidgetService.refreshWidget();
    if (mounted) setState(() {});
    await _loadEventsOnly();
  }

  void _toggleExpand(int parentId) {
    setState(() {
      if (_expandedParents.contains(parentId)) {
        _expandedParents.remove(parentId);
      } else {
        _expandedParents.add(parentId);
      }
    });
  }

  Future<void> _openAddEdit({Event? existing}) async {
    Event? eventToEdit = existing;
    if (existing != null && existing.id != null && existing.id! < 0) {
      final parentId = -existing.id!;
      final parent = await DatabaseHelper.instance.getEvent(parentId);
      if (parent != null) {
        final choice = await showDialog<_EditChoice>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Recurring Event'),
            content: const Text('This is a recurring event. What would you like to edit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, _EditChoice.series),
                child: const Text('Edit Series'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _EditChoice.occurrence),
                child: const Text('Edit This Date Only'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        if (choice == _EditChoice.series) {
          eventToEdit = parent;
        } else {
          eventToEdit = parent.copyWith(
            dateMillis: existing.dateMillis,
            startTimeMillis: existing.startTimeMillis,
            deadlineMillis: existing.deadlineMillis,
            recurrence: RecurrenceType.none,
          );
        }
      }
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditEventScreen(existing: eventToEdit)),
    );
    if (result == true) await _loadAll();
  }

  Future<void> _deleteEvent(Event event) async {
    if (event.id != null && event.id! < 0) {
      final parentId = -event.id!;
      final parent = await DatabaseHelper.instance.getEvent(parentId);
      if (parent == null) return;

      final choice = await showDialog<_DeleteChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Delete Recurring Event'),
          content: Text('Delete "${event.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.skip),
              child: const Text('Skip This Date'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.series),
              child: const Text('Delete Series'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (choice == null) return;
      HapticFeedback.mediumImpact();

      if (choice == _DeleteChoice.series) {
        setState(() {
          _events.removeWhere((e) =>
              e.id == event.id ||
              (e.id != null && e.id! < 0 && -e.id! == parentId));
        });
        await DatabaseHelper.instance.deleteEvent(parentId);
        await NotificationService.instance.cancelForEvent(parentId);
      } else {
        final excluded = List<int>.from(parent.excludedDates);
        excluded.add(event.dateMillis);
        final updated = parent.copyWith(excludedDatesJson: jsonEncode(excluded));
        await DatabaseHelper.instance.updateEvent(updated);
        setState(() {
          _events.removeWhere((e) =>
              e.id == event.id ||
              (e.id != null && e.id! < 0 && e.dateMillis == event.dateMillis));
        });
      }
      await WidgetService.refreshWidget();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete event?'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;
    HapticFeedback.mediumImpact();

    if (event.id != null) {
      setState(() => _events.removeWhere((e) => e.id == event.id));
      await DatabaseHelper.instance.deleteEvent(event.id!);
      await NotificationService.instance.cancelForEvent(event.id!);
      await WidgetService.refreshWidget();
    }
  }

  List<_EventGroup> _buildGroups(List<Event> events) {
    final groups = <_EventGroup>[];
    final parentMap = <int, List<Event>>{};
    final nonRecurring = <Event>[];
    final parentEvents = <Event>[];

    for (final event in events) {
      if (event.id != null && event.id! < 0) {
        final parentId = -event.id!;
        parentMap.putIfAbsent(parentId, () => []).add(event);
      } else if (event.isRecurring && event.id != null && event.id! > 0) {
        parentEvents.add(event);
      } else {
        nonRecurring.add(event);
      }
    }

    for (final event in nonRecurring) {
      groups.add(_EventGroup(parent: event, children: []));
    }
    for (final event in parentEvents) {
      final children = parentMap[event.id] ?? [];
      groups.add(_EventGroup(parent: event, children: children));
    }

    groups.sort((a, b) {
      final aMillis = a.children.isNotEmpty
          ? a.children.first.primarySortMillis
          : a.parent.primarySortMillis;
      final bMillis = b.children.isNotEmpty
          ? b.children.first.primarySortMillis
          : b.parent.primarySortMillis;
      return aMillis.compareTo(bMillis);
    });

    return groups;
  }

  String _randomQuote() {
    final index = DateTime.now().millisecond % _studyQuotes.length;
    return _studyQuotes[index];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups(_events);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Countdown'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await _loadAll();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isRecurringParent = group.parent.isRecurring &&
                          group.parent.id != null && group.parent.id! > 0;
                      final hasChildren = group.children.isNotEmpty;
                      final isExpanded =
                          isRecurringParent && _expandedParents.contains(group.parent.id);

                      return EventCard(
                        key: ValueKey('parent_${group.parent.id}'),
                        event: group.parent,
                        smartFormatEnabled: _smartFormat,
                        use24HourFormat: _use24Hour,
                        onTap: () => _openAddEdit(existing: group.parent),
                        onDelete: () => _deleteEvent(group.parent),
                        onComplete: (completed) => _toggleComplete(group.parent, completed),
                        childOccurrences: group.children,
                        onExpandToggle:
                            hasChildren ? () => _toggleExpand(group.parent.id!) : null,
                        isExpanded: isExpanded,
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

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary.withOpacity(0.3), cs.secondary.withOpacity(0.3)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 36,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No events yet!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first event.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppThemes.glassmorphism(
                context: context,
                opacity: 0.08,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.format_quote, color: cs.primary, size: 24),
                  const SizedBox(height: 12),
                  Text(
                    _randomQuote(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EditChoice { series, occurrence }
enum _DeleteChoice { series, skip }

class _EventGroup {
  final Event parent;
  final List<Event> children;
  _EventGroup({required this.parent, required this.children});
}
