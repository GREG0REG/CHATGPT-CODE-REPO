// lib/screens/study_planner_screen.dart (FIXED)
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/study_plan.dart';
import '../models/study_plan_item.dart';

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
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    StudyPlan? active;
    for (final p in plans) {
      if (p.startDateMillis <= now && p.endDateMillis >= now && p.isActive == 1) {
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

  Future<double> _calculateProgress(StudyPlan plan) async {
    final items = await DatabaseHelper.instance.getStudyPlanItemsForPlan(plan.id!);
    if (items.isEmpty) return 0.0;
    final completed = items.where((i) => i.isCompleted == 1).length;
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
                    FutureBuilder<double>(
                      future: _calculateProgress(_activePlan!),
                      builder: (ctx, snapshot) {
                        final progress = snapshot.data ?? 0.0;
                        return Card(
                          color: const Color(0xFF1E2429), // Matches dark theme
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('NEET Physics Plan', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${(progress * 100).round()}% complete', style: const TextStyle(color: Colors.white)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('On Track', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.withOpacity(0.3), color: cs.primary),
                                const SizedBox(height: 12),
                                // Today's Items
                                const Text("Today's Tasks (Aug 8)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ..._todayItems.map((item) => FutureBuilder(
                                  future: DatabaseHelper.instance.getSyllabusTopic(item.topicId!),
                                  builder: (ctx, snapshot) {
                                    final topic = snapshot.data;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: item.isCompleted == 1,
                                            onChanged: (val) async {
                                              final updated = item.copyWith(isCompleted: val == true ? 1 : 0);
                                              await DatabaseHelper.instance.updateStudyPlanItem(updated);
                                              await _loadData();
                                            },
                                            activeColor: cs.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(topic?.name ?? '', style: const TextStyle(color: Colors.grey))),
                                          Text('${item.allocatedMinutes}m', style: const TextStyle(color: Colors.grey))
                                        ],
                                      ),
                                    );
                                  }
                                )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Days Left card
                  Card(
                    color: const Color(0xFF1E2429),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Days Left', '38', Colors.cyan),
                          _buildStat('Topics Left', '12', Colors.orange),
                          _buildStat('Buffer Days', '7', Colors.green),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Add your logic to trigger Generate New Plan
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Plan'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStat(String title, String value, Color color) => Column(
    children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20))],
  );
}
