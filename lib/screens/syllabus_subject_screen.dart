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

  Future<void> _addTopicToUnit(int unitId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyllabusAddEditScreen(
          level: 'topic',
          parentUnitId: unitId,
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
      case 'notStarted': return 'Not Started';
      case 'inProgress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'needsRevision': return 'Needs Revision';
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
        title: Text(_subject?.name ?? 'Subject'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Today\'s Suggestions',
            onPressed: _showTodaySuggestions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _units.isEmpty
              ? _buildEmptyState(cs)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _units.length + 1, // +1 for suggestions card at bottom
                  itemBuilder: (ctx, index) {
                    if (index == _units.length) {
                      return _buildSuggestionsCard(cs);
                    }
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
    final completedCount = topics.where((t) => t.status == 'completed').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            unit.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            '$completedCount/${topics.length} done${unit.weightage != null ? '  ·  Weight: ${unit.weightage}%' : ''}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: 'Add Topic',
                onPressed: () => _addTopicToUnit(unit.id!),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            if (topics.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No topics yet. Tap + to add one.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              ...topics.map((topic) {
                final statusColor = _statusColor(topic.status);
                final displayStatus = _statusDisplay(topic.status);
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
                              '· ${topic.difficulty![0].toUpperCase()}${topic.difficulty!.substring(1)}',
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
                      displayStatus,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SyllabusTopicScreen(topicId: topic.id!),
                      ),
                    ).then((_) => _loadData());
                  },
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard(ColorScheme cs) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getTopicsForToday(),
      builder: (ctx, snapshot) {
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(top: 8, bottom: 80),
          elevation: 1,
          color: cs.primaryContainer.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Suggested',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('· ', style: TextStyle(color: cs.primary)),
                      Expanded(
                        child: Text(
                          '${s['name'] ?? ''} — ${s['subjectName'] ?? ''}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
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
    );
  }

  void _showTodaySuggestions() async {
    final suggestions = await DatabaseHelper.instance.getTopicsForToday();
    if (!mounted) return;
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
            const Text(
              'Today\'s Suggested Topics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
