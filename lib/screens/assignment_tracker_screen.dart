// FILE: lib/screens/assignment_tracker_screen.dart
// COMPLETE REPLACEMENT — Fixed deadline field, persistent progress, improved filtering
// FIXED: Uses deadlineMillis instead of finalMillis for due dates
// FIXED: Includes assignments without subject tags
// ENHANCED: Persistent progress in notes with regex fallback, sort options, overdue badge

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import 'package:event_countdown/services/widget_service.dart';
import '../models/event.dart';
import 'main_screen.dart';

enum AssignmentSort { deadline, priority, progress, title }

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
  AssignmentSort _sortBy = AssignmentSort.deadline;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _loading = true);
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();
    
    // FIXED: Include all events that have a deadline in the future OR are not completed
    // Events with subjectTag are assignments, but also include events without subjectTag
    // that have been explicitly created as assignments
    final assignments = events.where((e) {
      final hasDeadline = e.deadlineMillis != null && e.deadlineMillis! > 0;
      final isFuture = hasDeadline && e.deadlineMillis! > now.millisecondsSinceEpoch;
      final isNotCompleted = !e.isCompleted;
      // Include if: has deadline AND (future OR not completed if showing all)
      return hasDeadline && (isFuture || (_showCompleted ? true : isNotCompleted));
    }).toList();
    
    // Sort based on selected sort option
    switch (_sortBy) {
      case AssignmentSort.deadline:
        assignments.sort((a, b) => (a.deadlineMillis ?? 0).compareTo(b.deadlineMillis ?? 0));
      case AssignmentSort.priority:
        assignments.sort((a, b) => b.priority.compareTo(a.priority));
      case AssignmentSort.progress:
        assignments.sort((a, b) => _getProgressFromEvent(b).compareTo(_getProgressFromEvent(a)));
      case AssignmentSort.title:
        assignments.sort((a, b) => a.title.compareTo(b.title));
    }
    
    setState(() {
      _assignments = assignments;
      _loading = false;
    });
  }

  Future<void> _addAssignment() async {
    if (_titleController.text.trim().isEmpty) return;
    
    final title = _titleController.text.trim();
    final course = _courseController.text.trim().isEmpty ? 'General' : _courseController.text.trim();
    
    // FIXED: Use deadlineMillis for the actual deadline, dateMillis for the due date start
    final dueDateStart = DateTime(_dueDate.year, _dueDate.month, _dueDate.day).millisecondsSinceEpoch;
    final deadlineEnd = DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 23, 59).millisecondsSinceEpoch;
    
    final event = Event(
      title: title,
      dateMillis: dueDateStart,
      deadlineMillis: deadlineEnd,
      priority: _priority,
      subjectTag: course,
      // Store progress in notes with a prefix for easy parsing
      notes: 'PROGRESS:${(_progress * 100).toInt()}%',
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
    // FIXED: Store progress with PROGRESS: prefix for reliable parsing
    final updatedNotes = _setProgressInNotes(event.notes, value);
    final updated = event.copyWith(
      notes: updatedNotes,
      // Auto-mark complete at 100%
      isCompleted: value >= 1.0 ? true : event.isCompleted,
    );
    await DatabaseHelper.instance.updateEvent(updated);
    setState(() {
      final idx = _assignments.indexWhere((e) => e.id == event.id);
      if (idx >= 0) _assignments[idx] = updated;
    });
    await WidgetService.refreshWidget();
  }

  // Helper to set progress in notes while preserving other content
  String _setProgressInNotes(String? existingNotes, double progress) {
    final progressText = 'PROGRESS:${(progress * 100).toInt()}%';
    if (existingNotes == null || existingNotes.isEmpty) {
      return progressText;
    }
    // Remove old progress marker if exists
    final cleaned = existingNotes.replaceAll(RegExp(r'PROGRESS:\d+%'), '').trim();
    if (cleaned.isEmpty) return progressText;
    return '$cleaned\n$progressText';
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

  IconData _priorityIcon(int p) {
    switch (p) {
      case 1: return Icons.arrow_downward;
      case 2: return Icons.remove;
      case 3: return Icons.arrow_upward;
      case 4: return Icons.priority_high;
      default: return Icons.minimize;
    }
  }

  String _timeRemaining(int deadlineMillis) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(deadlineMillis);
    final diff = due.difference(now);
    if (diff.isNegative) {
      final daysOverdue = diff.inDays.abs();
      return daysOverdue > 0 ? '$daysOverdue days overdue' : 'Overdue!';
    }
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

  bool _isOverdue(int deadlineMillis) {
    return DateTime.now().millisecondsSinceEpoch > deadlineMillis;
  }

  // FIXED: Parse progress from PROGRESS:XX% marker, fallback to old format
  double _getProgressFromEvent(Event event) {
    if (event.notes == null || event.notes!.isEmpty) return 0;
    // Try new format first
    final newMatch = RegExp(r'PROGRESS:(\d+)%').firstMatch(event.notes!);
    if (newMatch != null) return int.parse(newMatch.group(1)!) / 100;
    // Fallback to old format
    final oldMatch = RegExp(r'Progress: (\d+)%').firstMatch(event.notes!);
    if (oldMatch != null) return int.parse(oldMatch.group(1)!) / 100;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final doneCount = _assignments.where((a) => a.isCompleted).length;
    final urgentCount = _assignments.where((a) => a.priority == 4 && !a.isCompleted).length;
    final overdueCount = _assignments.where((a) => _isOverdue(a.deadlineMillis ?? 0) && !a.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Assignments'),
        actions: [
          // Sort menu
          PopupMenuButton<AssignmentSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (sort) {
              setState(() => _sortBy = sort);
              _loadAssignments();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: AssignmentSort.deadline, child: ListTile(leading: Icon(Icons.calendar_today), title: Text('Deadline'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: AssignmentSort.priority, child: ListTile(leading: Icon(Icons.flag), title: Text('Priority'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: AssignmentSort.progress, child: ListTile(leading: Icon(Icons.percent), title: Text('Progress'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: AssignmentSort.title, child: ListTile(leading: Icon(Icons.sort_by_alpha), title: Text('Title'), contentPadding: EdgeInsets.zero)),
            ],
          ),
          // Show completed toggle
          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off),
            tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
            onPressed: () {
              setState(() => _showCompleted = !_showCompleted);
              _loadAssignments();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                                  ButtonSegment(value: 1, label: Text('Low'), icon: Icon(Icons.arrow_downward, size: 14)),
                                  ButtonSegment(value: 2, label: Text('Norm')),
                                  ButtonSegment(value: 3, label: Text('High'), icon: Icon(Icons.arrow_upward, size: 14)),
                                  ButtonSegment(value: 4, label: Text('URG'), icon: Icon(Icons.priority_high, size: 14)),
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
                                  divisions: 20,
                                  label: '${(_progress * 100).toInt()}%',
                                  onChanged: (v) => setState(() => _progress = v),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                                ),
                              ),
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

                // Stats row with overdue
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _statChip('Total', _assignments.length.toString(), cs.primary),
                      const SizedBox(width: 8),
                      _statChip('Done', doneCount.toString(), Colors.green),
                      const SizedBox(width: 8),
                      _statChip('Urgent', urgentCount.toString(), Colors.orange),
                      if (overdueCount > 0) ...[
                        const SizedBox(width: 8),
                        _statChip('Overdue', overdueCount.toString(), Colors.red),
                      ],
                    ],
                  ),
                ),

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
                                Text('Add assignments above or create Events with deadlines',
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
                              final isOverdue = _isOverdue(a.deadlineMillis ?? 0);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: isOverdue && !a.isCompleted ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isOverdue && !a.isCompleted 
                                        ? Colors.red.withOpacity(0.5)
                                        : cs.outlineVariant.withOpacity(0.3),
                                    width: isOverdue && !a.isCompleted ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Checkbox(
                                        value: a.isCompleted,
                                        onChanged: (_) => _toggleComplete(a),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              a.title,
                                              style: TextStyle(
                                                decoration: a.isCompleted ? TextDecoration.lineThrough : null,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (isOverdue && !a.isCompleted)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.red.withOpacity(0.4)),
                                              ),
                                              child: const Text(
                                                'OVERDUE',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${a.subjectTag ?? 'General'} • ${_timeRemaining(a.deadlineMillis ?? 0)}'),
                                          if (a.deadlineMillis != null)
                                            Text(
                                              'Due: ${_formatDate(a.deadlineMillis!)}',
                                              style: TextStyle(fontSize: 11, color: cs.outline),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _priorityColor(a.priority).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(_priorityIcon(a.priority), size: 12, color: _priorityColor(a.priority)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _priorityLabel(a.priority),
                                                  style: TextStyle(
                                                    color: _priorityColor(a.priority),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
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
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: progress >= 1.0 ? Colors.green.withOpacity(0.15) : cs.primaryContainer,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${(progress * 100).toInt()}%',
                                                    style: TextStyle(
                                                      fontSize: 12, 
                                                      fontWeight: FontWeight.bold, 
                                                      color: progress >= 1.0 ? Colors.green : cs.onPrimaryContainer,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Slider(
                                              value: progress,
                                              divisions: 20,
                                              label: '${(progress * 100).toInt()}%',
                                              onChanged: (v) => _updateProgress(a, v),
                                            ),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 6,
                                                backgroundColor: cs.outlineVariant.withOpacity(0.3),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  isOverdue ? Colors.red : _urgencyColor(a.deadlineMillis ?? 0),
                                                ),
                                              ),
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

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.month}/${dt.day}/${dt.year}';
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
