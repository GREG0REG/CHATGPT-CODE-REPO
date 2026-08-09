import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import '../models/study_plan.dart';
import '../models/study_plan_item.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subject.dart';
import '../models/syllabus_unit.dart';
import '../models/study_session.dart';


class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen>
    with SingleTickerProviderStateMixin {
  List<StudyPlan> _plans = [];
  List<StudyPlanItem> _todayItems = [];
  List<StudyPlanItem> _weekItems = [];
  StudyPlan? _activePlan;
  bool _loading = true;
  late TabController _tabController;
  int _selectedDayOffset = 0;

  // Study timer state
  bool _timerRunning = false;
  int _timerSeconds = 0;
  StudyPlanItem? _activeTimerItem;
  Timer? _timer;

  // Motivational quotes for NEET
  final List<String> _quotes = [
    'success is the sum of small efforts repeated day in and day out.',
    'the future belongs to those who believe in the beauty of their dreams.',
    'do not wait for opportunity. create it.',
    'your only limit is your mind.',
    'dream big, study hard, achieve more.',
    'every expert was once a beginner.',
    'discipline is the bridge between goals and accomplishment.',
    'small steps every day lead to giant leaps over time.',
    'consistency beats intensity.',
    'focus on progress, not perfection.',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final plans = await db.getAllStudyPlans();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;
    final weekStart = todayStart;
    final weekEnd = weekStart + const Duration(days: 7).inMilliseconds;

    StudyPlan? active;
    for (final p in plans) {
      if (p.active) {
        active = p;
        break;
      }
    }
    if (active == null && plans.isNotEmpty) {
      active = plans.first;
    }

    List<StudyPlanItem> todayItems = [];
    List<StudyPlanItem> weekItems = [];
    if (active != null) {
      todayItems = await db.getStudyPlanItemsForPlanInDateRange(
        active.id!, todayStart, todayEnd,
      );
      weekItems = await db.getStudyPlanItemsForPlanInDateRange(
        active.id!, weekStart, weekEnd,
      );
    }

    setState(() {
      _plans = plans;
      _activePlan = active;
      _todayItems = todayItems;
      _weekItems = weekItems;
      _loading = false;
    });
  }

  Future<void> _switchPlan(StudyPlan plan) async {
    final db = DatabaseHelper.instance;
    for (final p in _plans) {
      if (p.id != plan.id && p.active) {
        await db.updateStudyPlan(p.copyWith(isActive: 0));
      }
    }
    if (!plan.active) {
      await db.updateStudyPlan(plan.copyWith(isActive: 1));
    }
    await _loadData();
  }

  Future<void> _deletePlan(StudyPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('delete plan?'),
        content: Text('"${plan.name}" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteStudyPlan(plan.id!);
    await _loadData();
  }

  Future<void> _createNewPlan() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PlanGeneratorSheet(),
    );
    await _loadData();
  }

  // Study Timer
  void _startTimer(StudyPlanItem item) {
    setState(() {
      _timerRunning = true;
      _timerSeconds = 0;
      _activeTimerItem = item;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _timerSeconds++);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _stopTimer() async {
    _timer?.cancel();
    if (_activeTimerItem != null && _timerSeconds > 60) {
      // Save study session
      final minutes = _timerSeconds ~/ 60;
            await DatabaseHelper.instance.insertStudySession(StudySession(
        topicId: _activeTimerItem!.topicId,
        planItemId: _activeTimerItem!.id,
        startTimeMillis: DateTime.now().subtract(Duration(seconds: _timerSeconds)).millisecondsSinceEpoch,
        endTimeMillis: DateTime.now().millisecondsSinceEpoch,
        durationMinutes: minutes,
        productivity: 7,
      ));
    }
    setState(() {
      _timerRunning = false;
      _timerSeconds = 0;
      _activeTimerItem = null;
    });
  }

  String _formatTimer(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<double> _calculateProgress(StudyPlan plan) async {
    final items = await DatabaseHelper.instance.getStudyPlanItemsForPlan(plan.id!);
    if (items.isEmpty) return 0.0;
    final completed = items.where((i) => i.completed).length;
    return completed / items.length;
  }

  Map<int, double> _getWeeklyProgress() {
    final result = <int, double>{};
    for (int i = 0; i < 7; i++) result[i] = 0.0;
    if (_activePlan == null || _weekItems.isEmpty) return result;
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day);
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      final dayStart = weekStart.add(Duration(days: dayIndex)).millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
      final dayItems = _weekItems.where((item) =>
        item.scheduledDateMillis >= dayStart && item.scheduledDateMillis < dayEnd
      ).toList();
      if (dayItems.isNotEmpty) {
        final completed = dayItems.where((i) => i.completed).length;
        result[dayIndex] = completed / dayItems.length;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> _getPlanStats() async {
    if (_activePlan == null) return {};
    final db = DatabaseHelper.instance;
    final allItems = await db.getStudyPlanItemsForPlan(_activePlan!.id!);
    final completed = allItems.where((i) => i.completed).length;
    final remaining = allItems.length - completed;
    final daysLeft = (_activePlan!.endDateMillis - DateTime.now().millisecondsSinceEpoch) ~/ 86400000;
    SyllabusSubject? subject;
    if (_activePlan!.subjectId != null) {
      subject = await db.getSyllabusSubject(_activePlan!.subjectId!);
    }
    final totalDays = (_activePlan!.endDateMillis - _activePlan!.startDateMillis) ~/ 86400000;
    final elapsedDays = totalDays - daysLeft;
    final expectedProgress = totalDays > 0 ? elapsedDays / totalDays : 0.0;
    final actualProgress = allItems.isNotEmpty ? completed / allItems.length : 0.0;
    final paceDiff = actualProgress - expectedProgress;
    String paceStatus;
    Color paceColor;
    if (paceDiff > 0.1) {
      paceStatus = 'ahead of schedule';
      paceColor = Colors.green;
    } else if (paceDiff > -0.1) {
      paceStatus = 'on track';
      paceColor = Colors.green;
    } else if (paceDiff > -0.3) {
      paceStatus = 'slightly behind';
      paceColor = Colors.orange;
    } else {
      paceStatus = 'behind schedule';
      paceColor = Colors.red;
    }
    // Get session stats
    final sessionStats = await db.getStudySessionStats(_activePlan!.id!);
    final weeklyStats = await db.getWeeklyStudyStats(_activePlan!.id!);
    return {
      'totalItems': allItems.length,
      'completed': completed,
      'remaining': remaining,
      'daysLeft': daysLeft,
      'subject': subject,
      'paceStatus': paceStatus,
      'paceColor': paceColor,
      'paceDiff': paceDiff,
      'totalSessions': sessionStats['totalSessions'],
      'totalMinutes': sessionStats['totalMinutes'],
      'avgProductivity': sessionStats['avgProductivity'],
      'sessionsThisWeek': weeklyStats['sessionsThisWeek'],
      'minutesThisWeek': weeklyStats['minutesThisWeek'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('study planner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'dashboard'),
            Tab(text: 'weekly view'),
            Tab(text: 'analytics'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(cs),
                _buildWeeklyTab(cs),
                _buildAnalyticsTab(cs),
              ],
            ),
    );
  }

  Widget _buildDashboardTab(ColorScheme cs) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getPlanStats(),
      builder: (ctx, statsSnap) {
        final stats = statsSnap.data ?? {};
        final daysLeft = (stats['daysLeft'] as int?) ?? 0;
        final remaining = (stats['remaining'] as int?) ?? 0;
        final totalItems = (stats['totalItems'] as int?) ?? 0;
        final completed = (stats['completed'] as int?) ?? 0;
        final paceStatus = (stats['paceStatus'] as String?) ?? 'no plan';
        final paceColor = (stats['paceColor'] as Color?) ?? Colors.grey;
        final subject = stats['subject'] as SyllabusSubject?;
        final sessionsThisWeek = (stats['sessionsThisWeek'] as int?) ?? 0;
        final minutesThisWeek = (stats['minutesThisWeek'] as int?) ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_plans.isNotEmpty) _buildPlanSelector(cs),
              const SizedBox(height: 16),
              _buildQuoteCard(cs),
              const SizedBox(height: 20),
              if (_activePlan != null) ...[
                // Study Timer Card (NEW)
                _buildTimerCard(cs),
                const SizedBox(height: 20),
                _buildTodayCard(cs, daysLeft, completed, totalItems),
                const SizedBox(height: 20),
                _buildWeeklyChart(cs),
                const SizedBox(height: 20),
                _buildStatsGrid(cs, daysLeft, remaining, totalItems, paceStatus, paceColor, sessionsThisWeek, minutesThisWeek),
                const SizedBox(height: 20),
                if (subject != null) _buildSubjectBreakdown(cs, subject),
              ] else ...[
                _buildNoPlanCard(cs),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _createNewPlan,
                icon: const Icon(Icons.add),
                label: const Text('create new plan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // NEW: Study Timer Card
  Widget _buildTimerCard(ColorScheme cs) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _timerRunning ? Colors.red.withOpacity(0.15) : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _timerRunning ? Icons.timer : Icons.timer_outlined,
                    color: _timerRunning ? Colors.red : cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _timerRunning ? 'focus mode active' : 'study timer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_activeTimerItem != null)
                        Text(
                          _timerRunning ? 'studying: topic ${_activeTimerItem!.topicId}' : 'ready to focus',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _formatTimer(_timerSeconds),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _timerRunning ? Colors.red : cs.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_timerRunning && _activeTimerItem == null)
              // Show today's tasks to start timer
              if (_todayItems.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('tap a task to start focus timer:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ..._todayItems.take(3).map((item) => FutureBuilder<SyllabusTopic?>(
                      future: item.topicId != null
                          ? DatabaseHelper.instance.getSyllabusTopic(item.topicId!)
                          : Future.value(null),
                      builder: (ctx, snap) {
                        final topicName = snap.data?.name ?? 'topic ${item.topicId}';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.play_circle_outline, color: Colors.green),
                          title: Text(topicName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('${item.allocatedMinutes} min allocated', style: const TextStyle(fontSize: 12)),
                          onTap: () => _startTimer(item),
                        );
                      },
                    )),
                  ],
                )
              else
                Center(
                  child: Text(
                    'no tasks for today. add topics to your plan!',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_timerRunning)
                    FilledButton.tonal(
                      onPressed: _pauseTimer,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.pause), SizedBox(width: 4), Text('pause')],
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: () => _startTimer(_activeTimerItem!),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.play_arrow), SizedBox(width: 4), Text('resume')],
                      ),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _stopTimer,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.stop), SizedBox(width: 4), Text('finish')],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelector(ColorScheme cs) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.folder_open, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<StudyPlan>(
                  isExpanded: true,
                  value: _activePlan,
                  hint: const Text('select a plan'),
                  items: _plans.map((plan) {
                    return DropdownMenuItem(
                      value: plan,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(plan.name, overflow: TextOverflow.ellipsis),
                          ),
                          if (plan.active)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('active', style: TextStyle(fontSize: 10, color: Colors.green)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (plan) {
                    if (plan != null) _switchPlan(plan);
                  },
                ),
              ),
            ),
            // FIX: Always show delete button, not just when plans.length > 1
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _activePlan != null ? () => _deletePlan(_activePlan!) : null,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(ColorScheme cs) {
    final quote = _quotes[DateTime.now().day % _quotes.length];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primaryContainer.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: cs.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(ColorScheme cs, int daysLeft, int completed, int totalItems) {
    final progress = totalItems > 0 ? completed / totalItems : 0.0;
    final todayTasks = _todayItems;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.today, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (todayTasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.beach_access, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'no tasks scheduled for today. enjoy your break or add some!',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...todayTasks.map((item) => _buildTaskTile(item, cs)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('progress: ${(progress * 100).round()}%', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    color: daysLeft < 7 ? Colors.red : cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: daysLeft < 7 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(ColorScheme cs) {
    final weeklyData = _getWeeklyProgress();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('weekly progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          height: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
          ),
          child: BarChart(
            BarChartData(
              maxY: 1.0,
              barGroups: List.generate(7, (index) {
                final value = weeklyData[index] ?? 0.0;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: value >= 0.8 ? Colors.green : value >= 0.5 ? Colors.orange : value > 0 ? Colors.red : cs.surfaceContainerHighest,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
                      final now = DateTime.now();
                      final dayIndex = (now.weekday - 1 + value.toInt()) % 7;
                      final isToday = value.toInt() == 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          days[dayIndex],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ColorScheme cs, int daysLeft, int remaining, int totalItems, String paceStatus, Color paceColor, int sessionsThisWeek, int minutesThisWeek) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard('days left', '$daysLeft', 'until exam', cs, accentColor: daysLeft < 7 ? Colors.red : null),
            const SizedBox(width: 12),
            _buildStatCard('topics remaining', '$remaining', 'out of $totalItems total', cs),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('buffer days', '${_activePlan?.bufferDays ?? 7}', 'reserved for revision', cs, accentColor: Colors.green),
            const SizedBox(width: 12),
            _buildStatCard('daily target', '${_activePlan?.dailyStudyMinutes ?? 120}m', 'per day', cs, accentColor: Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        // NEW: Study session stats
        Row(
          children: [
            _buildStatCard('sessions', '$sessionsThisWeek', 'this week', cs, accentColor: Colors.purple),
            const SizedBox(width: 12),
            _buildStatCard('study time', '${(minutesThisWeek / 60).toStringAsFixed(1)}h', 'this week', cs, accentColor: Colors.teal),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: paceColor.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: paceColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: paceColor, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('pace status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(paceStatus, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: paceColor)),
                    ],
                  ),
                ),
                Icon(Icons.trending_up, color: paceColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectBreakdown(ColorScheme cs, SyllabusSubject subject) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getSyllabusProgressForSubject(subject.id!),
      builder: (ctx, snap) {
        final data = snap.data ?? {'total': 0, 'completed': 0};
        final total = data['total'] as int;
        final completed = data['completed'] as int;
        final progress = total > 0 ? completed / total : 0.0;
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: subject.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$completed/$total topics completed (${(progress * 100).round()}%)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoPlanCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 56, color: cs.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('no study plan yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('create a plan to organize your neet prep and track your progress', style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTab(ColorScheme cs) {
    if (_activePlan == null) return _buildNoPlanCard(cs);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (ctx, index) {
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: index));
        final dayStart = day.millisecondsSinceEpoch;
        final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
        final dayItems = _weekItems.where((item) => item.scheduledDateMillis >= dayStart && item.scheduledDateMillis < dayEnd).toList();
        final isToday = index == 0;
        final dayName = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][day.weekday - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isToday ? 2 : 0,
          color: isToday ? cs.primaryContainer.withOpacity(0.2) : cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isToday ? cs.primary.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.3), width: isToday ? 1.5 : 1),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isToday ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? cs.onPrimary : cs.onSurface)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayName, style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
                      Text('${dayItems.where((i) => i.completed).length}/${dayItems.length} done', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('today', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            children: [
              if (dayItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('no tasks scheduled', style: TextStyle(color: cs.onSurfaceVariant)),
                )
              else
                ...dayItems.map((item) => _buildTaskTile(item, cs)),
            ],
          ),
        );
      },
    );
  }

  // NEW: Analytics Tab
  Widget _buildAnalyticsTab(ColorScheme cs) {
    if (_activePlan == null) return _buildNoPlanCard(cs);
    return FutureBuilder<Map<String, dynamic>>(
      future: _getPlanStats(),
      builder: (ctx, snap) {
        final stats = snap.data ?? {};
        final totalSessions = (stats['totalSessions'] as int?) ?? 0;
        final totalMinutes = (stats['totalMinutes'] as int?) ?? 0;
        final avgProductivity = (stats['avgProductivity'] as num?)?.toDouble() ?? 0.0;
        final completed = (stats['completed'] as int?) ?? 0;
        final totalItems = (stats['totalItems'] as int?) ?? 0;
        final progress = totalItems > 0 ? completed / totalItems : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('productivity analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 20),
              // Overall Progress Ring
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('overall plan progress', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 14,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                Text('$completed / $totalItems', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Session Stats
              Row(
                children: [
                  _buildStatCard('total sessions', '$totalSessions', 'all time', cs, accentColor: Colors.indigo),
                  const SizedBox(width: 12),
                  _buildStatCard('total hours', '${(totalMinutes / 60).toStringAsFixed(1)}', 'study time', cs, accentColor: Colors.deepPurple),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatCard('avg productivity', '${avgProductivity.toStringAsFixed(1)}', 'out of 10', cs, accentColor: Colors.amber),
                  const SizedBox(width: 12),
                  _buildStatCard('efficiency', '${(progress * 100).round()}%', 'plan completion', cs, accentColor: Colors.cyan),
                ],
              ),
              const SizedBox(height: 20),
              // Study Tips Card
              Card(
                elevation: 0,
                color: cs.secondaryContainer.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: cs.secondary),
                          const SizedBox(width: 8),
                          Text('study tips', style: TextStyle(fontWeight: FontWeight.bold, color: cs.secondary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip('use the pomodoro technique: 25 min study, 5 min break'),
                      _buildTip('review difficult topics during your peak energy hours'),
                      _buildTip('teach what you learn to someone else to reinforce memory'),
                      _buildTip('space out revisions: 1 day, 3 days, 7 days, 14 days'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildTaskTile(StudyPlanItem item, ColorScheme cs) {
    return FutureBuilder<SyllabusTopic?>(
      future: item.topicId != null ? DatabaseHelper.instance.getSyllabusTopic(item.topicId!) : Future.value(null),
      builder: (ctx, snapshot) {
        final topic = snapshot.data;
        final topicName = topic?.name ?? 'topic ${item.topicId}';
        final difficulty = topic?.difficulty;
        return Dismissible(
          key: Key('task_${item.id}'),
          direction: DismissDirection.horizontal,
          background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.check, color: Colors.white)),
          secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              final updated = item.copyWith(isCompleted: item.completed ? 0 : 1);
              await DatabaseHelper.instance.updateStudyPlanItem(updated);
            } else {
              await DatabaseHelper.instance.deleteStudyPlanItem(item.id!);
            }
            await _loadData();
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            elevation: 0,
            color: item.completed ? Colors.green.withOpacity(0.06) : cs.surfaceContainerHighest.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: item.completed ? Colors.green.withOpacity(0.2) : cs.outlineVariant.withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Checkbox(
                value: item.completed,
                onChanged: (value) async {
                  final updated = item.copyWith(isCompleted: value == true ? 1 : 0);
                  await DatabaseHelper.instance.updateStudyPlanItem(updated);
                  await _loadData();
                },
              ),
              title: Text(
                topicName,
                style: TextStyle(decoration: item.completed ? TextDecoration.lineThrough : null, color: item.completed ? cs.onSurfaceVariant : cs.onSurface),
              ),
              subtitle: Row(
                children: [
                  Text('${item.allocatedMinutes} min'),
                  if (difficulty != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: difficulty == 'hard' ? Colors.red.withOpacity(0.12) : difficulty == 'medium' ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(
                          fontSize: 10,
                          color: difficulty == 'hard' ? Colors.red : difficulty == 'medium' ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: item.completed
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Colors.green),
                      onPressed: () => _startTimer(item),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, ColorScheme cs, {Color? accentColor}) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accentColor ?? cs.primary)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// BOTTOM SHEET: Plan Generator
class _PlanGeneratorSheet extends StatefulWidget {
  const _PlanGeneratorSheet();

  @override
  State<_PlanGeneratorSheet> createState() => _PlanGeneratorSheetState();
}

class _PlanGeneratorSheetState extends State<_PlanGeneratorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _subjectId;
  int? _eventId;
  int _dailyMinutes = 120;
  int _bufferDays = 7;
  String _strategy = 'balanced';
  bool _generating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 12),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text('create study plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('generate a smart schedule based on your actual syllabus', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'plan name', prefixIcon: Icon(Icons.edit_note), hintText: 'e.g. neet physics plan'),
                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'required' : null,
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<SyllabusSubject>>(
                      future: DatabaseHelper.instance.getAllSyllabusSubjects(),
                      builder: (ctx, snap) {
                        final subjects = snap.data ?? [];
                        return DropdownButtonFormField<int>(
                          value: _subjectId,
                          decoration: const InputDecoration(labelText: 'subject *', prefixIcon: Icon(Icons.subject)),
                          items: subjects.map((s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(s.name)]),
                          )).toList(),
                          onChanged: (v) => setState(() => _subjectId = v),
                          validator: (v) => v == null ? 'select a subject' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<dynamic>>(
                      future: DatabaseHelper.instance.getAllEventsSorted(),
                      builder: (ctx, snap) {
                        final events = snap.data ?? [];
                        return DropdownButtonFormField<int?>(
                          value: _eventId,
                          decoration: const InputDecoration(labelText: 'linked event (optional)', prefixIcon: Icon(Icons.event)),
                          items: [const DropdownMenuItem<int?>(value: null, child: Text('none')), ...events.map((e) => DropdownMenuItem<int?>(value: e.id as int, child: Text(e.title as String)))],
                          onChanged: (v) => setState(() => _eventId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('study strategy', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'balanced', label: Text('balanced')),
                        ButtonSegment(value: 'hardFirst', label: Text('hard first')),
                        ButtonSegment(value: 'easyFirst', label: Text('easy first')),
                        ButtonSegment(value: 'marksWeighted', label: Text('marks')),
                      ],
                      selected: {_strategy},
                      onSelectionChanged: (s) => setState(() => _strategy = s.first),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text('daily study time:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(min: 30, max: 480, divisions: 15, value: _dailyMinutes.toDouble(), onChanged: (v) => setState(() => _dailyMinutes = v.round())),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                          child: Text('$_dailyMinutes min', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text('buffer days:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(min: 0, max: 30, divisions: 30, value: _bufferDays.toDouble(), onChanged: (v) => setState(() => _bufferDays = v.round())),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                          child: Text('$_bufferDays days', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSecondaryContainer)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                      label: Text(_generating ? 'generating...' : 'generate plan'),
                      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) return;
    setState(() => _generating = true);
    try {
      final plan = await DatabaseHelper.instance.generateStudyPlan(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'study plan ${DateTime.now().day}',
        subjectId: _subjectId!,
        dailyStudyMinutes: _dailyMinutes,
        eventId: _eventId,
        strategy: _strategy,
        bufferDays: _bufferDays,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('plan "${plan.name}" created successfully!'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('generation failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
