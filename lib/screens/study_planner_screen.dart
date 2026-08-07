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
    final now = DateTime.now().millisecondsSinceEpoch;
    final todayStart = DateTime(now).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    StudyPlan? active;
    for (final p in plans) {
      if (p.startDateMillis <= now && p.endDateMillis >= now && p.active) {
        active = p;
        break;
      }
    }
    List<StudyPlanItem> todayItems = [];
    if (active != null) {
      todayItems = await db.getStudyPlanItemsForPlanInDateRange(
        active.id!,
        todayStart,
        todayEnd,
      );
    }
    setState(() {
      _plans = plans;
      _activePlan = active;
      _todayItems = todayItems;
      _loading = false;
    });
  }

  Future<void> _createNewPlan() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    int? subjectId;
    int? eventId;
    int dailyMinutes = 120;

    final subjects = await DatabaseHelper.instance.getAllSyllabusSubjects();
    final events = await DatabaseHelper.instance.getAllEventsSorted();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Study Plan'),
        content: SizedBox(
          width: 300,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Plan Name'),
                  onSaved: (v) => name = v?.trim() ?? 'My Plan',
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onSaved: (v) => subjectId = v,
                  validator: (v) => v == null ? 'Select a subject' : null,
                  // ─── FIX: added onChanged ───
                  onChanged: (value) {},
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Event (optional)'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('None')),
                    ...events.map((e) {
                      return DropdownMenuItem<int>(
                        value: e.id,
                        child: Text(e.title),
                      );
                    }),
                  ],
                  onSaved: (v) => eventId = v,
                  // ─── FIX: added onChanged ───
                  onChanged: (value) {},
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Daily minutes: '),
                    Expanded(
                      child: Slider(
                        min: 30,
                        max: 480,
                        divisions: 30,
                        value: dailyMinutes.toDouble(),
                        onChanged: (v) => dailyMinutes = v.round(),
                      ),
                    ),
                    Text('$dailyMinutes'),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (result != true || subjectId == null) return;

    try {
      final plan = await DatabaseHelper.instance.generateStudyPlan(
        name: name.isNotEmpty ? name : 'Study Plan ${DateTime.now().day}',
        subjectId: subjectId!,
        dailyStudyMinutes: dailyMinutes,
        eventId: eventId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan generated successfully!')),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    }
  }

  // ─── FIX: return type changed to Future<double> ───
  Future<double> _calculateProgress(StudyPlan plan) async {
    final items = await DatabaseHelper.instance.getStudyPlanItemsForPlan(plan.id!);
    if (items.isEmpty) return 0.0;
    final completed = items.where((i) => i.completed).length;
    return completed / items.length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Planner')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activePlan != null) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: FutureBuilder<double>(
                        future: _calculateProgress(_activePlan!),
                        builder: (ctx, snapshot) {
                          final progress = snapshot.data ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _activePlan!.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            '${DateTime.fromMillisecondsSinceEpoch(_activePlan!.startDateMillis).toLocal().toString().substring(0, 10)} – '
                                            '${DateTime.fromMillisecondsSinceEpoch(_activePlan!.endDateMillis).toLocal().toString().substring(0, 10)}',
                                            style: TextStyle(color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: progress >= 0.8
                                            ? Colors.green.withOpacity(0.15)
                                            : progress >= 0.5
                                                ? Colors.orange.withOpacity(0.15)
                                                : Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: progress >= 0.8
                                              ? Colors.green
                                              : progress >= 0.5
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                      ),
                                      child: Text(
                                        progress >= 0.8
                                            ? 'On Track'
                                            : progress >= 0.5
                                                ? 'Slightly Behind'
                                                : 'Behind',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: progress >= 0.8
                                              ? Colors.green
                                              : progress >= 0.5
                                                  ? Colors.orange
                                                  : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${(progress * 100).round()}% complete',
                                        style: TextStyle(color: cs.onSurfaceVariant)),
                                    Text(
                                      '${_activePlan!.endDateMillis ~/ 86400000 - DateTime.now().millisecondsSinceEpoch ~/ 86400000} days left',
                                      style: TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Today\'s Tasks',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                ..._todayItems.map((item) => CheckboxListTile(
                                      title: FutureBuilder(
                                        future: DatabaseHelper.instance.getSyllabusTopic(item.topicId!),
                                        builder: (ctx, snapshot) {
                                          final topic = snapshot.data;
                                          return Text(topic?.name ?? 'Topic ${item.topicId}');
                                        },
                                      ),
                                      subtitle: Text('${item.allocatedMinutes} min'),
                                      value: item.completed,
                                      onChanged: (value) async {
                                        final updated = item.copyWith(
                                            isCompleted: value == true ? 1 : 0);
                                        await DatabaseHelper.instance.updateStudyPlanItem(updated);
                                        await _loadData();
                                      },
                                      controlAffinity: ListTileControlAffinity.leading,
                                    )),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Gantt Chart (fl_chart)
                  if (_activePlan != null) ...[
                    const Text('Weekly Progress (Gantt)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                      ),
                      child: BarChart(
                        BarChartData(
                          maxY: 100,
                          barGroups: List.generate(7, (index) {
                            // Mock data – replace with actual plan data
                            final value = [80, 40, 100, 20, 90, 60, 70][index];
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: value.toDouble(),
                                  color: value >= 80
                                      ? Colors.green
                                      : value >= 50
                                          ? Colors.orange
                                          : Colors.red,
                                  width: 16,
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
                                  return Text(days[value.toInt()],
                                      style: const TextStyle(fontSize: 10));
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
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  ElevatedButton.icon(
                    onPressed: _createNewPlan,
                    icon: const Icon(Icons.add),
                    label: const Text('Generate New Plan'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
