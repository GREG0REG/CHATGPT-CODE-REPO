import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import '../models/study_session.dart';
import '../theme/app_themes.dart';
import '../main.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Survives IndexedStack switches

  bool _loading = true;
  List<StudySession> _sessions = [];
  int _todayMinutes = 0;
  int _latestStreak = 0;
  int _totalSessions = 0;
  int _totalHours = 0;
  String? _favoriteSubject;

  // 7-day buckets
  final Map<String, int> _subjectMinutes = {};
  final List<int> _dailyMinutes = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    final startOfWeek = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);

    final sessions = await DatabaseHelper.instance
        .getStudySessionsForDateRange(startOfWeek.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final todayMin = await DatabaseHelper.instance.getTodayStudyMinutes();
    final streak = await DatabaseHelper.instance.getLatestStreak();

    // Build buckets
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
      _todayMinutes = todayMin;
      _latestStreak = streak;
      _totalSessions = sessions.length;
      _totalHours = totalMin ~/ 60;
      _favoriteSubject = fav;
      _subjectMinutes.addAll(subjectMap);
      _dailyMinutes.setAll(0, daily);
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
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
                  // Summary cards
                  _buildSummaryRow(cs),
                  const SizedBox(height: 24),

                  // Weekly trend line chart
                  _buildSectionTitle('Weekly Focus Trend'),
                  const SizedBox(height: 8),
                  _buildTrendChart(cs),
                  const SizedBox(height: 24),

                  // Subject breakdown bar chart
                  if (_subjectMinutes.isNotEmpty) ...[
                    _buildSectionTitle('Minutes by Subject'),
                    const SizedBox(height: 8),
                    _buildSubjectChart(cs),
                    const SizedBox(height: 24),
                  ],

                  // Streak card
                  _buildStreakCard(cs),
                  const SizedBox(height: 24),
                ],
              ),
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
            value: '$_todayMinutes',
            unit: 'min',
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.local_fire_department,
            label: 'Streak',
            value: '$_latestStreak',
            unit: 'days',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.hourglass_bottom,
            label: 'Total',
            value: '$_totalHours',
            unit: 'hrs',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTrendChart(ColorScheme cs) {
    final maxY = _dailyMinutes.reduce((a, b) => a > b ? a : b).toDouble();
    final safeMaxY = maxY < 10 ? 60.0 : maxY * 1.2;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: safeMaxY,
          gridData: const FlGridData(show: false),
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
                      style: TextStyle(fontSize: 11, color: cs.outline),
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
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.3)],
              ),
              barWidth: 3,
              dotData: const FlDotData(show: false),
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

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: safeMax,
          gridData: const FlGridData(show: false),
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
                      entries[idx].key.length > 6
                          ? '${entries[idx].key.substring(0, 6)}..'
                          : entries[idx].key,
                      style: TextStyle(fontSize: 10, color: cs.outline),
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
                      _subjectColor(i, Theme.of(context).brightness).withOpacity(0.6),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department, color: Colors.orange),
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
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              unit,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
