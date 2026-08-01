// FILE: lib/screens/timetable_task_screen.dart
// COMPLETE REPLACEMENT — Task/Deadline Manager
// FIXED: Only uses columns that exist in timetable_tasks table

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';
import 'main_screen.dart';

class TimetableTaskScreen extends StatefulWidget {
  const TimetableTaskScreen({super.key});

  @override
  State<TimetableTaskScreen> createState() => _TimetableTaskScreenState();
}

class _TimetableTaskScreenState extends State<TimetableTaskScreen> {
  bool _loading = true;
  String _filterType = 'all';
  String _sortBy = 'dueDate';
  List<Map<String, dynamic>> _tasks = [];

  final List<Map<String, String>> _filterOptions = [
    {'value': 'all', 'label': 'All', 'icon': 'filter_list'},
    {'value': 'assignment', 'label': 'Assignments', 'icon': 'assignment'},
    {'value': 'exam', 'label': 'Exams', 'icon': 'quiz'},
    {'value': 'revision', 'label': 'Revision', 'icon': 'menu_book'},
    {'value': 'personal', 'label': 'Personal', 'icon': 'person'},
    {'value': 'study_block', 'label': 'Study', 'icon': 'timer'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    String whereClause = 'isCompleted = 0';
    List<dynamic> whereArgs = [];

    if (_filterType != 'all') {
      whereClause = 'taskType = ? AND isCompleted = 0';
      whereArgs = [_filterType];
    }

    String orderBy = 'dueDateMillis ASC';
    if (_sortBy == 'title') orderBy = 'title ASC';
    if (_sortBy == 'type') orderBy = 'taskType ASC, dueDateMillis ASC';

    final rows = await db.query(
      'timetable_tasks',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    setState(() {
      _tasks = rows;
      _loading = false;
    });
    await WidgetService.refreshTimetableWidget();
  }

  // ============================================
  // ADD TASK
  // ============================================
  Future<void> _addTask() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final noteController = TextEditingController();
    String taskType = 'assignment';
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    int? startTimeMinutes;
    int? endTimeMinutes;
    bool hasTime = false;

    final types = ['assignment', 'exam', 'revision', 'personal', 'study_block'];
    final typeLabels = ['Assignment', 'Exam', 'Revision', 'Personal', 'Study Block'];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Task / Deadline'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: taskType,
                    decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Text(typeLabels[i]),
                    )),
                    onChanged: (v) => setDialogState(() => taskType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Subject (optional)', prefixIcon: Icon(Icons.book)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Has Specific Time'),
                    subtitle: const Text('Add start/end time for this task'),
                    value: hasTime,
                    onChanged: (v) => setDialogState(() => hasTime = v),
                  ),
                  if (hasTime) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Start', style: TextStyle(fontSize: 12)),
                            subtitle: Text(
                              startTimeMinutes != null ? _formatMinutes(startTimeMinutes!) : 'Not set',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.access_time, size: 20),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (time != null) setDialogState(() => startTimeMinutes = time.hour * 60 + time.minute);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('End', style: TextStyle(fontSize: 12)),
                            subtitle: Text(
                              endTimeMinutes != null ? _formatMinutes(endTimeMinutes!) : 'Not set',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.access_time, size: 20),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (time != null) setDialogState(() => endTimeMinutes = time.hour * 60 + time.minute);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Title is required')));
                    return;
                  }
                  if (hasTime && startTimeMinutes != null && endTimeMinutes != null && endTimeMinutes! <= startTimeMinutes!) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
                    return;
                  }
                  Navigator.pop(ctx, {
                    'title': titleController.text.trim(),
                    'subject': subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                    'type': taskType,
                    'due': DateTime(dueDate.year, dueDate.month, dueDate.day).millisecondsSinceEpoch,
                    'startTime': hasTime ? startTimeMinutes : null,
                    'endTime': hasTime ? endTimeMinutes : null,
                    'note': noteController.text.trim(),
                  });
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    subjectController.dispose();
    noteController.dispose();

    if (result != null) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('timetable_tasks', {
        'title': result['title'],
        'taskType': result['type'],
        'subjectName': result['subject'],
        'dueDateMillis': result['due'],
        'startTimeMinutes': result['startTime'],
        'endTimeMinutes': result['endTime'],
        'isAllDay': result['startTime'] == null ? 1 : 0,
        'colorHex': _colorToHex(_typeColor(result['type'] as String)),
        'isCompleted': 0,
        'note': result['note'],
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  // ============================================
  // EDIT TASK
  // ============================================
  Future<void> _editTask(Map<String, dynamic> existing) async {
    final titleController = TextEditingController(text: existing['title'] as String? ?? '');
    final subjectController = TextEditingController(text: existing['subjectName'] as String? ?? '');
    final noteController = TextEditingController(text: existing['note'] as String? ?? '');
    String taskType = existing['taskType'] as String? ?? 'assignment';
    DateTime dueDate = DateTime.fromMillisecondsSinceEpoch(existing['dueDateMillis'] as int);
    int? startTimeMinutes = existing['startTimeMinutes'] as int?;
    int? endTimeMinutes = existing['endTimeMinutes'] as int?;
    bool hasTime = startTimeMinutes != null;

    final types = ['assignment', 'exam', 'revision', 'personal', 'study_block'];
    final typeLabels = ['Assignment', 'Exam', 'Revision', 'Personal', 'Study Block'];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: taskType,
                    decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Text(typeLabels[i]),
                    )),
                    onChanged: (v) => setDialogState(() => taskType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Subject (optional)', prefixIcon: Icon(Icons.book)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Has Specific Time'),
                    subtitle: const Text('Add start/end time for this task'),
                    value: hasTime,
                    onChanged: (v) => setDialogState(() => hasTime = v),
                  ),
                  if (hasTime) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Start', style: TextStyle(fontSize: 12)),
                            subtitle: Text(
                              startTimeMinutes != null ? _formatMinutes(startTimeMinutes!) : 'Not set',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.access_time, size: 20),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: startTimeMinutes != null ? startTimeMinutes! ~/ 60 : 9,
                                  minute: startTimeMinutes != null ? startTimeMinutes! % 60 : 0,
                                ),
                              );
                              if (time != null) setDialogState(() => startTimeMinutes = time.hour * 60 + time.minute);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('End', style: TextStyle(fontSize: 12)),
                            subtitle: Text(
                              endTimeMinutes != null ? _formatMinutes(endTimeMinutes!) : 'Not set',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.access_time, size: 20),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: endTimeMinutes != null ? endTimeMinutes! ~/ 60 : 10,
                                  minute: endTimeMinutes != null ? endTimeMinutes! % 60 : 0,
                                ),
                              );
                              if (time != null) setDialogState(() => endTimeMinutes = time.hour * 60 + time.minute);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Title is required')));
                    return;
                  }
                  if (hasTime && startTimeMinutes != null && endTimeMinutes != null && endTimeMinutes! <= startTimeMinutes!) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
                    return;
                  }
                  Navigator.pop(ctx, {
                    'title': titleController.text.trim(),
                    'subject': subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                    'type': taskType,
                    'due': DateTime(dueDate.year, dueDate.month, dueDate.day).millisecondsSinceEpoch,
                    'startTime': hasTime ? startTimeMinutes : null,
                    'endTime': hasTime ? endTimeMinutes : null,
                    'note': noteController.text.trim(),
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    subjectController.dispose();
    noteController.dispose();

    if (result != null) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'timetable_tasks',
        {
          'title': result['title'],
          'taskType': result['type'],
          'subjectName': result['subject'],
          'dueDateMillis': result['due'],
          'startTimeMinutes': result['startTime'],
          'endTimeMinutes': result['endTime'],
          'isAllDay': result['startTime'] == null ? 1 : 0,
          'colorHex': _colorToHex(_typeColor(result['type'] as String)),
          'note': result['note'],
          'updatedAtMillis': now,
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  // ============================================
  // DELETE
  // ============================================
  Future<void> _deleteTask(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task?'),
        content: const Text('This will permanently remove this task.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('timetable_tasks', where: 'id = ?', whereArgs: [id]);
      await _loadData();
    }
  }

  Future<void> _toggleTaskComplete(int id, bool current) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'timetable_tasks',
      {'isCompleted': current ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadData();
  }

  // ============================================
  // HELPERS
  // ============================================
  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $ampm';
  }

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDay = DateTime(dt.year, dt.month, dt.day);

    if (taskDay == today) return 'Today';
    if (taskDay == tomorrow) return 'Tomorrow';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _colorToHex(Color color) {
    final argb = color.value;
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Color _hexToColor(String hex) {
    if (hex.isEmpty) return Colors.blue;
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _typeColor(String type) {
    final map = {
      'lecture': Colors.blue, 'lab': Colors.green, 'tutorial': Colors.purple,
      'seminar': Colors.teal, 'exam': Colors.red, 'quiz': Colors.orange,
      'assignment': Colors.indigo, 'revision': Colors.amber,
      'personal': Colors.pink, 'study_block': Colors.cyan,
    };
    return map[type] ?? Colors.blue;
  }

  IconData _typeIcon(String type) {
    final map = {
      'lecture': Icons.school, 'lab': Icons.science, 'tutorial': Icons.group,
      'seminar': Icons.record_voice_over, 'exam': Icons.quiz, 'quiz': Icons.help,
      'assignment': Icons.assignment, 'revision': Icons.menu_book,
      'personal': Icons.person, 'study_block': Icons.timer,
    };
    return map[type] ?? Icons.event;
  }

  String _typeLabel(String type) {
    final map = {
      'lecture': 'Lecture', 'lab': 'Lab', 'tutorial': 'Tutorial',
      'seminar': 'Seminar', 'exam': 'Exam', 'quiz': 'Quiz',
      'assignment': 'Assignment', 'revision': 'Revision',
      'personal': 'Personal', 'study_block': 'Study Block',
    };
    return map[type] ?? type;
  }

  bool _isOverdue(int dueMillis) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return dueMillis < todayStart;
  }

  bool _isDueSoon(int dueMillis) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart = todayStart + const Duration(days: 1).inMilliseconds;
    return dueMillis >= todayStart && dueMillis < tomorrowStart;
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Tasks & Deadlines'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dueDate', child: Text('Sort by Due Date')),
              const PopupMenuItem(value: 'title', child: Text('Sort by Title')),
              const PopupMenuItem(value: 'type', child: Text('Sort by Type')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Task',
            onPressed: _addTask,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((opt) {
                        final isSelected = _filterType == opt['value'];
                        final color = opt['value'] == 'all' ? cs.primary : _typeColor(opt['value']!);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            showCheckmark: false,
                            avatar: Icon(
                              _typeIcon(opt['value']!),
                              size: 16,
                              color: isSelected ? Colors.white : color,
                            ),
                            label: Text(opt['label']!),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : cs.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            backgroundColor: cs.surfaceContainerHighest.withOpacity(0.3),
                            selectedColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? Colors.transparent : cs.outline.withOpacity(0.3),
                              ),
                            ),
                            onSelected: (_) {
                              setState(() => _filterType = opt['value']!);
                              _loadData();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Stats bar
                if (_tasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('${_tasks.length}', 'Tasks', cs.onSurface),
                        _statItem(
                          '${_tasks.where((t) => _isOverdue(t['dueDateMillis'] as int)).length}',
                          'Overdue',
                          Colors.red,
                        ),
                        _statItem(
                          '${_tasks.where((t) => _isDueSoon(t['dueDateMillis'] as int)).length}',
                          'Due Soon',
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Task list
                Expanded(
                  child: _tasks.isEmpty
                      ? _buildEmptyState(cs)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return _buildTaskCard(task, cs);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 72, color: cs.outline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            _filterType == 'all' ? 'No tasks yet' : 'No ${_typeLabel(_filterType)} tasks',
            style: TextStyle(color: cs.outline, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add a new task',
            style: TextStyle(color: cs.outline.withOpacity(0.7), fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addTask,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> t, ColorScheme cs) {
    final typeColor = _typeColor(t['taskType'] as String);
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;
    final dueMillis = t['dueDateMillis'] as int;
    final overdue = _isOverdue(dueMillis);
    final dueSoon = _isDueSoon(dueMillis);
    final cardColor = isCompleted
        ? Colors.grey.withOpacity(0.05)
        : overdue
            ? Colors.red.withOpacity(0.05)
            : dueSoon
                ? Colors.orange.withOpacity(0.05)
                : cs.surface;

    return Dismissible(
      key: Key('task_${t['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Task?'),
            content: const Text('This will permanently remove this task.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final db = await DatabaseHelper.instance.database;
          await db.delete('timetable_tasks', where: 'id = ?', whereArgs: [t['id']]);
          await _loadData();
          return true;
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: isCompleted ? 0 : 1,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCompleted
                ? Colors.grey.withOpacity(0.2)
                : overdue
                    ? Colors.red.withOpacity(0.4)
                    : dueSoon
                        ? Colors.orange.withOpacity(0.4)
                        : cs.outline.withOpacity(0.1),
            width: isCompleted ? 1 : (overdue || dueSoon ? 1.5 : 1),
          ),
        ),
        child: InkWell(
          onTap: () => _editTask(t),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.grey.withOpacity(0.15) : typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _typeIcon(t['taskType'] as String),
                        color: isCompleted ? Colors.grey : typeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['title'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.grey : cs.onSurface,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _typeLabel(t['taskType'] as String),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              if ((t['subjectName'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(width: 6),
                                Text(
                                  t['subjectName'] as String,
                                  style: TextStyle(fontSize: 11, color: cs.outline),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isCompleted,
                      onChanged: (_) => _toggleTaskComplete(t['id'] as int, isCompleted),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: overdue ? Colors.red : dueSoon ? Colors.orange : cs.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(dueMillis),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: overdue ? Colors.red : dueSoon ? Colors.orange : cs.onSurfaceVariant,
                      ),
                    ),
                    if (t['startTimeMinutes'] != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatMinutes(t['startTimeMinutes'] as int)} - ${_formatMinutes(t['endTimeMinutes'] as int)}',
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                    ],
                    const Spacer(),
                    if (overdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('OVERDUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                    if (dueSoon && !overdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('DUE SOON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                  ],
                ),
                if ((t['note'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.notes, size: 12, color: cs.outline.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          t['note'] as String,
                          style: TextStyle(fontSize: 11, color: cs.outline.withOpacity(0.7)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
