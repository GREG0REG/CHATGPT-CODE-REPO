import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'pomodoro_screen.dart';
import 'stats_screen.dart';

/// Bottom-navigation host for the three primary destinations.
/// IndexedStack is used intentionally so that:
///   - HomeScreen's 60-second refresh timer keeps ticking
///   - PomodoroScreen's active session survives tab switches
///   - StatsScreen doesn't re-fetch data every time you open it
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = [
    const HomeScreen(),
    const PomodoroScreen(),
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
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Focus',
            tooltip: 'Focus',
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
