// FILE: lib/screens/home_screen.dart
// COMPLETE REPLACEMENT — NEET-Focused Home Screen v2
// FIXES:
//  1. Reads NEET prefs and conditionally shows/hides countdown + filter chips
//  2. Countdown banner redesigned: moved below AppBar, sleek card style
//  3. Countdown uses theme-aware colors instead of hardcoded red
//  4. Added subject count badges on filter chips
//  5. Added 7-day study streak calendar strip
//  6. Added daily study goal progress ring
//  7. Added subject-wise time breakdown (computed from events)
//  8. Enhanced empty state with rotating quotes
//  9. Quick-add chips now pre-fill subject tag
// PRESERVED: All original CRUD, recurrence, edit/delete, completion

import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../services/notification_service.dart';
import '../services/recurrence_service.dart';
import '../services/settings_service.dart';
import 'package:event_countdown/services/widget_service.dart';
import '../theme/app_themes.dart';
import '../widgets/event_card.dart';
import 'add_edit_event_screen.dart';
import 'settings_screen.dart';
import 'main_screen.dart';

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
  int _streak = 0;
  int _todayMinutes = 0;
  String _activeFilter = 'All';
  Timer? _refreshTimer;
  final Set<int> _expandedParents = {};

  // NEET prefs
  bool _neetModeEnabled = true;
  bool _showCountdownBanner = true;
  bool _showSubjectBreakdown = true;
  DateTime _neetExamDate = DateTime(2027, 5, 4);
  int _dailyStudyGoal = 120;

  // Subject goals
  int _physicsGoal = 120;
  int _chemistryGoal = 120;
  int _biologyGoal = 120;

  // Cached study metrics from DB (not computed from events)
  Map<String, int> _subjectTimeToday = {'Physics': 0, 'Chemistry': 0, 'Biology': 0};
  List<_DayStreak> _weekStreakData = [];

  // Dashboard data
  Map<String, dynamic> _todayAttendance = {'total': 0, 'present': 0, 'absent': 0, 'percentage': 0.0};
  List<Event> _upcomingEvents = [];
  List<Event> _overdueEvents = [];

  // Quote rotation
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  final _neetQuotes = const [
    'Every MCQ you solve brings you closer to AIIMS.',
    'Physics today, doctor tomorrow.',
    'Chemistry is the bridge to your medical dream.',
    'Biology is not just a subject, it's your future.',
    'Stethoscope dreams start with desk lamp hours.',
    'One correct answer at a time. That's the NEET way.',
    'The white coat is earned, not given.',
    'Your competition is sleeping. Are you?',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) { if (mounted) setState(() {}); },
    );
    _quoteTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) {
          setState(() => _quoteIndex = (_quoteIndex + 1) % _neetQuotes.length);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _quoteTimer?.cancel();
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
    await _loadNeetPrefs();
    await _loadEventsOnly();
    await _loadStats();
    await WidgetService.refreshWidget();
  }

  Future<void> _loadNeetPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final neetMode = prefs.getBool('neet_mode_enabled') ?? true;
    final showBanner = prefs.getBool('show_countdown_banner') ?? true;
    final showBreakdown = prefs.getBool('show_subject_breakdown') ?? true;
    final neetDateMs = prefs.getInt('neet_exam_date_millis');
    final dailyGoal = prefs.getInt('dailyStudyGoal') ?? 120;
    final physGoal = prefs.getInt('subjectGoal_Physics') ?? 120;
    final chemGoal = prefs.getInt('subjectGoal_Chemistry') ?? 120;
    final bioGoal = prefs.getInt('subjectGoal_Biology') ?? 120;

    if (mounted) {
      setState(() {
        _neetModeEnabled = neetMode;
        _showCountdownBanner = showBanner;
        _showSubjectBreakdown = showBreakdown;
        _neetExamDate = neetDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(neetDateMs)
            : DateTime(2027, 5, 4);
        _dailyStudyGoal = dailyGoal;
        _physicsGoal = physGoal;
        _chemistryGoal = chemGoal;
        _biologyGoal = bioGoal;
      });
    }
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

  Future<void> _loadStats() async {
    final streak = await DatabaseHelper.instance.getLatestStreak();
    final mins = await DatabaseHelper.instance.getTodayStudyMinutes();
    final subjectMins = await DatabaseHelper.instance.getTodayNeetSubjectMinutes();
    final weekStreak = await _loadWeekStreakFromDb();
    final attendance = await DatabaseHelper.instance.getTodayAttendanceSummary();
    final upcoming = await DatabaseHelper.instance.getUpcomingEvents(7);
    final overdue = await DatabaseHelper.instance.getOverdueEvents();
    if (mounted) {
      setState(() {
        _streak = streak;
        _todayMinutes = mins;
        _subjectTimeToday = {
          'Physics': subjectMins['Physics'] ?? 0,
          'Chemistry': subjectMins['Chemistry'] ?? 0,
          'Biology': subjectMins['Biology'] ?? 0,
        };
        _weekStreakData = weekStreak;
        _todayAttendance = attendance;
        _upcomingEvents = upcoming;
        _overdueEvents = overdue;
      });
    }
  }

  // Load week streak from actual study_sessions DB, not events
  Future<List<_DayStreak>> _loadWeekStreakFromDb() async {
    final now = DateTime.now();
    final result = <_DayStreak>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
      final sessions = await DatabaseHelper.instance.getStudySessionsForDateRange(dayStart, dayEnd);
      result.add(_DayStreak(
        date: day,
        hasEvents: sessions.isNotEmpty,
        isToday: i == 0,
      ));
    }
    return result;
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

  Future<void> _openAddEdit({Event? existing, String? prefillSubject}) async {
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
      MaterialPageRoute(
        builder: (_) => AddEditEventScreen(
          existing: eventToEdit,
          prefillSubject: prefillSubject,
        ),
      ),
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

  List<_EventGroup> _getFilteredGroups() {
    final groups = _buildGroups(_events);
    if (_activeFilter == 'All') return groups;

    return groups.where((g) {
      final subject = g.parent.subjectTag ?? '';
      return subject.toLowerCase().contains(_activeFilter.toLowerCase());
    }).toList();
  }

  // ── Subject counts for badges ──
  Map<String, int> _getSubjectCounts() {
    final counts = <String, int>{'Physics': 0, 'Chemistry': 0, 'Biology': 0};
    for (final e in _events) {
      final tag = e.subjectTag ?? '';
      if (tag.toLowerCase().contains('physics')) counts['Physics'] = counts['Physics']! + 1;
      else if (tag.toLowerCase().contains('chemistry')) counts['Chemistry'] = counts['Chemistry']! + 1;
      else if (tag.toLowerCase().contains('biology')) counts['Biology'] = counts['Biology']! + 1;
    }
    return counts;
  }



  @override
  Widget build(BuildContext context) {
    final groups = _getFilteredGroups();
    final cs = Theme.of(context).colorScheme;
    final subjectCounts = _getSubjectCounts();
    final todayMins = _todayMinutes;
    final subjectTimes = _subjectTimeToday;
    final weekStreak = _weekStreakData;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Event Countdown',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Streak indicator
          if (_streak > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.whatshot, size: 14, color: Colors.orange.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadAll();
              },
              child: CustomScrollView(
                slivers: [
                  // ═══════════════════════════════════════════════════════
                  // NEET COUNTDOWN BANNER (conditionally shown, redesigned)
                  // ═══════════════════════════════════════════════════════
                  if (_neetModeEnabled && _showCountdownBanner)
                    SliverToBoxAdapter(
                      child: _buildNeetCountdownCard(cs),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // STUDY PROGRESS RING + STREAK CALENDAR
                  // ═══════════════════════════════════════════════════════
                  if (_neetModeEnabled)
                    SliverToBoxAdapter(
                      child: _buildStudyProgressSection(cs, todayMins, weekStreak),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // SUBJECT BREAKDOWN (conditionally shown)
                  // ═══════════════════════════════════════════════════════
                  if (_neetModeEnabled && _showSubjectBreakdown)
                    SliverToBoxAdapter(
                      child: _buildSubjectBreakdown(cs, subjectTimes),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // TODAY'S ATTENDANCE DASHBOARD
                  // ═══════════════════════════════════════════════════════
                  if (_neetModeEnabled && (_todayAttendance['total'] as int) > 0)
                    SliverToBoxAdapter(
                      child: _buildAttendanceDashboard(cs),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // OVERDUE EVENTS ALERT
                  // ═══════════════════════════════════════════════════════
                  if (_overdueEvents.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildOverdueAlert(cs),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // UPCOMING EVENTS (next 7 days)
                  // ═══════════════════════════════════════════════════════
                  if (_upcomingEvents.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildUpcomingEvents(cs),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // FILTER CHIPS (only in NEET mode)
                  // ═══════════════════════════════════════════════════════
                  if (_neetModeEnabled && _events.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildFilterChip('All', null, subjectCounts, cs),
                            _buildFilterChip('Physics', const Color(0xFF1565C0), subjectCounts, cs),
                            _buildFilterChip('Chemistry', const Color(0xFF2E7D32), subjectCounts, cs),
                            _buildFilterChip('Biology', const Color(0xFFC62828), subjectCounts, cs),
                          ],
                        ),
                      ),
                    ),

                  // ═══════════════════════════════════════════════════════
                  // EVENTS LIST (or empty state)
                  // ═══════════════════════════════════════════════════════
                  _events.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyState(cs),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.only(top: 4, bottom: 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final group = groups[index];
                                final isRecurringParent = group.parent.isRecurring &&
                                    group.parent.id != null && group.parent.id! > 0;
                                final hasChildren = group.children.isNotEmpty;
                                final isExpanded = isRecurringParent &&
                                    _expandedParents.contains(group.parent.id);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: EventCard(
                                    key: ValueKey('parent_${group.parent.id}'),
                                    event: group.parent,
                                    smartFormatEnabled: _smartFormat,
                                    use24HourFormat: _use24Hour,
                                    onTap: () => _openAddEdit(existing: group.parent),
                                    onDelete: () => _deleteEvent(group.parent),
                                    onComplete: (completed) => _toggleComplete(group.parent, completed),
                                    childOccurrences: group.children,
                                    onExpandToggle: hasChildren
                                        ? () => _toggleExpand(group.parent.id!)
                                        : null,
                                    isExpanded: isExpanded,
                                  ),
                                );
                              },
                              childCount: groups.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
        elevation: 2,
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  // TODAY'S ATTENDANCE DASHBOARD — Quick glance at class attendance
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAttendanceDashboard(ColorScheme cs) {
    final total = (_todayAttendance['total'] as int?) ?? 0;
    final present = (_todayAttendance['present'] as int?) ?? 0;
    final absent = (_todayAttendance['absent'] as int?) ?? 0;
    final percentage = (_todayAttendance['percentage'] as double?) ?? 0.0;
    final progress = total > 0 ? present / total : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                "Today's Attendance",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (absent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$absent missed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$present/$total sessions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${percentage.toStringAsFixed(0)}% present',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 0.75 ? Colors.green : progress >= 0.5 ? Colors.orange : cs.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // OVERDUE EVENTS ALERT — Shows missed deadlines/tests
  // ═══════════════════════════════════════════════════════════════
  Widget _buildOverdueAlert(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Text(
                'Overdue: ${_overdueEvents.length} item(s)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._overdueEvents.take(3).map((event) {
            final daysOverdue = DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(event.dateMillis),
            ).inDays;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _openAddEdit(existing: event),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy, size: 16, color: cs.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        daysOverdue == 0 ? 'Today' : '$daysOverdue d ago',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UPCOMING EVENTS — Next 7 days reminder strip
  // ═══════════════════════════════════════════════════════════════
  Widget _buildUpcomingEvents(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upcoming, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Upcoming (${_upcomingEvents.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._upcomingEvents.take(5).map((event) {
            final eventDate = DateTime.fromMillisecondsSinceEpoch(event.dateMillis);
            final daysUntil = eventDate.difference(DateTime.now()).inDays;
            final isToday = daysUntil == 0 && eventDate.day == DateTime.now().day;
            final dayLabel = isToday
                ? 'Today'
                : daysUntil == 1
                    ? 'Tomorrow'
                    : '$daysUntil days';

            Color urgencyColor = cs.primary;
            if (daysUntil <= 1) urgencyColor = cs.error;
            else if (daysUntil <= 3) urgencyColor = Colors.orange;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _openAddEdit(existing: event),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: urgencyColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NEET COUNTDOWN CARD — Redesigned, below AppBar, theme-aware
  // ═══════════════════════════════════════════════════════════════  // ═══════════════════════════════════════════════════════════════
  // NEET COUNTDOWN CARD — Redesigned, below AppBar, theme-aware
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNeetCountdownCard(ColorScheme cs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(_neetExamDate.year, _neetExamDate.month, _neetExamDate.day);
    final diff = exam.difference(today);
    final days = diff.inDays;

    final primary = cs.primary;
    final isUrgent = days <= 30;
    final cardColor = isUrgent
        ? Color.lerp(cs.errorContainer, cs.surface, 0.7)!
        : cs.primaryContainer.withOpacity(0.3);
    final accentColor = isUrgent ? cs.error : primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor,
            cs.surfaceContainerHighest.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await _loadAll();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'NEET EXAM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_calendar, size: 12, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'EDIT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 40,
                        color: accentColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (days > 0)
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                    height: 1.1,
                                  ),
                                  children: [
                                    TextSpan(text: '$days'),
                                    TextSpan(
                                      text: 'd ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    TextSpan(text: '${diff.inHours % 24}'),
                                    TextSpan(
                                      text: 'h ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    TextSpan(text: '${diff.inMinutes % 60}'),
                                    TextSpan(
                                      text: 'm',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                days == 0 ? 'Today!' : 'Exam passed',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              days >= 0
                                  ? '$days days until your exam'
                                  : '${-days} days since exam',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar to exam
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: days > 365 ? 0.05 : (365 - days) / 365,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STUDY PROGRESS + STREAK CALENDAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStudyProgressSection(ColorScheme cs, int todayMins, List<_DayStreak> streak) {
    final goalProgress = (todayMins / _dailyStudyGoal).clamp(0.0, 1.0);
    final goalPercent = (goalProgress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: goalProgress,
                      strokeWidth: 5,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                    Center(
                      child: Text(
                        '$goalPercent%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today's Study Goal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${todayMins ~/ 60}h ${todayMins % 60}m / ${_dailyStudyGoal ~/ 60}h ${_dailyStudyGoal % 60}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: goalProgress,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goalProgress >= 1.0 ? Colors.green : cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 7-day streak strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: streak.map((day) => _buildStreakDot(day, cs)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakDot(_DayStreak day, ColorScheme cs) {
    final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.date.weekday - 1];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: day.hasEvents
                ? (day.isToday ? cs.primary : Colors.green.shade400)
                : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: day.isToday
                ? Border.all(color: cs.primary, width: 2)
                : null,
          ),
          child: day.hasEvents
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
            color: day.isToday ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUBJECT TIME BREAKDOWN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSubjectBreakdown(ColorScheme cs, Map<String, int> times) {
    final subjects = [
      _SubjectBreakdown('Physics', times['Physics']!, _physicsGoal, const Color(0xFF1565C0)),
      _SubjectBreakdown('Chemistry', times['Chemistry']!, _chemistryGoal, const Color(0xFF2E7D32)),
      _SubjectBreakdown('Biology', times['Biology']!, _biologyGoal, const Color(0xFFC62828)),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today's Subject Split',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: subjects.map((s) => Expanded(
              child: _buildSubjectBar(s, cs),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBar(_SubjectBreakdown subject, ColorScheme cs) {
    final progress = (subject.minutes / subject.goal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 24,
                height: 60,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 24,
                height: 60 * progress,
                decoration: BoxDecoration(
                  color: subject.color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subject.name.substring(0, 3),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subject.color,
            ),
          ),
          Text(
            '${subject.minutes}m',
            style: TextStyle(
              fontSize: 9,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTER CHIP WITH COUNT BADGE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFilterChip(String label, Color? color, Map<String, int> counts, ColorScheme cs) {
    final isActive = _activeFilter == label;
    final chipColor = color ?? cs.primary;
    final count = label == 'All' ? _events.length : (counts[label] ?? 0);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isActive,
        showCheckmark: false,
        selectedColor: chipColor.withOpacity(0.15),
        backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
        side: BorderSide(
          color: isActive ? chipColor.withOpacity(0.5) : cs.outlineVariant.withOpacity(0.3),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? chipColor : cs.onSurfaceVariant,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? chipColor.withOpacity(0.2) : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive ? chipColor : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (selected) {
          HapticFeedback.lightImpact();
          setState(() => _activeFilter = selected ? label : 'All');
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.2),
                    cs.secondary.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.local_hospital_outlined,
                size: 44,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No events yet!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your NEET preparation journey.
Tap below to add your first milestone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.outline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Rotating Quote Card
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey<int>(_quoteIndex),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withOpacity(0.3),
                      cs.secondaryContainer.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.format_quote, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'NEET Motivation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _neetQuotes[_quoteIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurface.withOpacity(0.75),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Quick-add NEET events with prefill
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickAddChip('Physics Test', Icons.science, const Color(0xFF1565C0), 'Physics'),
                _buildQuickAddChip('Chemistry Test', Icons.biotech, const Color(0xFF2E7D32), 'Chemistry'),
                _buildQuickAddChip('Biology Test', Icons.eco, const Color(0xFFC62828), 'Biology'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddChip(String label, IconData icon, Color color, String subject) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.2)),
      onPressed: () => _openAddEdit(prefillSubject: subject),
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

class _DayStreak {
  final DateTime date;
  final bool hasEvents;
  final bool isToday;
  _DayStreak({required this.date, required this.hasEvents, required this.isToday});
}

class _SubjectBreakdown {
  final String name;
  final int minutes;
  final int goal;
  final Color color;
  _SubjectBreakdown(this.name, this.minutes, this.goal, this.color);
}
