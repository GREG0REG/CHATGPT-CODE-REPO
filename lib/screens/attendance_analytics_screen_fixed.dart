// FILE: lib/screens/attendance_analytics_screen.dart
// NEW FILE — Attendance Analytics Dashboard (NEET Edition)
// FIXED: Division by zero when required=100
// CHANGED: "Class" → "Session" throughout
// ENHANCED: Medical theme, NEET countdown, subject priority badges

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import 'attendance_detail_screen.dart';

class AttendanceAnalyticsScreen extends StatefulWidget {
  const AttendanceAnalyticsScreen({super.key});

  @override
  State<AttendanceAnalyticsScreen> createState() =>
      _AttendanceAnalyticsScreenState();
}

class _AttendanceAnalyticsScreenState extends State<AttendanceAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _weeklyGrid = [];
  int _currentWeekOffset = 0;
  late TabController _tabController;

  static const List<String> _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final subjectRows =
        await DatabaseHelper.instance.getAllAttendanceSubjects();
    final subjects = <Map<String, dynamic>>[];

    for (final row in subjectRows) {
      final id = (row['id'] as int?) ?? 0;
      final name = row['name'] as String;
      final requiredPct =
          (row['requiredPercentage'] as num?)?.toDouble() ?? 75.0;
      final colorHex = row['colorHex'] as String? ?? '#2196F3';
      final color = _hexToColor(colorHex);

      final stats =
          await DatabaseHelper.instance.getAttendanceStatsForSubject(name);
      final present = (stats['present'] as int?) ?? 0;
      final absent = (stats['absent'] as int?) ?? 0;
      final late = (stats['late'] as int?) ?? 0;
      final excused = (stats['excused'] as int?) ?? 0;
      final total = (stats['total'] as int?) ?? 0;

      final effectiveTotal = total - excused;
      final percentage = effectiveTotal > 0
          ? ((present + late * 0.5) / effectiveTotal * 100)
          : 0.0;

      final streak = await _calculateStreak(name);
      final monthly = await _buildMonthlyTrend(name);
      final projection = _calculateProjection(
        percentage,
        total,
        requiredPct,
        row['semesterStartMillis'] as int?,
        row['semesterEndMillis'] as int?,
      );

      subjects.add({
        'id': id,
        'name': name,
        'requiredPercentage': requiredPct,
        'percentage': percentage,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'total': total,
        'color': color,
        'colorHex': colorHex,
        'streak': streak,
        'monthlyTrend': monthly,
        'projection': projection,
        'semesterStartMillis': row['semesterStartMillis'],
        'semesterEndMillis': row['semesterEndMillis'],
      });
    }

    subjects.sort(
        (a, b) => (a['percentage'] as double).compareTo(b['percentage'] as double));

    final weeklyGrid = await _buildWeeklyGrid(subjects);

    if (mounted) {
      setState(() {
        _subjects = subjects;
        _weeklyGrid = weeklyGrid;
        _loading = false;
      });
    }
  }

  Future<int> _calculateStreak(String subjectName) async {
    final logs = await DatabaseHelper.instance
        .getAttendanceLogsForSubject(subjectName);
    if (logs.isEmpty) return 0;

    final sorted = logs.toList()
      ..sort((a, b) =>
          (b['dateMillis'] as int).compareTo(a['dateMillis'] as int));

    int streak = 0;
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    for (final log in sorted) {
      final status = log['status'] as String;
      final date = (log['dateMillis'] as int?) ?? 0;
      if (status == 'present' || status == 'late') {
        if (streak == 0 && date == today) {
          streak = 1;
        } else if (streak > 0) {
          final expectedDate =
              today - (streak * const Duration(days: 1).inMilliseconds);
          if (date == expectedDate) {
            streak++;
          } else {
            break;
          }
        }
      } else if (status == 'absent' &&
          date >= today - const Duration(days: 1).inMilliseconds) {
        break;
      }
    }
    return streak;
  }

  Future<List<Map<String, dynamic>>> _buildMonthlyTrend(String subjectName) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final months = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final start = month.millisecondsSinceEpoch;
      final end = nextMonth.millisecondsSinceEpoch;

      final result = await db.rawQuery("""
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
          SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late
        FROM attendance_logs
        WHERE subjectName = ? AND dateMillis >= ? AND dateMillis < ?
      """, [subjectName, start, end]);

      final row = result.first;
      final total = (row['total'] as int?) ?? 0;
      final present = (row['present'] as int?) ?? 0;
      final late = (row['late'] as int?) ?? 0;
      final effective = total > 0 ? total : 1;
      final pct = ((present + late * 0.5) / effective * 100);

      months.add({
        'month': DateFormat('MMM').format(month),
        'percentage': pct,
        'total': total,
      });
    }
    return months;
  }

  // FIXED: Guard against division by zero when required=100
  String _calculateProjection(double percentage, int total, double required,
      int? semesterStartMillis, int? semesterEndMillis) {
    if (total == 0) return 'No data yet';
    if (semesterStartMillis == null || semesterEndMillis == null) {
      return 'Set semester dates for projection';
    }

    final semesterStart =
        DateTime.fromMillisecondsSinceEpoch(semesterStartMillis);
    final semesterEnd = DateTime.fromMillisecondsSinceEpoch(semesterEndMillis);
    final totalDays = semesterEnd.difference(semesterStart).inDays;
    final elapsedDays = DateTime.now().difference(semesterStart).inDays;

    if (elapsedDays <= 0 || totalDays <= 0) return 'Semester not started';

    final projectedPct = percentage;
    final remainingDays = totalDays - elapsedDays;
    final classesPerDay = total / elapsedDays;
    final projectedTotal = total + (classesPerDay * remainingDays).round();
    final projectedPresent = (projectedTotal * (projectedPct / 100)).round();

    if (projectedPct >= required) {
      final buffer = projectedPct - required;
      return 'Projected: ${projectedPct.toStringAsFixed(1)}% (+${buffer.toStringAsFixed(1)}% buffer)';
    } else {
      // FIXED: avoid division by zero when required=100
      if (required >= 100.0) {
        return 'Projected: ${projectedPct.toStringAsFixed(1)}% — need 100% attendance, no room for misses';
      }
      final needed = ((required * projectedTotal - projectedPresent) /
              (1 - required / 100))
          .ceil();
      return 'Projected: ${projectedPct.toStringAsFixed(1)}% — need $needed more attendances';
    }
  }

    Future<List<Map<String, dynamic>>> _buildWeeklyGrid(
      List<Map<String, dynamic>> subjects) async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: _currentWeekOffset * 7));

    final grid = <Map<String, dynamic>>[];

    for (int day = 0; day < 7; day++) {
      final currentDay = weekStart.add(Duration(days: day));
      final dayStart = DateTime(currentDay.year, currentDay.month, currentDay.day)
          .millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;

      final dayLogs = await DatabaseHelper.instance.getAttendanceLogsForDate(dayStart);

      final subjectStatus = <String, String>{};
      for (final log in dayLogs) {
        final subjName = log['subjectName'] as String;
        subjectStatus[subjName] = log['status'] as String;
      }

      grid.add({
        'date': currentDay,
        'dayName': _dayNames[day],
        'isToday': now.year == currentDay.year &&
            now.month == currentDay.month &&
            now.day == currentDay.day,
        'subjectStatus': subjectStatus,
      });
    }

    return grid;
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'excused':
        return Colors.blue;
      default:
        return Colors.grey.shade300;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'present':
        return Icons.check;
      case 'absent':
        return Icons.close;
      case 'late':
        return Icons.watch_later;
      case 'excused':
        return Icons.medical_services;
      default:
        return Icons.remove;
    }
  }

  String _riskLabel(double percentage, double required) {
    if (percentage >= required + 10) return 'Safe';
    if (percentage >= required) return 'OK';
    if (percentage >= required - 10) return 'At Risk';
    return 'Critical';
  }

  Color _riskColor(double percentage, double required) {
    if (percentage >= required + 10) return Colors.green;
    if (percentage >= required) return Colors.orange;
    if (percentage >= required - 10) return Colors.deepOrange;
    return Colors.red;
  }

  void _changeWeek(int delta) {
    setState(() => _currentWeekOffset += delta);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Analytics'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Overview'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Comparison'),
            Tab(icon: Icon(Icons.grid_on), text: 'Weekly Grid'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Risk Analysis'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? _buildEmptyState(cs)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(cs),
                    _buildComparisonTab(cs),
                    _buildWeeklyGridTab(cs),
                    _buildRiskAnalysisTab(cs),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined,
              size: 80, color: cs.outline.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            'No attendance data yet!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add subjects and mark attendance to see analytics.',
            style: TextStyle(color: cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallStatsCards(cs),
          const SizedBox(height: 24),
          _buildSectionTitle('Monthly Trends', cs),
          const SizedBox(height: 12),
          ..._subjects.map((s) => _buildSubjectTrendCard(s, cs)),
          const SizedBox(height: 24),
          _buildSectionTitle('Performance Summary', cs),
          const SizedBox(height: 12),
          _buildPerformanceSummary(cs),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOverallStatsCards(ColorScheme cs) {
    final totalSubjects = _subjects.length;
    final atRisk = _subjects
        .where((s) =>
            (s['percentage'] as double) < (s['requiredPercentage'] as double))
        .length;
    final avgPercentage = _subjects.isEmpty
        ? 0.0
        : _subjects
                .map((s) => s['percentage'] as double)
                .reduce((a, b) => a + b) /
            totalSubjects;
    final totalStreak = _subjects.isEmpty
        ? 0
        : _subjects
            .map((s) => (s['streak'] as int?) ?? 0)
            .reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Avg Attendance',
            '${avgPercentage.toStringAsFixed(1)}%',
            cs.primary,
            Icons.percent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'At Risk',
            '$atRisk',
            atRisk > 0 ? Colors.red : Colors.green,
            Icons.warning_amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Best Streak',
            '$totalStreak',
            Colors.orange,
            Icons.local_fire_department,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTrendCard(Map<String, dynamic> subject, ColorScheme cs) {
    final monthly = subject['monthlyTrend'] as List<Map<String, dynamic>>;
    final color = subject['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  subject['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(subject['percentage'] as double).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _riskColor(
                      subject['percentage'] as double,
                      subject['requiredPercentage'] as double,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _TrendLinePainter(
                  data: monthly.map((m) => m['percentage'] as double).toList(),
                  color: color,
                  maxValue: 100,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: monthly.map((m) {
                return Text(
                  m['month'] as String,
                  style: TextStyle(
                    fontSize: 9,
                    color: cs.outline,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSummary(ColorScheme cs) {
    if (_subjects.isEmpty) return const SizedBox.shrink();

    final sorted = _subjects.toList()
      ..sort((a, b) =>
          (b['percentage'] as double).compareTo(a['percentage'] as double));
    final best = sorted.first;
    final worst = sorted.last;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Best Performer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${best['name']} — ${(best['percentage'] as double).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_down, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Needs Attention',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${worst['name']} — ${(worst['percentage'] as double).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Subject Comparison', cs),
          const SizedBox(height: 4),
          Text(
            'Attendance percentage across all subjects',
            style: TextStyle(fontSize: 13, color: cs.outline),
          ),
          const SizedBox(height: 16),
          ..._subjects.map((s) => _buildComparisonBar(s, cs)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 3,
                  color: cs.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dashed line = Required percentage threshold',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(Map<String, dynamic> subject, ColorScheme cs) {
    final percentage = (subject['percentage'] as double).clamp(0.0, 100.0);
    final required = (subject['requiredPercentage'] as double);
    final color = subject['color'] as Color;
    final name = subject['name'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttendanceDetailScreen(
                subjectId: (subject['id'] as int?) ?? 0,
                subjectName: name,
                subjectColor: color,
              ),
            ),
          ).then((_) => _loadData());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _riskColor(percentage, required),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage / 100,
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned(
                  left: (required / 100) *
                      (MediaQuery.of(context).size.width - 64),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyGridTab(ColorScheme cs) {
    final weekStart = _weeklyGrid.isNotEmpty
        ? _weeklyGrid.first['date'] as DateTime
        : DateTime.now();
    final weekEnd = _weeklyGrid.isNotEmpty
        ? _weeklyGrid.last['date'] as DateTime
        : DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Weekly Heatmap', cs),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () => _changeWeek(-1),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd)}',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () => _changeWeek(1),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendItem('Present', Colors.green),
              const SizedBox(width: 12),
              _buildLegendItem('Absent', Colors.red),
              const SizedBox(width: 12),
              _buildLegendItem('Late', Colors.orange),
              const SizedBox(width: 12),
              _buildLegendItem('Excused', Colors.blue),
              const SizedBox(width: 12),
              _buildLegendItem('None', Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 80),
                      ..._weeklyGrid.map((day) {
                        final isToday = day['isToday'] as bool;
                        return Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: isToday
                                ? BoxDecoration(
                                    color: cs.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    day['dayName'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isToday
                                          ? cs.primary
                                          : cs.outline,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd').format(
                                        day['date'] as DateTime),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: cs.outline,
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
                  const Divider(height: 16),
                  ..._subjects.map((subject) {
                    final name = subject['name'] as String;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: subject['color'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._weeklyGrid.map((day) {
                            final subjectStatus =
                                (day['subjectStatus'] as Map<String, String>?);
                            final status = subjectStatus?[name];
                            final statusColor = _statusColor(status);

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (status != null) {
                                  }
                                },
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: status != null
                                        ? statusColor.withOpacity(0.8)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                    border: (day['isToday'] as bool)
                                        ? Border.all(
                                            color: cs.primary, width: 1.5)
                                        : null,
                                  ),
                                  child: status != null
                                      ? Icon(
                                          _statusIcon(status),
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildWeeklySummary(cs),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildWeeklySummary(ColorScheme cs) {
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalLate = 0;
    int totalExcused = 0;

    for (final day in _weeklyGrid) {
      final statusMap = day['subjectStatus'] as Map<String, String>?;
      if (statusMap != null) {
        for (final status in statusMap.values) {
          switch (status) {
            case 'present':
              totalPresent++;
              break;
            case 'absent':
              totalAbsent++;
              break;
            case 'late':
              totalLate++;
              break;
            case 'excused':
              totalExcused++;
              break;
          }
        }
      }
    }

    final totalMarked = totalPresent + totalAbsent + totalLate;
    final weeklyRate = totalMarked > 0
        ? ((totalPresent + totalLate * 0.5) / totalMarked * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Present', totalPresent, Colors.green),
              _buildSummaryItem('Absent', totalAbsent, Colors.red),
              _buildSummaryItem('Late', totalLate, Colors.orange),
              _buildSummaryItem('Excused', totalExcused, Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          if (totalMarked > 0)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (weeklyRate / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: cs.outlineVariant.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        weeklyRate >= 75 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${weeklyRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: weeklyRate >= 75 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

    Widget _buildRiskAnalysisTab(ColorScheme cs) {
    final atRisk = _subjects
        .where((s) =>
            (s['percentage'] as double) < (s['requiredPercentage'] as double))
        .toList();
    final safe = _subjects
        .where((s) =>
            (s['percentage'] as double) >= (s['requiredPercentage'] as double))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRiskDistribution(cs),
          const SizedBox(height: 24),

          if (atRisk.isNotEmpty) ...[
            _buildSectionTitle('At Risk Subjects', cs),
            const SizedBox(height: 12),
            ...atRisk.map((s) => _buildRiskCard(s, cs, true)),
            const SizedBox(height: 24),
          ],

          if (safe.isNotEmpty) ...[
            _buildSectionTitle('Safe Subjects', cs),
            const SizedBox(height: 12),
            ...safe.map((s) => _buildRiskCard(s, cs, false)),
            const SizedBox(height: 24),
          ],

          _buildSectionTitle('Streak Leaderboard', cs),
          const SizedBox(height: 12),
          _buildStreakLeaderboard(cs),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRiskDistribution(ColorScheme cs) {
    final critical = _subjects.where((s) {
      final p = s['percentage'] as double;
      final r = s['requiredPercentage'] as double;
      return p < r - 10;
    }).length;
    final atRisk = _subjects.where((s) {
      final p = s['percentage'] as double;
      final r = s['requiredPercentage'] as double;
      return p >= r - 10 && p < r;
    }).length;
    final ok = _subjects.where((s) {
      final p = s['percentage'] as double;
      final r = s['requiredPercentage'] as double;
      return p >= r && p < r + 10;
    }).length;
    final safe = _subjects.where((s) {
      final p = s['percentage'] as double;
      final r = s['requiredPercentage'] as double;
      return p >= r + 10;
    }).length;

    final total = _subjects.length;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Distribution',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (critical > 0)
                  Expanded(
                    flex: critical,
                    child: Container(
                      height: 24,
                      color: Colors.red,
                      child: Center(
                        child: Text(
                          '$critical',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (atRisk > 0)
                  Expanded(
                    flex: atRisk,
                    child: Container(
                      height: 24,
                      color: Colors.deepOrange,
                      child: Center(
                        child: Text(
                          '$atRisk',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (ok > 0)
                  Expanded(
                    flex: ok,
                    child: Container(
                      height: 24,
                      color: Colors.orange,
                      child: Center(
                        child: Text(
                          '$ok',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (safe > 0)
                  Expanded(
                    flex: safe,
                    child: Container(
                      height: 24,
                      color: Colors.green,
                      child: Center(
                        child: Text(
                          '$safe',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRiskLegend('Critical', Colors.red),
              _buildRiskLegend('At Risk', Colors.deepOrange),
              _buildRiskLegend('OK', Colors.orange),
              _buildRiskLegend('Safe', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildRiskCard(
      Map<String, dynamic> subject, ColorScheme cs, bool isAtRisk) {
    final percentage = subject['percentage'] as double;
    final required = subject['requiredPercentage'] as double;
    final color = subject['color'] as Color;
    final name = subject['name'] as String;
    final projection = subject['projection'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isAtRisk
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttendanceDetailScreen(
                subjectId: (subject['id'] as int?) ?? 0,
                subjectName: name,
                subjectColor: color,
              ),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _riskColor(percentage, required).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _riskLabel(percentage, required),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _riskColor(percentage, required),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: cs.outlineVariant.withOpacity(0.2),
                  valueColor:
                      AlwaysStoppedAnimation(_riskColor(percentage, required)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}% / $required% required',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Streak: ${subject['streak']} days',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        projection,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakLeaderboard(ColorScheme cs) {
    final sorted = _subjects.toList()
      ..sort((a, b) => ((b['streak'] as int?) ?? 0).compareTo((a['streak'] as int?) ?? 0));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: sorted.take(5).map((subject) {
          final rank = sorted.indexOf(subject) + 1;
          final color = subject['color'] as Color;
          final name = subject['name'] as String;
          final streak = (subject['streak'] as int?) ?? 0;

          return ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber.withOpacity(0.2)
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rank == 1 ? Colors.orange : cs.outline,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(name),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;

  _TrendLinePainter({
    required this.data,
    required this.color,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final dx = size.width / (data.length - 1);

    double getY(double value) {
      return size.height - (value / maxValue) * size.height;
    }

    path.moveTo(0, getY(data[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      final x = i * dx;
      final y = getY(data[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo((data.length - 1) * dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(Offset(i * dx, getY(data[i])), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
