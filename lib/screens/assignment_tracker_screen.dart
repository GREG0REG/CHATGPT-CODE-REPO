import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/event.dart';

/// Quick assignment tracker with priority and progress
class AssignmentTrackerScreen extends StatefulWidget {
  const AssignmentTrackerScreen({super.key});

  @override
  State<AssignmentTrackerScreen> createState() => _AssignmentTrackerScreenState();
}

class _AssignmentTrackerScreenState extends State<AssignmentTrackerScreen> {
  final List<Assignment> _assignments = [];
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _priority = 2;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    // Load from events with subject tags as assignments
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    
    setState(() {
      _assignments.clear();
      for (final e in events) {
        if (!e.isCompleted && e.finalMillis > now.millisecondsSinceEpoch) {
          _assignments.add(Assignment.fromEvent(e));
        }
      }
      _assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });
  }

  void _addAssignment() {
    if (_titleController.text.trim().isEmpty) return;
    
    setState(() {
      _assignments.add(Assignment(
        title: _titleController.text.trim(),
        course: _courseController.text.trim().isEmpty ? 'General' : _courseController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        progress: _progress,
      ));
      _assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });

    HapticFeedback.lightImpact();
    _titleController.clear();
    _courseController.clear();
    _progress = 0;
  }

  void _updateProgress(int index, double value) {
    setState(() {
      _assignments[index] = _assignments[index].copyWith(progress: value);
    });
  }

  void _toggleComplete(int index) {
    setState(() {
      _assignments[index] = _assignments[index].copyWith(
        isCompleted: !_assignments[index].isCompleted,
      );
    });
    HapticFeedback.mediumImpact();
  }

  void _deleteAssignment(int index) {
    setState(() => _assignments.removeAt(index));
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.orange;
      case 4: return Colors.red;
      default: return Colors.grey;
    }
  }

  String _priorityLabel(int p) {
    switch (p) {
      case 1: return 'Low';
      case 2: return 'Normal';
      case 3: return 'High';
      case 4: return 'Urgent';
      default: return 'None';
    }
  }

  String _timeRemaining(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.isNegative) return 'Overdue!';
    if (diff.inDays > 0) return '${diff.inDays} days left';
    if (diff.inHours > 0) return '${diff.inHours} hours left';
    return '${diff.inMinutes} min left';
  }

  Color _urgencyColor(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.isNegative) return Colors.red;
    if (diff.inDays > 7) return Colors.green;
    if (diff.inDays > 3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      body: Column(
        children: [
          // Quick add
          ExpansionTile(
            title: const Text('Quick Add Assignment'),
            leading: const Icon(Icons.add_circle),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Assignment Title',
                        hintText: 'e.g., Essay on Climate Change',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _courseController,
                      decoration: const InputDecoration(
                        labelText: 'Course/Subject',
                        hintText: 'e.g., Environmental Science',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text('${_dueDate.month}/${_dueDate.day}/${_dueDate.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Priority: '),
                        const SizedBox(width: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 1, label: Text('Low')),
                            ButtonSegment(value: 2, label: Text('Norm')),
                            ButtonSegment(value: 3, label: Text('High')),
                            ButtonSegment(value: 4, label: Text('URG')),
                          ],
                          selected: {_priority},
                          onSelectionChanged: (sel) {
                            if (sel.isNotEmpty) setState(() => _priority = sel.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Progress: '),
                        Expanded(
                          child: Slider(
                            value: _progress,
                            onChanged: (v) => setState(() => _progress = v),
                          ),
                        ),
                        Text('${(_progress * 100).toInt()}%'),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addAssignment,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _statChip('Total', _assignments.length.toString(), cs.primary),
                const SizedBox(width: 8),
                _statChip('Done', _assignments.where((a) => a.isCompleted).length.toString(), Colors.green),
                const SizedBox(width: 8),
                _statChip('Urgent', _assignments.where((a) => a.priority == 4 && !a.isCompleted).length.toString(), Colors.red),
              ],
            ),
          ),

          // List
          Expanded(
            child: _assignments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: cs.outline),
                        const SizedBox(height: 16),
                        Text('No assignments yet', style: TextStyle(color: cs.outline)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) {
                      final a = _assignments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: a.isCompleted ? cs.surfaceContainerHighest.withOpacity(0.5) : null,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Checkbox(
                                value: a.isCompleted,
                                onChanged: (_) => _toggleComplete(index),
                              ),
                              title: Text(
                                a.title,
                                style: TextStyle(
                                  decoration: a.isCompleted ? TextDecoration.lineThrough : null,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('${a.course} • ${_timeRemaining(a.dueDate)}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _priorityColor(a.priority).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _priorityLabel(a.priority),
                                  style: TextStyle(
                                    color: _priorityColor(a.priority),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (!a.isCompleted) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Progress', style: TextStyle(fontSize: 12, color: cs.outline)),
                                        Text('${(a.progress * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Slider(
                                      value: a.progress,
                                      onChanged: (v) => _updateProgress(index, v),
                                    ),
                                    LinearProgressIndicator(
                                      value: a.progress,
                                      backgroundColor: cs.outlineVariant.withOpacity(0.3),
                                      valueColor: AlwaysStoppedAnimation<Color>(_urgencyColor(a.dueDate)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseController.dispose();
    super.dispose();
  }
}

class Assignment {
  final String title;
  final String course;
  final DateTime dueDate;
  final int priority;
  final double progress;
  final bool isCompleted;

  Assignment({
    required this.title,
    required this.course,
    required this.dueDate,
    this.priority = 2,
    this.progress = 0,
    this.isCompleted = false,
  });

  factory Assignment.fromEvent(Event e) {
    return Assignment(
      title: e.title,
      course: e.subjectTag ?? 'General',
      dueDate: DateTime.fromMillisecondsSinceEpoch(e.finalMillis),
      priority: e.priority,
      progress: 0,
      isCompleted: e.isCompleted,
    );
  }

  Assignment copyWith({
    String? title,
    String? course,
    DateTime? dueDate,
    int? priority,
    double? progress,
    bool? isCompleted,
  }) {
    return Assignment(
      title: title ?? this.title,
      course: course ?? this.course,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
