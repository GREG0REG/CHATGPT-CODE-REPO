// FILE: lib/screens/stats_screen.dart
// COMPLETE REPLACEMENT — copy and paste entire file

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';
import '../theme/app_themes.dart';
import '../WIDGET/gpa_calculator_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  List<StudySession> _sessions = [];
  List<Event> _upcomingExams = [];
  int _todayMinutes = 0;
  int _latestStreak = 0;
  int _totalSessions = 0;
  int _totalHours = 0;
  String? _favoriteSubject;

  final Map<String, int> _subjectMinutes = {};
  final List<int> _dailyMinutes = List.filled(7, 0);

  late final AnimationController _counterController;
  late final Animation<double> _counterAnimation;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _counterAnimation = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    final startOfWeek = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);

    // Load study sessions
    final sessions = await DatabaseHelper.instance
        .getStudySessionsForDateRange(startOfWeek.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final todayMin = await DatabaseHelper.instance.getTodayStudyMinutes();
    final streak = await DatabaseHelper.instance.getLatestStreak();

    // Load real upcoming exams (events with subjectTag and future deadline)
    final allEvents = await DatabaseHelper.instance.getAllEventsSorted();
    final exams = allEvents.where((e) {
      if (e.isCompleted) return false;
      if (e.subjectTag == null || e.subjectTag!.trim().isEmpty) return false;
      return e.finalMillis > now.millisecondsSinceEpoch;
    }).toList();
    exams.sort((a, b) => a.finalMillis.compareTo(b.finalMillis));
    // Take top 5 upcoming exams
    final upcomingExams = exams.take(5).toList();

    final subjectMap = <String, int>{};
    final daily = List<int>.filled(7, 0);
    int totalMin = 0;

    for (final s in sessions) {
      totalMin += s.durationMinutes;
      subjectMap[s.subjectTag ?? 'General'] =
          (subjectMap[s.subjectTag ?? 'General'] ?? 0) + s.durationMinutes;

      final dt = DateTime.fromMillisecondsSinceEpoch(s.completedAtMillis);
      final dayIndex = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        daily[6 - dayIndex] += s.durationMinutes;
      }
    }

    String? fav;
    int maxMin = 0;
    subjectMap.forEach((sub, min) {
      if (min > maxMin) {
        maxMin = min;
        fav = sub;
      }
    });

    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _upcomingExams = upcomingExams;
      _todayMinutes = todayMin;
      _latestStreak = streak;
      _totalSessions = sessions.length;
      _totalHours = totalMin ~/ 60;
      _favoriteSubject = fav;
      _subjectMinutes.addAll(subjectMap);
      _dailyMinutes.setAll(0, daily);
      _loading = false;
    });

    _counterController.forward(from: 0);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadData();
  }

  Color _subjectColor(int index, Brightness brightness) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.red,
    ];
    return colors[index % colors.length];
  }

  String _dayLabel(int daysAgo) {
    final dt = DateTime.now().subtract(Duration(days: daysAgo));
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[dt.weekday % 7];
  }

  String _formatCountdown(Event event) {
    final now = DateTime.now();
    final diff = Duration(milliseconds: event.finalMillis - now.millisecondsSinceEpoch);
    if (diff.inDays > 0) return '${diff.inDays} days';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }

  Color _examUrgencyColor(Event event) {
    final now = DateTime.now();
    final diff = Duration(milliseconds: event.finalMillis - now.millisecondsSinceEpoch);
    if (diff.inDays < 1) return Colors.red;
    if (diff.inDays < 3) return Colors.deepOrange;
    if (diff.inDays < 7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Upcoming Exams Section
                  if (_upcomingExams.isNotEmpty) ...[
                    _buildSectionTitle('Upcoming Exams'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _upcomingExams.length,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemBuilder: (context, index) {
                          final exam = _upcomingExams[index];
                          final urgencyColor = _examUrgencyColor(exam);
                          final countdown = _formatCountdown(exam);
                          final date = DateTime.fromMillisecondsSinceEpoch(exam.finalMillis);

                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  urgencyColor.withOpacity(0.15),
                                  urgencyColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: urgencyColor.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: urgencyColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        countdown,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: urgencyColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.alarm,
                                      size: 16,
                                      color: urgencyColor.withOpacity(0.6),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  exam.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  exam.subjectTag ?? 'General',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${date.month}/${date.day}/${date.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.outline.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    // Empty exam state
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.event_note, color: cs.onPrimaryContainer, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No upcoming exams',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Add events with subject tags to track exams here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Summary Stats Row
                  _buildSummaryRow(cs),
                  const SizedBox(height: 24),

                  // GPA Calculator Widget
                  const GPACalculatorWidget(),
                  const SizedBox(height: 24),

                  // Weekly Focus Trend
                  _buildSectionTitle('Weekly Focus Trend'),
                  const SizedBox(height: 12),
                  _buildTrendChart(cs),
                  const SizedBox(height: 24),

                  // Subject Breakdown
                  if (_subjectMinutes.isNotEmpty) ...[
                    _buildSectionTitle('Minutes by Subject'),
                    const SizedBox(height: 12),
                    _buildSubjectChart(cs),
                    const SizedBox(height: 24),
                  ],

                  // Streak Card
                  _buildStreakCard(cs),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSummaryRow(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.timer,
            label: 'Today',
            value: _todayMinutes,
            unit: 'min',
            color: cs.primary,
            animation: _counterAnimation,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.local_fire_department,
            label: 'Streak',
            value: _latestStreak,
            unit: 'days',
            color: Colors.orange,
            animation: _counterAnimation,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.hourglass_bottom,
            label: 'Total',
            value: _totalHours,
            unit: 'hrs',
            color: Colors.green,
            animation: _counterAnimation,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(ColorScheme cs) {
    final maxY = _dailyMinutes.reduce((a, b) => a > b ? a : b).toDouble();
    final safeMaxY = maxY < 10 ? 60.0 : maxY * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: safeMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMaxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: cs.outlineVariant.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx > 6) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _dayLabel(6 - idx),
                      style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                7,
                (i) => FlSpot(i.toDouble(), _dailyMinutes[i].toDouble()),
              ),
              isCurved: true,
              curveSmoothness: 0.35,
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.3)],
              ),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: cs.primary,
                    strokeWidth: 2,
                    strokeColor: cs.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.2),
                    cs.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectChart(ColorScheme cs) {
    final entries = _subjectMinutes.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    final safeMax = maxVal < 10 ? 60.0 : maxVal * 1.1;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: BarChart(
        BarChartData(
          maxY: safeMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMax / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: cs.outlineVariant.withOpacity(0.2),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entries[idx].key.length > 5
                          ? '${entries[idx].key.substring(0, 5)}..'
                          : entries[idx].key,
                      style: TextStyle(fontSize: 10, color: cs.outline, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(
            entries.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  gradient: LinearGradient(
                    colors: [
                      _subjectColor(i, Theme.of(context).brightness),
                      _subjectColor(i, Theme.of(context).brightness).withOpacity(0.5),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 24,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: safeMax,
                    color: cs.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.12),
            Colors.deepOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_latestStreak day streak',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _favoriteSubject != null
                      ? 'Favorite subject: $_favoriteSubject'
                      : 'Keep studying to build your streak!',
                  style: TextStyle(fontSize: 13, color: cs.outline),
                ),
              ],
            ),
          ),
          if (_latestStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'On Fire',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _counterController.dispose();
    super.dispose();
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String unit;
  final Color color;
  final Animation<double> animation;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final displayValue = (value * animation.value).round();
              return Text(
                '$displayValue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              );
            },
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
