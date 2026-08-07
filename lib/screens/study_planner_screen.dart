import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/study_plan.dart';
import '../models/study_plan_item.dart';
import '../models/syllabus_topic.dart';

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
    // Find active plan (the one with start <= now <= end)
    StudyPlan? active;
    for (final p in plans) {
      if (p.startDateMillis <= now && p.endDateMillis >= now && p.active) {
        active = p;
        break;
      }
    }
    List<StudyPlanItem> todayItems = [];
    if (active != null) {
      todayItems = await db.getStudyPlanItemsForPlanInDateRange(active.id!, todayStart, todayEnd);
    }
    setState(() {
      _plans = plans;
      _activePlan = active;
      _todayItems = todayItems;
      _loading = false;
    });
  }

  Future<void> _createNewPlan() async {
    // Simple flow: pick name, subject, event (optional), daily minutes
    // For brevity, we'll show a dialog with basic fields.
    // Then call db.generateStudyPlan().
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Plan: ${_activePlan!.name}', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text('From ${DateTime.fromMillisecondsSinceEpoch(_activePlan!.startDateMillis)} to ${DateTime.fromMillisecondsSinceEpoch(_activePlan!.endDateMillis)}'),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _calculateProgress(_activePlan!),
                              minHeight: 8,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                            const SizedBox(height: 8),
                            Text('${(_calculateProgress(_activePlan!) * 100).round()}% complete'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Today\'s Tasks', style: Theme.of(context).textTheme.titleMedium),
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
                            final updated = item.copyWith(isCompleted: value == true ? 1 : 0);
                            await DatabaseHelper.instance.updateStudyPlanItem(updated);
                            await _loadData();
                          },
                        )),
                    const SizedBox(height: 20),
                  ],
                  // Gantt chart placeholder – would use fl_chart
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('Gantt Chart (fl_chart)')),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _createNewPlan,
                    icon: const Icon(Icons.add),
                    label: const Text('Generate New Plan'),
                  ),
                ],
              ),
            ),
    );
  }

  double _calculateProgress(StudyPlan plan) {
    // For demo, return dummy
    return 0.3;
  }
}
