import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subject.dart';
import 'syllabus_add_edit_screen.dart';
import 'syllabus_topic_screen.dart';

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

  String _statusDisplay(String status) {
    // Convert camelCase to words: "notStarted" -> "Not Started"
    final words = status.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return words[0].toUpperCase() + words.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_subject?.name ?? 'Subject'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb),
            tooltip: 'Today\'s Suggestions',
            onPressed: () => _showTodaySuggestions(),
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
                  padding: const EdgeInsets.all(16),
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(unit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${topics.length} topics'),
        children: topics.map((topic) {
          final statusColors = {
            'notStarted': Colors.grey,
            'inProgress': Colors.orange,
            'completed': Colors.green,
            'needsRevision': Colors.red,
          };
          final color = statusColors[topic.status] ?? Colors.grey;
          final displayStatus = _statusDisplay(topic.status);
          return ListTile(
            leading: CircleAvatar(radius: 6, backgroundColor: color),
            title: Text(topic.name),
            trailing: Text(
              displayStatus,
              style: TextStyle(fontSize: 12, color: color),
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
      ),
    );
  }

  void _showTodaySuggestions() async {
    final suggestions = await DatabaseHelper.instance.getTopicsForToday();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Today\'s Suggested Topics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (suggestions.isEmpty)
              const Text('No suggestions for today. Great job!')
            else
              ...suggestions.map((s) => ListTile(
                    leading: const Icon(Icons.today),
                    title: Text(s['name'] ?? ''),
                    subtitle: Text(s['subjectName'] ?? ''),
                  )),
          ],
        ),
      ),
    );
  }
}
