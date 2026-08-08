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
                  padding: const EdgeInsets.all(16),
                  itemCount: _subjects.length,
                  itemBuilder: (ctx, index) {
                    final subject = _subjects[index];
                    return _buildSubjectCard(subject);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubject,
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
        backgroundColor: const Color(0xFF00E5FF), // Cyan/Teal matches design
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildSubjectCard(SyllabusSubject subject) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getSyllabusProgressForSubject(subject.id!),
      builder: (ctx, snapshot) {
        final data = snapshot.data ?? {'total': 0, 'completed': 0};
        final total = data['total'] as int;
        final completed = data['completed'] as int;
        final progress = total > 0 ? completed / total : 0.0;

        // Determine status based on progress
        String statusText;
        Color statusColor;
        if (progress >= 0.8) {
          statusText = 'Ahead';
          statusColor = Colors.green;
        } else if (progress >= 0.5) {
          statusText = 'On Track';
          statusColor = Colors.green;
        } else {
          statusText = 'Behind';
          statusColor = Colors.orange;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2429), // Dark theme card background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2C3238), width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SyllabusSubjectScreen(subjectId: subject.id!),
                ),
              );
            },
            child: Row(
              children: [
                // Circular Progress (Pie Chart Simulation)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFF2F3540),
                        valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total units · $completed topics completed',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Popup Menu
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
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
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
          Icon(Icons.subject, size: 80, color: cs.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No Subjects Yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Add your first subject', style: TextStyle(color: cs.onSurfaceVariant)),
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
