import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../services/widget_service.dart';

/// Assignment tracker that syncs with Events database.
/// Assignments ARE events with subject tags — fully persistent.
class AssignmentTrackerScreen extends StatefulWidget {
  const AssignmentTrackerScreen({super.key});

  @override
  State<AssignmentTrackerScreen> createState() => _AssignmentTrackerScreenState();
}

class _AssignmentTrackerScreenState extends State<AssignmentTrackerScreen> {
  List<Event> _assignments = [];
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _priority = 2;
  double _progress = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _loading = true);
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    
    final assignments = events.where((e) {
      // Treat all non-completed future events with subject tags as assignments
      // Also include events that look like assignments (have subject tags)
      return e.subjectTag != null && 
             e.subjectTag!.isNotEmpty && 
             !e.isCompleted &&
             e.finalMillis > now.millisecondsSinceEpoch;
    }).toList();
    
    assignments.sort((a, b) => a.finalMillis.compareTo(b.finalMillis));
    
    setState(() {
      _assignments = assignments;
      _loading = false;
    });
  }

  Future<void> _addAssignment() async {
    if (_titleController.text.trim().isEmpty) return;
    
    final title = _titleController.text.trim();
    final course = _courseController.text.trim().isEmpty ? 'General' : _courseController.text.trim();
    
    // Create as an Event so it persists and widget updates
    final event = Event(
      title: title,
      dateMillis: DateTime(_dueDate.year, _dueDate.month, _dueDate.day).millisecondsSinceEpoch,
      deadlineMillis: DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 23, 59).millisecondsSinceEpoch,
      priority: _priority,
      subjectTag: course,
      notes: 'Progress: ${(_progress * 100).toInt()}%',
    );

    await DatabaseHelper.instance.insertEvent(event);
    await WidgetService.refreshWidget();
    
    HapticFeedback.lightImpact();
    _titleController.clear();
    _courseController.clear();
    _progress = 0;
    _priority = 2;
    _dueDate = DateTime.now().add(const Duration(days: 7));
    
    await _loadAssignments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _updateProgress(Event event, double value) async {
    if (event.id == null) return;
    final updated = event.copyWith(
      notes: 'Progress: ${(value * 100).toInt()}%',
    );
    await DatabaseHelper.instance.updateEvent(updated);
    setState(() {
      final idx = _assignments.indexWhere((e) => e.id == event.id);
      if (idx >= 0) _assignments[idx] = updated;
    });
  }

  Future<void> _toggleComplete(Event event) async {
    if (event.id == null) return;
    final updated = event.copyWith(isCompleted: !event.isCompleted);
    await DatabaseHelper.instance.updateEvent(updated);
    await WidgetService.refreshWidget();
    HapticFeedback.mediumImpact();
    await _loadAssignments();
  }

  Future<void> _deleteAssignment(Event event) async {
    if (event.id == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Assignment?'),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    await DatabaseHelper.instance.deleteEvent(event.id!);
    await WidgetService.refreshWidget();
    HapticFeedback.mediumImpact();
    await _loadAssignments();
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

  String _timeRemaining(int deadlineMillis) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(deadlineMillis);
    final diff = due.difference(now);
    if (diff.isNegative) return 'Overdue!';
    if (diff.inDays > 0) return '${diff.inDays} days left';
    if (diff.inHours > 0) return '${diff.inHours} hours left';
    return '${diff.inMinutes} min left';
  }

  Color _urgencyColor(int deadlineMillis) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(deadlineMillis);
    final diff = due.difference(now);
    if (diff.isNegative) return Colors.red;
    if (diff.inDays > 7) return Colors.green;
    if (diff.inDays > 3) return Colors.orange;
    return Colors.red;
  }

  double _getProgressFromEvent(Event event) {
    if (event.notes == null) return 0;
    final match = RegExp(r'Progress: (\d+)%').firstMatch(event.notes!);
    if (match == null) return 0;
    return int.parse(match.group(1)!) / 100;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final doneCount = _assignments.where((a) => a.isCompleted).length;
    final urgentCount = _assignments.where((a) => a.priority == 4 && !a.isCompleted).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                      _statChip('Done', doneCount.toString(), Colors.green),
                      const SizedBox(width: 8),
                      _statChip('Urgent', urgentCount.toString(), Colors.red),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAssignments,
                    child: _assignments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: cs.outline),
                                const SizedBox(height: 16),
                                Text('No assignments yet', style: TextStyle(color: cs.outline)),
                                const SizedBox(height: 8),
                                Text('Add assignments above or create Events with subjects',
                                    style: TextStyle(color: cs.outline, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _assignments.length,
                            itemBuilder: (context, index) {
                              final a = _assignments[index];
                              final progress = _getProgressFromEvent(a);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Checkbox(
                                        value: a.isCompleted,
                                        onChanged: (_) => _toggleComplete(a),
                                      ),
                                      title: Text(
                                        a.title,
                                        style: TextStyle(
                                          decoration: a.isCompleted ? TextDecoration.lineThrough : null,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text('${a.subjectTag ?? 'General'} • ${_timeRemaining(a.finalMillis)}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
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
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () => _deleteAssignment(a),
                                          ),
                                        ],
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
                                                Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Slider(
                                              value: progress,
                                              onChanged: (v) => _updateProgress(a, v),
                                            ),
                                            LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: cs.outlineVariant.withOpacity(0.3),
                                              valueColor: AlwaysStoppedAnimation<Color>(_urgencyColor(a.finalMillis)),
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
