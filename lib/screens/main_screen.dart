// CHATGPT-CODE-REPO-TEST/lib/screens/main_screen.dart
// UPDATED - All student features integrated

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'pomodoro_screen.dart';
import 'stats_screen.dart';
import 'flashcard_screen.dart';
import 'grade_calculator_screen.dart';
import 'assignment_tracker_screen.dart';
import 'study_log_screen.dart';

/// Bottom-navigation host for all primary destinations.
/// IndexedStack is used so that:
///   - HomeScreen's 60-second refresh timer keeps ticking
///   - PomodoroScreen's active session survives tab switches
///   - StatsScreen doesn't re-fetch data every time you open it
///   - FlashcardScreen preserves review state across tab switches
///   - All other screens maintain their state
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = [
    const HomeScreen(),
    const FlashcardScreen(),
    const AssignmentTrackerScreen(),
    const PomodoroScreen(),
    const StudyLogScreen(),
    const GradeCalculatorScreen(),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex != index) {
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Events',
            tooltip: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Cards',
            tooltip: 'Flashcards',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tasks',
            tooltip: 'Assignments',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Focus',
            tooltip: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Log',
            tooltip: 'Study Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Grades',
            tooltip: 'Grade Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
            tooltip: 'Stats',
          ),
        ],
      ),
    );
  }
}
