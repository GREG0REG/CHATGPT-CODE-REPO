import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import '../models/study_plan.dart';
import '../models/study_plan_item.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subject.dart';

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  List<StudyPlan> _plans = [];
  List<StudyPlanItem> _todayItems = [];
  List<StudyPlanItem> _weekItems = [];
  StudyPlan? _activePlan;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final plans = await db.getAllStudyPlans();
    final now = DateTime.now();
    final nowMillis = now.millisecondsSinceEpoch;
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;
    final weekStart = todayStart;
    final weekEnd = weekStart + const Duration(days: 7).inMilliseconds;

    StudyPlan? active;
    for (final p in plans) {
      if (p.startDateMillis <= nowMillis && p.endDateMillis >= nowMillis && p.active) {
        active = p;
        break;
      }
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

  Future<void> _createNewPlan() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _PlanGeneratorSheet(),
    );
    await _loadData();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Planner')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left sidebar - Plan overview
                if (_activePlan != null)
                  Container(
                    width: 140,
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activePlan!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _activePlan!.subjectId != null
                              ? DatabaseHelper.instance.getSyllabusPaceAnalysis(_activePlan!.subjectId!)
                              : Future.value({'status': 'Active'}),
                          builder: (ctx, snap) {
                            final status = (snap.data?['status'] as String?) ?? 'Active';
                            final statusColor = status.contains('On') || status.contains('Ahead')
                                ? Colors.green
                                : status.contains('Behind')
                                    ? Colors.red
                                    : Colors.orange;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${DateTime.fromMillisecondsSinceEpoch(_activePlan!.startDateMillis).toLocal().toString().substring(0, 10)} —\n'
                          '${DateTime.fromMillisecondsSinceEpoch(_activePlan!.endDateMillis).toLocal().toString().substring(0, 10)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_activePlan!.dailyStudyMinutes} min/day',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const Divider(height: 24),
                        // Mini timeline
                        ..._buildMiniTimeline(cs),
                      ],
                    ),
                  ),
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_activePlan != null) ...[
                          // Today's tasks
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: FutureBuilder<double>(
                              future: _calculateProgress(_activePlan!),
                              builder: (ctx, snapshot) {
                                final progress = snapshot.data ?? 0.0;
                                final daysLeft = (_activePlan!.endDateMillis - DateTime.now().millisecondsSinceEpoch) ~/ 86400000;

                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: cs.primaryContainer,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today,
                                              color: cs.onPrimaryContainer,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Today',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  '${DateTime.now().toLocal().toString().substring(0, 10)}',
                                                  style: TextStyle(
                                                    color: cs.onSurfaceVariant,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (_todayItems.isEmpty)
                                        Text(
                                          'No tasks scheduled for today.',
                                          style: TextStyle(color: cs.onSurfaceVariant),
                                        )
                                      else
                                        ..._todayItems.map((item) => _buildTaskTile(item, cs)),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Progress: ${(progress * 100).round()}%',
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            '$daysLeft days left',
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: cs.surfaceContainerHighest,
                                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Weekly Gantt
                          const Text(
                            'Weekly Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.3),
                              ),
                            ),
                            child: BarChart(
                              BarChartData(
                                maxY: 1.0,
                                barGroups: List.generate(7, (index) {
                                  final weeklyData = _getWeeklyProgress();
                                  final value = weeklyData[index] ?? 0.0;
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: value,
                                        color: value >= 0.8
                                            ? Colors.green
                                            : value >= 0.5
                                                ? Colors.orange
                                                : value > 0
                                                    ? Colors.red
                                                    : cs.surfaceContainerHighest,
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
                                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Stats cards
                        if (_activePlan != null) ...[
                          Row(
                            children: [
                              _buildStatCard(
                                'Days Left',
                                '${(_activePlan!.endDateMillis - DateTime.now().millisecondsSinceEpoch) ~/ 86400000}',
                                'until exam',
                                cs,
                              ),
                              const SizedBox(width: 12),
                              FutureBuilder<List<StudyPlanItem>>(
                                future: DatabaseHelper.instance.getStudyPlanItemsForPlan(_activePlan!.id!),
                                builder: (ctx, snap) {
                                  final items = snap.data ?? [];
                                  final remaining = items.where((i) => !i.completed).length;
                                  return _buildStatCard(
                                    'Topics Remaining',
                                    '$remaining',
                                    'out of ${items.length} total',
                                    cs,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard(
                                'Buffer Days',
                                '7',
                                'reserved for revision',
                                cs,
                                accentColor: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Daily Target',
                                '${_activePlan!.dailyStudyMinutes}m',
                                'per day',
                                cs,
                                accentColor: Colors.blue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        FilledButton.icon(
                          onPressed: _createNewPlan,
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Plan'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildMiniTimeline(ColorScheme cs) {
    if (_activePlan == null) return [];
    final items = <Widget>[];
    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(_activePlan!.startDateMillis);
    final end = DateTime.fromMillisecondsSinceEpoch(_activePlan!.endDateMillis);

    // Simplified timeline blocks
        final totalDays = end.difference(start).inDays;
    final passedDays = now.difference(start).inDays.clamp(0, totalDays);

    final blocks = [
      ('Mechanics', start, start.add(Duration(days: (totalDays * 0.3).round()))),
      ('Thermodynamics', start.add(Duration(days: (totalDays * 0.3).round())), start.add(Duration(days: (totalDays * 0.5).round()))),
      ('Electrodynamics', start.add(Duration(days: (totalDays * 0.5).round())), start.add(Duration(days: (totalDays * 0.8).round()))),
      ('Modern Physics', start.add(Duration(days: (totalDays * 0.8).round())), end),
    ];

    for (final (name, blockStart, blockEnd) in blocks) {
      final isActive = now.isAfter(blockStart) && now.isBefore(blockEnd);
      final isPast = now.isAfter(blockEnd);
      items.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primaryContainer
                : isPast
                    ? cs.surfaceContainerHighest
                    : cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? cs.primary : cs.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${blockStart.day}/${blockStart.month} — ${blockEnd.day}/${blockEnd.month}',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: passedDays / totalDays,
                  minHeight: 3,
                  backgroundColor: cs.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildTaskTile(StudyPlanItem item, ColorScheme cs) {
    return FutureBuilder<SyllabusTopic?>(
      future: item.topicId != null
          ? DatabaseHelper.instance.getSyllabusTopic(item.topicId!)
          : Future.value(null),
      builder: (ctx, snapshot) {
        final topic = snapshot.data;
        final topicName = topic?.name ?? 'Topic ${item.topicId}';
        final difficulty = topic?.difficulty;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: item.completed
              ? Colors.green.withOpacity(0.08)
              : cs.surfaceContainerHighest.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: item.completed
                  ? Colors.green.withOpacity(0.3)
                  : cs.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: item.completed,
              onChanged: (value) async {
                final updated = item.copyWith(
                  isCompleted: value == true ? 1 : 0,
                );
                await DatabaseHelper.instance.updateStudyPlanItem(updated);
                await _loadData();
              },
            ),
            title: Text(
              topicName,
              style: TextStyle(
                decoration: item.completed ? TextDecoration.lineThrough : null,
                color: item.completed ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
            subtitle: Row(
              children: [
                Text('${item.allocatedMinutes} min'),
                if (difficulty != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: difficulty == 'hard'
                          ? Colors.red.withOpacity(0.12)
                          : difficulty == 'medium'
                              ? Colors.orange.withOpacity(0.12)
                              : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      difficulty[0].toUpperCase() + difficulty.substring(1),
                      style: TextStyle(
                        fontSize: 10,
                        color: difficulty == 'hard'
                            ? Colors.red
                            : difficulty == 'medium'
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: item.completed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.circle_outlined, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    ColorScheme cs, {
    Color? accentColor,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: accentColor ?? cs.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET: Plan Generator
// ─────────────────────────────────────────────────────────────

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
  bool _generating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Create Study Plan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate a smart schedule based on your syllabus',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Plan Name',
                prefixIcon: Icon(Icons.edit_note),
                hintText: 'e.g. NEET Physics Plan',
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<SyllabusSubject>>(
              future: DatabaseHelper.instance.getAllSyllabusSubjects(),
              builder: (ctx, snap) {
                final subjects = snap.data ?? [];
                return DropdownButtonFormField<int>(
                  value: _subjectId,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    prefixIcon: Icon(Icons.subject),
                  ),
                  items: subjects.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(s.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _subjectId = v),
                  validator: (v) => v == null ? 'Select a subject' : null,
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
                  decoration: const InputDecoration(
                    labelText: 'Linked Event (optional)',
                    prefixIcon: Icon(Icons.event),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...events.map((e) {
                      return DropdownMenuItem<int?>(
                        value: e.id as int,
                        child: Text(e.title as String),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _eventId = v),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Daily Study Time:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 30,
                    max: 480,
                    divisions: 15,
                    value: _dailyMinutes.toDouble(),
                    onChanged: (v) => setState(() => _dailyMinutes = v.round()),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_dailyMinutes min',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Generating...' : 'Generate Plan'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) return;

    setState(() => _generating = true);

    try {
      final plan = await DatabaseHelper.instance.generateStudyPlan(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Study Plan ${DateTime.now().day}',
        subjectId: _subjectId!,
        dailyStudyMinutes: _dailyMinutes,
        eventId: _eventId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan "${plan.name}" created successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
