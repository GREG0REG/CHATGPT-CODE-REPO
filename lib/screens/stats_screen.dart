// FILE: lib/screens/stats_screen.dart
// COMPLETE REPLACEMENT — copy and paste entire file

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';
import '../theme/app_themes.dart';
import '../WIDGETS/gpa_calculator_widget.dart';

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

  // NEW: Enhanced stats
  Map<int, int> _hourlyMinutes = {};
  double _avgSessionLength = 0.0;
  int _longestSession = 0;
  int _todaySessionCount = 0;
  int _thisWeekMinutes = 0;
  int _lastWeekMinutes = 0;
  int _thisMonthMinutes = 0;
  int _lastMonthMinutes = 0;
  int _efficiencyScore = 0;
  Map<String, int> _sessionTypeBreakdown = {};
  Map<String, int> _subjectGoals = {};

  late final AnimationController _counterController;
  late final Animation<double> _counterAnimation;
  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;

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
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringController,
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

    // Load real upcoming exams
    final allEvents = await DatabaseHelper.instance.getAllEventsSorted();
    final exams = allEvents.where((e) {
      if (e.isCompleted) return false;
      if (e.subjectTag == null || e.subjectTag!.trim().isEmpty) return false;
      return e.finalMillis > now.millisecondsSinceEpoch;
    }).toList();
    exams.sort((a, b) => a.finalMillis.compareTo(b.finalMillis));
    final upcomingExams = exams.take(5).toList();

    // NEW: Enhanced stats queries
    final hourlyMinutes = await DatabaseHelper.instance.getSessionsByHour();
    final avgDuration = await DatabaseHelper.instance.getAverageSessionDuration();
    final longestSession = await DatabaseHelper.instance.getLongestSession();
    final todaySessionCount = await DatabaseHelper.instance.getTodaySessionCount();
    final sessionTypes = await DatabaseHelper.instance.getSessionTypeBreakdown();

    // Weekly comparison
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStartMillis = DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day).millisecondsSinceEpoch;
    final lastWeekStartMillis = thisWeekStartMillis - const Duration(days: 7).inMilliseconds;
    final thisWeekMin = await DatabaseHelper.instance.getWeeklyMinutes(thisWeekStartMillis);
    final lastWeekMin = await DatabaseHelper.instance.getWeeklyMinutes(lastWeekStartMillis);

    // Monthly comparison
    final thisMonthMin = await DatabaseHelper.instance.getMonthlyMinutes(now.year, now.month);
    final lastMonthMin = now.month == 1
        ? await DatabaseHelper.instance.getMonthlyMinutes(now.year - 1, 12)
        : await DatabaseHelper.instance.getMonthlyMinutes(now.year, now.month - 1);

    // Efficiency score
    final efficiency = await DatabaseHelper.instance.getStudyEfficiencyScore();

    // Subject goals (default 120 min per subject per week)
    final subjectGoals = <String, int>{};
    for (final entry in _subjectMinutes.entries) {
      subjectGoals[entry.key] = 120; // Default weekly goal
    }

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

      // NEW: Enhanced stats
      _hourlyMinutes = hourlyMinutes;
      _avgSessionLength = avgDuration;
      _longestSession = longestSession;
      _todaySessionCount = todaySessionCount;
      _thisWeekMinutes = thisWeekMin;
      _lastWeekMinutes = lastWeekMin;
      _thisMonthMinutes = thisMonthMin;
      _lastMonthMinutes = lastMonthMin;
      _efficiencyScore = efficiency;
      _sessionTypeBreakdown = sessionTypes;
      _subjectGoals = subjectGoals;

      _loading = false;
    });

    _counterController.forward(from: 0);
    _ringController.forward(from: 0);
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
      Colors.cyan,
      Colors.lime,
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

  // NEW: Get best time of day
  int? get _bestHour {
    if (_hourlyMinutes.isEmpty) return null;
    int bestHour = 0;
    int maxMinutes = 0;
    _hourlyMinutes.forEach((hour, minutes) {
      if (minutes > maxMinutes) {
        maxMinutes = minutes;
        bestHour = hour;
      }
    });
    return maxMinutes > 0 ? bestHour : null;
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour $period';
  }

  // NEW: Weekly change percentage
  double get _weekChangePercent {
    if (_lastWeekMinutes == 0) return _thisWeekMinutes > 0 ? 100.0 : 0.0;
    return ((_thisWeekMinutes - _lastWeekMinutes) / _lastWeekMinutes * 100);
  }

  // NEW: Monthly change percentage
  double get _monthChangePercent {
    if (_lastMonthMinutes == 0) return _thisMonthMinutes > 0 ? 100.0 : 0.0;
    return ((_thisMonthMinutes - _lastMonthMinutes) / _lastMonthMinutes * 100);
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

                  // NEW: Efficiency Score Card
                  _buildEfficiencyCard(cs),
                  const SizedBox(height: 24),

                  // Summary Stats Row
                  _buildSummaryRow(cs),
                  const SizedBox(height: 24),

                  // NEW: Best Time of Day & Average Session
                  _buildInsightsRow(cs),
                  const SizedBox(height: 24),

                  // NEW: Weekly vs Monthly Comparison
                  _buildComparisonSection(cs),
                  const SizedBox(height: 24),

                  // GPA Calculator Widget
                  const GPACalculatorWidget(),
                  const SizedBox(height: 24),

                  // Weekly Focus Trend
                  _buildSectionTitle('Weekly Focus Trend'),
                  const SizedBox(height: 12),
                  _buildTrendChart(cs),
                  const SizedBox(height: 24),

                  // NEW: Session Type Breakdown
                  if (_sessionTypeBreakdown.isNotEmpty) ...[
                    _buildSectionTitle('Session Types'),
                    const SizedBox(height: 12),
                    _buildSessionTypeChart(cs),
                    const SizedBox(height: 24),
                  ],

                  // NEW: Subject Progress Rings
                  if (_subjectMinutes.isNotEmpty) ...[
                    _buildSectionTitle('Subject Progress'),
                    const SizedBox(height: 12),
                    _buildSubjectProgressRings(cs),
                    const SizedBox(height: 24),
                  ],

                  // Subject Breakdown
                  if (_subjectMinutes.isNotEmpty) ...[
                    _buildSectionTitle('Minutes by Subject'),
                    const SizedBox(height: 12),
                    _buildSubjectChart(cs),
                    const SizedBox(height: 24),
                  ],

                  // NEW: Best Time Heatmap
                  if (_hourlyMinutes.isNotEmpty) ...[
                    _buildSectionTitle('Productivity by Hour'),
                    const SizedBox(height: 12),
                    _buildHourlyHeatmap(cs),
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

  // NEW: Efficiency Score Card
  Widget _buildEfficiencyCard(ColorScheme cs) {
    final score = _efficiencyScore;
    final Color scoreColor = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.12),
            cs.primary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: _ringAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: (score / 100) * _ringAnimation.value,
                    color: scoreColor,
                    backgroundColor: cs.surfaceContainerHighest,
                    strokeWidth: 8,
                  ),
                  child: Center(
                    child: Text(
                      '${(score * _ringAnimation.value).round()}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Efficiency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 80
                      ? 'Excellent! You\'re in the zone.'
                      : score >= 60
                          ? 'Good progress. Keep it consistent.'
                          : 'Let\'s build a more regular study habit.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _EfficiencyBadge(
                      label: 'Duration',
                      active: _avgSessionLength >= 20 && _avgSessionLength <= 50,
                      color: cs,
                    ),
                    const SizedBox(width: 8),
                    _EfficiencyBadge(
                      label: 'Consistency',
                      active: _latestStreak >= 3,
                      color: cs,
                    ),
                    const SizedBox(width: 8),
                    _EfficiencyBadge(
                      label: 'Volume',
                      active: _totalSessions >= 10,
                      color: cs,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  // NEW: Insights Row - Best Time & Avg Session
  Widget _buildInsightsRow(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.withOpacity(0.12),
                  Colors.purple.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule, color: Colors.purple, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  _bestHour != null ? _formatHour(_bestHour!) : '--',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Best Time',
                  style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _bestHour != null ? 'Peak productivity hour' : 'No data yet',
                  style: TextStyle(fontSize: 10, color: cs.outline.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.withOpacity(0.12),
                  Colors.teal.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timelapse, color: Colors.teal, size: 20),
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _counterAnimation,
                  builder: (context, child) {
                    final displayValue = (_avgSessionLength * _counterAnimation.value).round();
                    return Text(
                      '$displayValue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    );
                  },
                ),
                Text(
                  'min avg',
                  style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Session length',
                  style: TextStyle(fontSize: 10, color: cs.outline.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.indigo.withOpacity(0.12),
                  Colors.indigo.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.format_list_numbered, color: Colors.indigo, size: 20),
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _counterAnimation,
                  builder: (context, child) {
                    final displayValue = (_todaySessionCount * _counterAnimation.value).round();
                    return Text(
                      '$displayValue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    );
                  },
                ),
                Text(
                  'sessions',
                  style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Today\'s count',
                  style: TextStyle(fontSize: 10, color: cs.outline.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEW: Weekly & Monthly Comparison
  Widget _buildComparisonSection(ColorScheme cs) {
    final weekChange = _weekChangePercent;
    final monthChange = _monthChangePercent;
    final weekColor = weekChange >= 0 ? Colors.green : Colors.red;
    final monthColor = monthChange >= 0 ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Performance Comparison',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ComparisonItem(
                  label: 'This Week',
                  value: '${(_thisWeekMinutes / 60).toStringAsFixed(1)}h',
                  change: weekChange,
                  changeColor: weekColor,
                  previousLabel: 'Last week: ${(_lastWeekMinutes / 60).toStringAsFixed(1)}h',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: cs.outlineVariant.withOpacity(0.3),
              ),
              Expanded(
                child: _ComparisonItem(
                  label: 'This Month',
                  value: '${(_thisMonthMinutes / 60).toStringAsFixed(1)}h',
                  change: monthChange,
                  changeColor: monthColor,
                  previousLabel: 'Last month: ${(_lastMonthMinutes / 60).toStringAsFixed(1)}h',
                ),
              ),
            ],
          ),
          if (_longestSession > 0) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Longest session: $_longestSession minutes',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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

  // NEW: Session Type Breakdown (Pie Chart)
  Widget _buildSessionTypeChart(ColorScheme cs) {
    final entries = _sessionTypeBreakdown.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);
    if (total == 0) return const SizedBox.shrink();

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: List.generate(
                  entries.length,
                  (i) {
                    final percentage = (entries[i].value / total * 100);
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: entries[i].value.toDouble(),
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((entry) {
                final i = entry.key;
                final type = entry.value.key;
                final count = entry.value.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Subject Progress Rings
  Widget _buildSubjectProgressRings(ColorScheme cs) {
    final entries = _subjectMinutes.entries.toList();
    
    return Container(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final subject = entries[index].key;
          final minutes = entries[index].value;
          final goal = _subjectGoals[subject] ?? 120;
          final progress = (minutes / goal).clamp(0.0, 1.0);
          final color = _subjectColor(index, cs.brightness);

          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: AnimatedBuilder(
                    animation: _ringAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _RingPainter(
                          progress: progress * _ringAnimation.value,
                          color: color,
                          backgroundColor: cs.surfaceContainerHighest,
                          strokeWidth: 6,
                        ),
                        child: Center(
                          child: Text(
                            '${(progress * 100 * _ringAnimation.value).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subject.length > 8 ? '${subject.substring(0, 8)}..' : subject,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$min / $goal min',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // NEW: Hourly Heatmap
  Widget _buildHourlyHeatmap(ColorScheme cs) {
    final maxMinutes = _hourlyMinutes.values.isEmpty 
        ? 1 
        : _hourlyMinutes.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Morning',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
              Text(
                'Afternoon',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
              Text(
                'Evening',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
              Text(
                'Night',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: List.generate(24, (hour) {
                final minutes = _hourlyMinutes[hour] ?? 0;
                final intensity = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
                final isBest = _bestHour == hour;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: minutes > 0
                          ? cs.primary.withOpacity(0.1 + (intensity * 0.9))
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                      border: isBest
                          ? Border.all(color: Colors.amber, width: 2)
                          : null,
                    ),
                    child: Tooltip(
                      message: '${_formatHour(hour)}: $minutes min',
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Best hour',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ],
          ),
        ],
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
    _ringController.dispose();
    super.dispose();
  }
}

// NEW: Ring Painter for circular progress
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// NEW: Efficiency Badge
class _EfficiencyBadge extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme color;

  const _EfficiencyBadge({
    required this.label,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.15)
            : color.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? Colors.green.withOpacity(0.3)
              : color.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: active ? Colors.green.shade700 : color.outline,
        ),
      ),
    );
  }
}

// NEW: Comparison Item
class _ComparisonItem extends StatelessWidget {
  final String label;
  final String value;
  final double change;
  final Color changeColor;
  final String previousLabel;

  const _ComparisonItem({
    required this.label,
    required this.value,
    required this.change,
    required this.changeColor,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = change >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: changeColor,
              ),
              const SizedBox(width: 2),
              Text(
                '${change.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: changeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            previousLabel,
            style: TextStyle(
              fontSize: 10,
              color: cs.outline.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
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
