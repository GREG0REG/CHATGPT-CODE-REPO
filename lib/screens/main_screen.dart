// FILE: lib/screens/main_screen.dart
// COMPLETE REPLACEMENT — "NEET Flow" Premium Shell with Syllabus Tab
// CHANGES:
//  1. Added SyllabusListScreen as new bottom navigation tab
//  2. Updated bottom nav items, indices, and screens list
//  3. All other features preserved (countdown, drawer, stats, etc.)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/event.dart';
import 'home_screen.dart';
import 'pomodoro_screen.dart';
import 'stats_screen.dart';
import 'flashcard_screen.dart';
import 'grade_calculator_screen.dart';
import 'assignment_tracker_screen.dart';
import 'study_log_screen.dart';
import 'quick_notes_screen.dart';
import 'attendance_screen.dart';
import 'timetable_screen.dart';
import 'settings_screen.dart';
import 'habit_screen.dart';
import 'reading_screen.dart';
// NEW: Syllabus imports
import 'syllabus_list_screen.dart';
import 'study_planner_screen.dart';

final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _bottomNavSelectedIndex = 0;
  bool _trackingExpanded = false;

  late final AnimationController _chevronController;
  late final Animation<double> _chevronAnimation;
  late final AnimationController _pulseController;
  late final AnimationController _confettiController;
  late final AnimationController _flameController;

  // ── NEET Countdown ──
  late DateTime _neetTargetDate;
  Timer? _countdownTimer;
  String _countdownText = '';

  // ── Live Stats ──
  int _todayMinutes = 0;
  int _todaySessions = 0;
  int _streak = 0;

  // ── NEET Subject Breakdown ──
  Map<String, int> _neetSubjectMinutes = {};

  // ── Badges ──
  int _todayEventsCount = 0;
  int _dueFlashcardsCount = 0;
  int _todayTimetableCount = 0;

  // ── Quotes ──
  final List<String> _medicalQuotes = const [
    'The white coat is earned in these silent hours.',
    'Your future patients are waiting for you to study today.',
    'Medicine is a science of uncertainty and an art of probability.',
    'The difference between ordinary and extraordinary is that little extra.',
    'One day, these books will become your superpower.',
    'Stethoscopes are earned, not given.',
    'Success is the sum of small efforts, repeated day in and day out.',
    'Dream of the white coat. Study like it depends on it.',
  ];
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  // ── Schedule Peek ──
  List<Map<String, dynamic>> _nextItems = [];

  // ── Confetti ──
  bool _showConfetti = false;
  final List<_ConfettiParticle> _particles = [];

  // Bottom nav → screen index mapping
  final List<int> _bottomNavIndices = const [0, 1, 9, 2, 6, 10];
  final List<_NavItem> _bottomItems = const [
    _NavItem(index: 0, label: 'Home', icon: Icons.calendar_today),
    _NavItem(index: 1, label: 'Focus', icon: Icons.timer),
    _NavItem(index: 9, label: 'Table', icon: Icons.schedule),
    _NavItem(index: 2, label: 'Cards', icon: Icons.style),
    _NavItem(index: 6, label: 'Read', icon: Icons.menu_book),
    _NavItem(index: 10, label: 'Syllabus', icon: Icons.subject), // NEW
  ];

  // Habit REMOVED from main drawer — now only in Tracking section
  final List<_DrawerItem> _drawerItems = const [
    _DrawerItem(index: 3, label: 'Assignments', icon: Icons.assignment),
    _DrawerItem(index: 4, label: 'Stats', icon: Icons.bar_chart),
    _DrawerItem(index: 5, label: 'Quick Notes', icon: Icons.note_alt),
  ];

  final List<_DrawerItem> _trackingItems = const [
    _DrawerItem(index: 9, label: 'Timetable', icon: Icons.schedule, isTracking: true),
    _DrawerItem(index: 8, label: 'Attendance', icon: Icons.fact_check, isTracking: true),
    _DrawerItem(index: 6, label: 'Reading', icon: Icons.menu_book, isTracking: true),
    _DrawerItem(index: 7, label: 'Habits', icon: Icons.check_circle_outline, isTracking: true),
  ];

  // Screens list – added SyllabusListScreen at index 10
  final List<Widget> _screens = const [
    HomeScreen(), // 0
    PomodoroScreen(), // 1
    FlashcardScreen(), // 2
    AssignmentTrackerScreen(), // 3
    StatsScreen(), // 4
    QuickNotesScreen(), // 5
    ReadingScreen(), // 6
    HabitScreen(), // 7
    AttendanceScreen(), // 8
    TimetableScreen(), // 9
    SyllabusListScreen(), // 10  ← NEW
  ];

  @override
  void initState() {
    super.initState();
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _chevronAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _neetTargetDate = _calculateNeetDate();
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );

    _quoteIndex = Random().nextInt(_medicalQuotes.length);
    _quoteTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) {
          setState(() => _quoteIndex = (_quoteIndex + 1) % _medicalQuotes.length);
        }
      },
    );

    _loadLiveData();
    _loadBadges();
    _loadSchedulePeek();
    _checkStreakCelebration();
  }

  DateTime _calculateNeetDate() {
    final now = DateTime.now();
    var target = DateTime(now.year, 5, 4);
    if (target.isBefore(now)) target = DateTime(now.year + 1, 5, 4);
    return target;
  }

  void _updateCountdown() {
    final diff = _neetTargetDate.difference(DateTime.now());
    if (diff.isNegative) {
      if (mounted) setState(() => _countdownText = 'EXAM DAY!');
      return;
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (mounted) {
      setState(() => _countdownText = '${days}d ${hours}h ${mins}m');
    }
  }

  Future<void> _loadLiveData() async {
    final mins = await DatabaseHelper.instance.getTodayStudyMinutes();
    final streak = await DatabaseHelper.instance.getLatestStreak();
    final neetBreakdown = await DatabaseHelper.instance.getTodayNeetSubjectMinutes();

    // Session count today
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;
    final sessionResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM study_sessions WHERE completedAtMillis >= ? AND completedAtMillis < ?',
      [start, end],
    );
    final sessions = (sessionResult.first['c'] as int?) ?? 0;

    if (mounted) {
      setState(() {
        _todayMinutes = mins;
        _todaySessions = sessions;
        _streak = streak;
        _neetSubjectMinutes = neetBreakdown;
      });
    }
  }

  Future<void> _loadBadges() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;

    // Today's incomplete events
    final events = await db.query(
      'events',
      where: 'dateMillis >= ? AND dateMillis < ? AND isCompleted = 0',
      whereArgs: [start, end],
    );

    // Due flashcards
    final dueCards = await DatabaseHelper.instance.getFlashcardsDueForReview(end);

    // Today's timetable items
    final dayOfWeek = now.weekday;
    final classes = await db.query(
      'timetable_classes',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
    );
    final tasks = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ? AND isCompleted = 0',
      whereArgs: [start, end],
    );

    if (mounted) {
      setState(() {
        _todayEventsCount = events.length;
        _dueFlashcardsCount = dueCards.length;
        _todayTimetableCount = classes.length + tasks.length;
      });
    }
  }

  Future<void> _loadSchedulePeek() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;

    final classes = await db.query(
      'timetable_classes',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
      orderBy: 'startTimeMinutes ASC',
    );
    final tasks = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ? AND isCompleted = 0',
      whereArgs: [start, end],
      orderBy: 'startTimeMinutes ASC',
    );

    final items = <Map<String, dynamic>>[];
    for (final c in classes) {
      items.add({...c, 'kind': 'class', 'sort': c['startTimeMinutes'] as int});
    }
    for (final t in tasks) {
      items.add({...t, 'kind': 'task', 'sort': (t['startTimeMinutes'] as int?) ?? 0});
    }
    items.sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));

    if (mounted) setState(() => _nextItems = items.take(2).toList());
  }

  void _checkStreakCelebration() async {
    if (_streak >= 3) {
      _spawnConfetti();
      _confettiController.forward().whenComplete(() {
        if (mounted) setState(() => _showConfetti = false);
      });
    }
  }

  void _spawnConfetti() {
    final emojis = ['🎉', '🔥', '🧠', '💊', '⚡', '🩺', '📚'];
    _particles.clear();
    for (int i = 0; i < 20; i++) {
      _particles.add(_ConfettiParticle(
        emoji: emojis[Random().nextInt(emojis.length)],
        left: Random().nextDouble() * 300,
        delay: Random().nextDouble() * 2,
        duration: 1.5 + Random().nextDouble() * 2,
      ));
    }
    setState(() => _showConfetti = true);
  }

  @override
  void dispose() {
    _chevronController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    _flameController.dispose();
    _countdownTimer?.cancel();
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _toggleTracking() {
    setState(() => _trackingExpanded = !_trackingExpanded);
    _trackingExpanded ? _chevronController.forward() : _chevronController.reverse();
  }

  void _selectDrawerIndex(int index) {
    HapticFeedback.lightImpact();
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
    Navigator.of(context).pop();
  }

  void _onBottomNavTap(int bottomIndex) {
    HapticFeedback.lightImpact();
    final screenIndex = _bottomNavIndices[bottomIndex];
    if (_currentIndex != screenIndex) {
      setState(() {
        _bottomNavSelectedIndex = bottomIndex;
        _currentIndex = screenIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    if (isWide) {
      return _buildWideLayout(cs);
    }
    return _buildNarrowLayout(cs);
  }

  // ═══════════════════════════════════════════════════════════════
  // WIDE LAYOUT (Tablet / Desktop)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildWideLayout(ColorScheme cs) {
    return Scaffold(
      key: mainScaffoldKey,
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 800,
            minExtendedWidth: 200,
            backgroundColor: cs.surface,
            selectedIndex: _bottomNavSelectedIndex,
            onDestinationSelected: _onBottomNavTap,
            leading: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPulsingMedicalIcon(cs, 28),
                  const SizedBox(height: 8),
                  Text('NEET Flow', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 14)),
                ],
              ),
            ),
            destinations: _bottomItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon, color: cs.onSurfaceVariant),
                selectedIcon: Icon(item.icon, color: cs.primary),
                label: Text(item.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildCountdownBanner(cs),
                    if (_neetSubjectMinutes.isNotEmpty) _buildNeetSubjectBreakdown(cs),
                    if (_nextItems.isNotEmpty) _buildSchedulePeek(cs),
                    Expanded(
                      child: IndexedStack(index: _currentIndex, children: _screens),
                    ),
                  ],
                ),
                if (_showConfetti) _buildConfettiLayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NARROW LAYOUT (Phone)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNarrowLayout(ColorScheme cs) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: mainScaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _buildDrawerHeader(cs),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),
                    ..._drawerItems.map((item) => _buildDrawerItem(item, cs)),
                    const Divider(height: 24, indent: 16, endIndent: 16),
                    _buildTrackingHeader(cs),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF5F5F5),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: _trackingExpanded
                            ? Column(
                                children: _trackingItems
                                    .map((item) => _buildDrawerItem(item, cs))
                                    .toList(),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.settings, color: cs.onSurfaceVariant),
                title: Text('Settings', style: TextStyle(color: cs.onSurfaceVariant)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // SafeArea offset for countdown to avoid status bar overlap
              SizedBox(height: topPadding > 0 ? 4 : 8),
              _buildCountdownBanner(cs),
              if (_neetSubjectMinutes.isNotEmpty) _buildNeetSubjectBreakdown(cs),
              if (_nextItems.isNotEmpty) _buildSchedulePeek(cs),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
            ],
          ),
          if (_showConfetti) _buildConfettiLayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavSelectedIndex,
        onDestinationSelected: _onBottomNavTap,
        destinations: _bottomItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon, color: cs.primary),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DRAWER HEADER — Medical Theme + Live Stats + Quotes + NEET Chips
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDrawerHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF00695C),
            Color(0xFF004D40),
            Color(0xFF263238),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPulsingMedicalIcon(cs, 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEET Flow',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 800),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _medicalQuotes[_quoteIndex],
                          key: ValueKey<int>(_quoteIndex),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _liveStat('$_todaySessions', 'Sessions', Icons.timer, cs),
                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                  _liveStat('$_todayMinutes', 'Min Today', Icons.local_fire_department, cs),
                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                  _buildStreakStat(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // NEET Subject Quick Chips
            if (_neetSubjectMinutes.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _neetSubjectMinutes.entries.map((entry) {
                  final colors = {
                    'Physics': const Color(0xFF1565C0),
                    'Chemistry': const Color(0xFF2E7D32),
                    'Biology': const Color(0xFFC62828),
                    'General': const Color(0xFF6A1B9A),
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (colors[entry.key] ?? cs.primary).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (colors[entry.key] ?? cs.primary).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingMedicalIcon(ColorScheme cs, double iconSize) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: iconSize * 2.1,
        height: iconSize * 2.1,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFE0F2F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.local_hospital, color: cs.primary, size: iconSize),
      ),
    );
  }

  Widget _liveStat(String value, String label, IconData icon, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.amber.shade300),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakStat() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_flameController.value * 0.15),
                  child: Icon(
                    Icons.whatshot,
                    size: 14,
                    color: _streak > 0 ? Colors.orange.shade400 : Colors.white.withOpacity(0.5),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            Text(
              '$_streak',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _streak > 0 ? Colors.orange.shade300 : Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Streak',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ENHANCED COUNTDOWN BANNER — Better spacing, circular progress
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCountdownBanner(ColorScheme cs) {
    final now = DateTime.now();
    final totalDays = _neetTargetDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    final maxDays = 365;
    final progress = (totalDays / maxDays).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C), Color(0xFF7F0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular progress ring
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_available, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEET EXAM',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_neetTargetDate.day}/${_neetTargetDate.month}/${_neetTargetDate.year}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _countdownText,
                    key: ValueKey<String>(_countdownText),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalDays days until your exam',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _neetTargetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: const Color(0xFFD32F2F),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) setState(() => _neetTargetDate = picked);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_calendar, color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'EDIT',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NEET SUBJECT BREAKDOWN MINI-CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNeetSubjectBreakdown(ColorScheme cs) {
    final subjectColors = {
      'Physics': const Color(0xFF1565C0),
      'Chemistry': const Color(0xFF2E7D32),
      'Biology': const Color(0xFFC62828),
      'General': const Color(0xFF6A1B9A),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Today\'s Subject Breakdown',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _neetSubjectMinutes.entries.map((entry) {
              final color = subjectColors[entry.key] ?? cs.primary;
              final total = _neetSubjectMinutes.values.fold(0, (a, b) => a + b);
              final pct = total > 0 ? (entry.value / total) : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            height: 40 * pct,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key.substring(0, min(3, entry.key.length)),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        '${entry.value}m',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SCHEDULE PEEK
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSchedulePeek(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upcoming, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Up Next Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._nextItems.map((item) {
            final isClass = item['kind'] == 'class';
            final name = isClass
                ? (item['subjectName'] as String? ?? 'Class')
                : (item['title'] as String? ?? 'Task');
            final start = item['startTimeMinutes'] as int? ?? 0;
            final h = start ~/ 60;
            final m = start % 60;
            final timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isClass ? cs.primary : Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isClass ? cs.primary.withOpacity(0.12) : Colors.orange.shade600.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isClass ? 'Class' : 'Task',
                      style: TextStyle(
                        fontSize: 9,
                        color: isClass ? cs.primary : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONFETTI OVERLAY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildConfettiLayer() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final progress = ((_confettiController.value - p.delay) / p.duration).clamp(0.0, 1.0);
            final top = -50 + progress * (MediaQuery.of(context).size.height + 100);
            final opacity = progress < 0.8 ? 1.0 : 1.0 - (progress - 0.8) * 5;
            return Positioned(
              top: top,
              left: p.left,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: progress * 4,
                  child: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DRAWER ITEMS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDrawerItem(_DrawerItem item, ColorScheme cs) {
    final isSelected = _currentIndex == item.index;
    int badge = 0;
    if (item.label == 'Assignments') badge = _todayEventsCount;
    if (item.label == 'Flashcards') badge = _dueFlashcardsCount;
    if (item.label == 'Timetable') badge = _todayTimetableCount;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? _itemColor(item.label).withOpacity(0.12) : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.icon,
          size: 18,
          color: isSelected ? _itemColor(item.label) : cs.onSurfaceVariant,
        ),
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      selectedTileColor: _itemColor(item.label).withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Icon(
              Icons.chevron_right,
              size: 18,
              color: isSelected ? _itemColor(item.label).withOpacity(0.5) : cs.outline.withOpacity(0.4),
            ),
      onTap: () => _selectDrawerIndex(item.index),
    );
  }

  Color _itemColor(String label) {
    return switch (label) {
      'Timetable' => const Color(0xFF1565C0),
      'Attendance' => const Color(0xFF00695C),
      'Reading' => const Color(0xFF6A1B9A),
      'Habits' => const Color(0xFF2E7D32),
      'Assignments' => const Color(0xFFE65100),
      'Stats' => const Color(0xFFC62828),
      'Quick Notes' => const Color(0xFF455A64),
      _ => const Color(0xFF607D8B),
    };
  }

  Widget _buildTrackingHeader(ColorScheme cs) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.trending_up, color: cs.primary, size: 18),
      ),
      title: Text(
        'Tracking',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
          fontSize: 14,
        ),
      ),
      trailing: RotationTransition(
        turns: _chevronAnimation,
        child: Icon(Icons.expand_more, color: cs.onSurfaceVariant, size: 20),
      ),
      onTap: _toggleTracking,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════

class _NavItem {
  final int index;
  final String label;
  final IconData icon;
  const _NavItem({required this.index, required this.label, required this.icon});
}

class _DrawerItem {
  final int index;
  final String label;
  final IconData icon;
  final bool isTracking;
  const _DrawerItem({
    required this.index,
    required this.label,
    required this.icon,
    this.isTracking = false,
  });
}

class _ConfettiParticle {
  final String emoji;
  final double left;
  final double delay;
  final double duration;
  _ConfettiParticle({
    required this.emoji,
    required this.left,
    required this.delay,
    required this.duration,
  });
}
