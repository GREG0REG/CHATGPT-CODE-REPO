import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/syllabus_subject.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import 'syllabus_add_edit_screen.dart';
import 'syllabus_subject_screen.dart';
import 'study_planner_screen.dart';

class SyllabusListScreen extends StatefulWidget {
  const SyllabusListScreen({super.key});

  @override
  State<SyllabusListScreen> createState() => _SyllabusListScreenState();
}

class _SyllabusListScreenState extends State<SyllabusListScreen> {
  List<SyllabusSubject> _subjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final rows = await db.getAllSyllabusSubjects();
    setState(() {
      _subjects = rows;
      _loading = false;
    });
  }

  Future<void> _deleteSubject(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: const Text('This will also delete all units, topics, and subtopics under it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteSyllabusSubject(id);
    await _loadData();
  }

  Future<void> _addSubject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyllabusAddEditScreen()),
    );
    if (result == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus Tracker'),
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
          : _subjects.isEmpty
              ? _buildEmptyState(cs)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _subjects.length,
                  itemBuilder: (ctx, index) {
                    final subject = _subjects[index];
                    return _buildSubjectCard(subject, cs);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubject,
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
    );
  }

  Widget _buildSubjectCard(SyllabusSubject subject, ColorScheme cs) {
    // We need to compute progress: count completed topics / total topics
    // For simplicity, we'll fetch counts from DB – but to keep UI smooth,
    // we can compute in a FutureBuilder or use a helper method.
    // We'll use a FutureBuilder inside the card to load counts.
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getSyllabusProgressForSubject(subject.id!),
      builder: (ctx, snapshot) {
        final data = snapshot.data ?? {'total': 0, 'completed': 0};
        final total = data['total'] ?? 0;
        final completed = data['completed'] ?? 0;
        final progress = total > 0 ? completed / total : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: subject.color,
              child: Text(
                subject.name.isNotEmpty ? subject.name[0].toUpperCase() : 'S',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$completed / $total topics completed'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                      ),
                      Center(
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SyllabusAddEditScreen(existing: subject),
                      ),
                    );
                    if (result == true) await _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _deleteSubject(subject.id!),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SyllabusSubjectScreen(subjectId: subject.id!),
                ),
              );
            },
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
          Icon(Icons.subject, size: 80, color: cs.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No Subjects Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first syllabus subject to start tracking',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
        ],
      ),
    );
  }
}
