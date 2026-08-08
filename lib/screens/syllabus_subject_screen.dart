import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subject.dart';
import 'syllabus_add_edit_screen.dart';

class SyllabusSubjectScreen extends StatefulWidget {
  final int subjectId;
  const SyllabusSubjectScreen({super.key, required this.subjectId});

  @override
  State<SyllabusSubjectScreen> createState() => _SyllabusSubjectScreenState();
}

class _SyllabusSubjectScreenState extends State<SyllabusSubjectScreen> {
  List<SyllabusUnit> _units = [];
  Map<int, List<SyllabusTopic>> _topicsMap = {};
  SyllabusSubject? _subject;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final subject = await db.getSyllabusSubject(widget.subjectId);
    final units = await db.getSyllabusUnitsForSubject(widget.subjectId);
    final topicsMap = <int, List<SyllabusTopic>>{};
    for (final unit in units) {
      final topics = await db.getSyllabusTopicsForUnit(unit.id!);
      topicsMap[unit.id!] = topics;
    }
    setState(() {
      _subject = subject;
      _units = units;
      _topicsMap = topicsMap;
      _loading = false;
    });
  }

  Future<void> _addUnit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyllabusAddEditScreen(
          level: 'unit',
          parentSubjectId: widget.subjectId,
        ),
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _cycleTopicStatus(SyllabusTopic topic) async {
    const statuses = ['notStarted', 'inProgress', 'completed', 'needsRevision'];
    final currentIndex = statuses.indexOf(topic.status);
    final nextStatus = statuses[(currentIndex + 1) % statuses.length];
    final updated = topic.copyWith(status: nextStatus);
    await DatabaseHelper.instance.updateSyllabusTopic(updated);
    if (nextStatus == 'completed') {
      await DatabaseHelper.instance.generateRevisionSchedules(topic.id!);
    }
    await _loadData();
  }

  String _statusDisplay(String status) {
    switch (status) {
      case 'notStarted': return 'not started';
      case 'inProgress': return 'in progress';
      case 'completed': return 'completed';
      case 'needsRevision': return 'needs revision';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'notStarted': return Colors.grey;
      case 'inProgress': return Colors.orange;
      case 'completed': return Colors.green;
      case 'needsRevision': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_subject?.name ?? 'subject'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'weightage analysis',
            onPressed: () => _showWeightageAnalysis(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _units.isEmpty
              ? _buildEmptyState(cs)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _units.length,
                  itemBuilder: (ctx, index) => _buildUnitCard(_units[index], cs),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('add unit'),
      ),
    );
  }

  Widget _buildUnitCard(SyllabusUnit unit, ColorScheme cs) {
    final topics = _topicsMap[unit.id] ?? [];
    final completedCount = topics.where((t) => t.status == 'completed').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          unit.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '$completedCount/${topics.length} done${unit.weightage != null ? '  ·  weight: ${unit.weightage}%' : ''}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        children: [
          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'no topics yet. add from the main syllabus screen.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            ...topics.map((topic) {
              final statusColor = _statusColor(topic.status);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: GestureDetector(
                  onTap: () => _cycleTopicStatus(topic),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                title: Text(topic.name),
                subtitle: topic.difficulty != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '· ${topic.difficulty}',
                            style: TextStyle(
                              fontSize: 12,
                              color: topic.difficulty == 'hard'
                                  ? Colors.red
                                  : topic.difficulty == 'medium'
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                          if (topic.estimatedMinutes != null)
                            Text(
                              '  · ${topic.estimatedMinutes} min',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          if (topic.neetMarksWeightage != null)
                            Text(
                              '  · ${topic.neetMarksWeightage} marks',
                              style: TextStyle(fontSize: 12, color: cs.primary),
                            ),
                        ],
                      )
                    : null,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusDisplay(topic.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  void _showWeightageAnalysis(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WeightageAnalysisSheet(
        subject: _subject,
        units: _units,
        topicsMap: _topicsMap,
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 60, color: cs.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('no units', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('add a unit to organize topics', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WEIGHTAGE ANALYSIS SHEET - NEET SPECIFIC
// ─────────────────────────────────────────────────────────────

class _WeightageAnalysisSheet extends StatelessWidget {
  final SyllabusSubject? subject;
  final List<SyllabusUnit> units;
  final Map<int, List<SyllabusTopic>> topicsMap;

  const _WeightageAnalysisSheet({
    this.subject,
    required this.units,
    required this.topicsMap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allTopics = units.expand((u) => topicsMap[u.id] ?? []).toList();
    final totalMarks = allTopics.fold<int>(0, (sum, t) => sum + (t.neetMarksWeightage ?? 0));
    final completedMarks = allTopics
        .where((t) => t.status == 'completed')
        .fold<int>(0, (sum, t) => sum + (t.neetMarksWeightage ?? 0));
    final marksProgress = totalMarks > 0 ? completedMarks / totalMarks : 0.0;

    // Group by status for pie chart
    final notStarted = allTopics.where((t) => t.status == 'notStarted').length;
    final inProgress = allTopics.where((t) => t.status == 'inProgress').length;
    final completed = allTopics.where((t) => t.status == 'completed').length;
    final needsRevision = allTopics.where((t) => t.status == 'needsRevision').length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'neet weightage analysis',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        subject?.name ?? '',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Marks progress
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'marks coverage',
                          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: marksProgress,
                                strokeWidth: 10,
                                backgroundColor: cs.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(subject?.color ?? cs.primary),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$completedMarks',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '/ $totalMarks',
                                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(marksProgress * 100).round()}% of total marks covered',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Status breakdown
                const Text('status breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusPill('not started', notStarted, Colors.grey, cs),
                    const SizedBox(width: 8),
                    _buildStatusPill('in progress', inProgress, Colors.orange, cs),
                    const SizedBox(width: 8),
                    _buildStatusPill('completed', completed, Colors.green, cs),
                    const SizedBox(width: 8),
                    _buildStatusPill('revision', needsRevision, Colors.red, cs),
                  ],
                ),
                const SizedBox(height: 20),
                // High weightage topics
                const Text('high marks topics (priority)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...allTopics
                    .where((t) => (t.neetMarksWeightage ?? 0) > 0)
                    .toList()
                    ..sort((a, b) => (b.neetMarksWeightage ?? 0).compareTo(a.neetMarksWeightage ?? 0))
                    ..take(10)
                    .map((topic) {
                      final unit = units.firstWhere((u) => u.id == topic.unitId);
                      final statusColor = _statusColor(topic.status);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: topic.status == 'completed'
                            ? Colors.green.withOpacity(0.06)
                            : cs.surfaceContainerHighest.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: topic.status == 'completed'
                                ? Colors.green.withOpacity(0.2)
                                : cs.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${topic.neetMarksWeightage}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(topic.name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(unit.name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusDisplay(topic.status),
                              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, int count, Color color, ColorScheme cs) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _statusDisplay(String status) {
    switch (status) {
      case 'notStarted': return 'not started';
      case 'inProgress': return 'in progress';
      case 'completed': return 'completed';
      case 'needsRevision': return 'needs revision';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'notStarted': return Colors.grey;
      case 'inProgress': return Colors.orange;
      case 'completed': return Colors.green;
      case 'needsRevision': return Colors.red;
      default: return Colors.grey;
    }
  }
}
