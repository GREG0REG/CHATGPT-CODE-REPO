// FILE: lib/screens/main_screen.dart
// COMPLETE REPLACEMENT — copy and paste entire file

// CHATGPT-CODE-REPO-TEST/lib/screens/main_screen.dart
// UPDATED - Side drawer navigation + Attendance + Timetable

import 'package:flutter/material.dart';
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

/// Side-drawer host for all primary destinations.
/// Uses IndexedStack so that all screens maintain their state across navigation.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _trackingExpanded = false;

  late final AnimationController _chevronController;
  late final Animation<double> _chevronAnimation;

  final _screens = [
    const HomeScreen(),
    const PomodoroScreen(),
    const FlashcardScreen(),
    const AssignmentTrackerScreen(),
    const StatsScreen(),
    const QuickNotesScreen(),
    const StudyLogScreen(),
    const GradeCalculatorScreen(),
    const AttendanceScreen(),
    const TimetableScreen(),
  ];

  final _mainItems = [
    _DrawerItem(index: 0, label: 'Home', icon: Icons.calendar_today, tooltip: 'Events'),
    _DrawerItem(index: 1, label: 'Focus', icon: Icons.timer, tooltip: 'Focus'),
    _DrawerItem(index: 2, label: 'Flashcards', icon: Icons.style, tooltip: 'Flashcards'),
    _DrawerItem(index: 3, label: 'Assignments', icon: Icons.assignment, tooltip: 'Assignments'),
    _DrawerItem(index: 4, label: 'Stats', icon: Icons.bar_chart, tooltip: 'Stats'),
    _DrawerItem(index: 5, label: 'Quick Notes', icon: Icons.note_alt, tooltip: 'Quick Notes'),
  ];

  final _trackingItems = [
    _DrawerItem(index: 8, label: 'Attendance', icon: Icons.fact_check, tooltip: 'Attendance'),
    _DrawerItem(index: 9, label: 'Timetable', icon: Icons.schedule, tooltip: 'Timetable'),
    _DrawerItem(index: 6, label: 'Reading', icon: Icons.menu_book, tooltip: 'Reading', disabled: true),
    _DrawerItem(index: 7, label: 'Habits', icon: Icons.check_circle_outline, tooltip: 'Habits', disabled: true),
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
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggleTracking() {
    setState(() {
      _trackingExpanded = !_trackingExpanded;
    });
    if (_trackingExpanded) {
      _chevronController.forward();
    } else {
      _chevronController.reverse();
    }
  }

  void _selectIndex(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
    Navigator.of(context).pop(); // Close drawer
  }

  String _getAppBarTitle() {
    final allItems = [..._mainItems, ..._trackingItems];
    final item = allItems.firstWhere(
      (i) => i.index == _currentIndex,
      orElse: () => _mainItems.first,
    );
    return item.label;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withOpacity(0.8),
                      cs.secondary.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.surface,
                            cs.surfaceContainerHighest,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school,
                        color: cs.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'StudyFlow',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stay on track 🎯',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main section
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),
                    ..._mainItems.map((item) => _buildDrawerItem(item, cs)),

                    const Divider(height: 24, indent: 16, endIndent: 16),

                    // Tracking expandable section
                    _buildTrackingHeader(cs),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      color: isDark
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

              // Bottom section
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.settings, color: cs.onSurfaceVariant),
                title: Text(
                  'Settings',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }

  Widget _buildDrawerItem(_DrawerItem item, ColorScheme cs) {
    final isSelected = _currentIndex == item.index;

    return ListTile(
      leading: Icon(
        item.icon,
        color: item.disabled
            ? cs.outline
            : isSelected
                ? cs.primary
                : cs.onSurfaceVariant,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color: item.disabled ? cs.outline : cs.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      enabled: !item.disabled,
      selected: isSelected,
      selectedTileColor: cs.primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: item.disabled ? null : () => _selectIndex(item.index),
    );
  }

  Widget _buildTrackingHeader(ColorScheme cs) {
    return ListTile(
      leading: Icon(Icons.trending_up, color: cs.primary),
      title: const Text(
        'Tracking',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: RotationTransition(
        turns: _chevronAnimation,
        child: Icon(
          Icons.expand_more,
          color: cs.onSurfaceVariant,
        ),
      ),
      onTap: _toggleTracking,
    );
  }
}

class _DrawerItem {
  final int index;
  final String label;
  final IconData icon;
  final String tooltip;
  final bool disabled;

  const _DrawerItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.tooltip,
    this.disabled = false,
  });
}
