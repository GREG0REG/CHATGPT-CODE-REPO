import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subject.dart';
import 'syllabus_add_edit_screen.dart';
import 'syllabus_topic_screen.dart';
import 'study_planner_screen.dart';

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
          parentSubjectId: widget.subjectId,
          level: 'unit',
        ),
      ),
    );
    if (result == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_subject?.name ?? 'Subject'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Study Planner',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudyPlannerScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _units.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 60, color: cs.primary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No Units', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Add a unit to organize topics', style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _units.length,
                  itemBuilder: (ctx, index) {
                    final unit = _units[index];
                    final topics = _topicsMap[unit.id] ?? [];
                    return _buildUnitCard(unit, topics, cs);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),
    );
  }

  Widget _buildUnitCard(SyllabusUnit unit, List<SyllabusTopic> topics, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(unit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${topics.length} topics'),
        children: topics.map((topic) {
          return ListTile(
            leading: CircleAvatar(
              radius: 10,
              backgroundColor: _statusColor(topic.statusEnum),
            ),
            title: Text(topic.name),
            trailing: Text(
              topic.status,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SyllabusTopicScreen(topicId: topic.id!),
                ),
              );
            },
          );
        }).toList(),
        onExpansionChanged: (expanded) {},
      ),
    );
  }

  Color _statusColor(TopicStatus status) {
    switch (status) {
      case TopicStatus.completed:
        return Colors.green;
      case TopicStatus.inProgress:
        return Colors.orange;
      case TopicStatus.needsRevision:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
