import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/syllabus_subject.dart';
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
    final subjects = await DatabaseHelper.instance.getAllSyllabusSubjects();
    setState(() {
      _subjects = subjects;
      _loading = false;
    });
  }

  Future<void> _addSubject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SyllabusAddEditScreen(level: 'subject'),
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _deleteSubject(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: const Text('This will delete all units, topics, and subtopics under it.'),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Syllabus Tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyPlannerScreen()),
              ),
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('Study Planner'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? _buildEmptyState(cs)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getSyllabusProgressForSubject(subject.id!),
      builder: (ctx, snapshot) {
        final data = snapshot.data ?? {'total': 0, 'completed': 0};
        final total = data['total'] as int;
        final completed = data['completed'] as int;
        final progress = total > 0 ? completed / total : 0.0;
        final remaining = total - completed;

        // Pace status
        return FutureBuilder<Map<String, dynamic>>(
          future: DatabaseHelper.instance.getSyllabusPaceAnalysis(subject.id!),
          builder: (ctx, paceSnapshot) {
            final paceData = paceSnapshot.data;
            final paceStatus = (paceData?['status'] as String?) ?? 'No target';
            final paceColor = _paceColor(paceStatus);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SyllabusSubjectScreen(subjectId: subject.id!),
                    ),
                  ).then((_) => _loadData());
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Circular progress
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$total units · $total topics · $remaining remaining',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: paceColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: paceColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    paceStatus,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: paceColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SyllabusAddEditScreen(
                                  level: 'subject',
                                  existing: subject,
                                ),
                              ),
                            );
                            if (result == true) await _loadData();
                          } else if (value == 'delete') {
                            await _deleteSubject(subject.id!);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _paceColor(String status) {
    if (status.contains('Ahead') || status.contains('On Track')) return Colors.green;
    if (status.contains('Slightly')) return Colors.orange;
    if (status.contains('Behind')) return Colors.red;
    return Colors.grey;
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: cs.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No Subjects Yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Add your first subject to start tracking', style: TextStyle(color: cs.onSurfaceVariant)),
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
