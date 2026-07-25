// FILE: lib/screens/timetable_screen.dart
// COMPLETE NEW FILE — Smart Timetable with weekly view, conflict detection

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';
import 'main_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _loading = true;
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await _loadClasses();
    await _loadTasks();
    if (mounted) setState(() => _loading = false);
    await WidgetService.refreshTimetableWidget();
  }

  Future<void> _loadClasses() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'timetable_classes',
      orderBy: 'startTimeMinutes ASC',
    );
    setState(() => _classes = rows);
  }

  Future<void> _loadTasks() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ?',
      whereArgs: [now - 86400000],
      orderBy: 'dueDateMillis ASC',
    );
    setState(() => _tasks = rows);
  }

  Future<void> _addClass() async {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final profController = TextEditingController();
    String classType = 'lecture';
    int startMinutes = 540; // 9:00 AM
    int endMinutes = 600;   // 10:00 AM
    int dayOfWeek = _selectedDay + 1;

    final types = ['lecture', 'lab', 'tutorial', 'seminar', 'exam', 'quiz'];
    final typeLabels = ['Lecture', 'Lab', 'Tutorial', 'Seminar', 'Exam', 'Quiz'];
    final typeColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.red, Colors.orange];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Class'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Subject Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: 'Room/Location'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: profController,
                    decoration: const InputDecoration(labelText: 'Professor'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: classType,
                    decoration: const InputDecoration(labelText: 'Class Type'),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: typeColors[i], size: 12),
                          const SizedBox(width: 8),
                          Text(typeLabels[i]),
                        ],
                      ),
                    )),
                    onChanged: (v) => setDialogState(() => classType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: List.generate(7, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_dayNames[i]),
                    )),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(_formatMinutes(startMinutes)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60),
                      );
                      if (time != null) {
                        setDialogState(() => startMinutes = time.hour * 60 + time.minute);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(_formatMinutes(endMinutes)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60),
                      );
                      if (time != null) {
                        setDialogState(() => endMinutes = time.hour * 60 + time.minute);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  if (endMinutes <= startMinutes) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'name': nameController.text.trim(),
                    'room': roomController.text.trim(),
                    'prof': profController.text.trim(),
                    'type': classType,
                    'day': dayOfWeek,
                    'start': startMinutes,
                    'end': endMinutes,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    roomController.dispose();
    profController.dispose();

    if (result != null) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('timetable_classes', {
        'subjectName': result['name'],
        'classType': result['type'],
        'dayOfWeek': result['day'],
        'startTimeMinutes': result['start'],
        'endTimeMinutes': result['end'],
        'room': result['room'],
        'professor': result['prof'],
        'colorHex': _colorToHex(typeColors[types.indexOf(result['type'] as String)]),
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    String taskType = 'assignment';
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    final types = ['assignment', 'exam', 'revision', 'personal', 'study_block'];
    final typeLabels = ['Assignment', 'Exam', 'Revision', 'Personal', 'Study Block'];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Task/Deadline'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Subject (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: taskType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Text(typeLabels[i]),
                    )),
                    onChanged: (v) => setDialogState(() => taskType = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Due Date'),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.pop(ctx, {
                    'title': titleController.text.trim(),
                    'subject': subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                    'type': taskType,
                    'due': DateTime(dueDate.year, dueDate.month, dueDate.day).millisecondsSinceEpoch,
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

    if (result != null) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('timetable_tasks', {
        'title': result['title'],
        'taskType': result['type'],
        'subjectName': result['subject'],
        'dueDateMillis': result['due'],
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  Future<void> _deleteClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('timetable_classes', where: 'id = ?', whereArgs: [id]);
      await _loadData();
    }
  }

  Future<void> _deleteTask(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('timetable_tasks', where: 'id = ?', whereArgs: [id]);
      await _loadData();
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $ampm';
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
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
      'lecture': Colors.blue,
      'lab': Colors.green,
      'tutorial': Colors.purple,
      'seminar': Colors.teal,
      'exam': Colors.red,
      'quiz': Colors.orange,
      'assignment': Colors.indigo,
      'revision': Colors.amber,
      'personal': Colors.pink,
      'study_block': Colors.cyan,
    };
    return map[type] ?? Colors.blue;
  }

  IconData _typeIcon(String type) {
    final map = {
      'lecture': Icons.school,
      'lab': Icons.science,
      'tutorial': Icons.group,
      'seminar': Icons.record_voice_over,
      'exam': Icons.quiz,
      'quiz': Icons.help,
      'assignment': Icons.assignment,
      'revision': Icons.menu_book,
      'personal': Icons.person,
      'study_block': Icons.timer,
    };
    return map[type] ?? Icons.event;
  }

  List<Map<String, dynamic>> _getClassesForDay(int dayIndex) {
    return _classes.where((c) => c['dayOfWeek'] == dayIndex + 1).toList()
      ..sort((a, b) => (a['startTimeMinutes'] as int).compareTo(b['startTimeMinutes'] as int));
  }

  List<Map<String, dynamic>> _detectConflicts(List<Map<String, dynamic>> dayClasses) {
    final conflicts = <Map<String, dynamic>>[];
    for (int i = 0; i < dayClasses.length; i++) {
      for (int j = i + 1; j < dayClasses.length; j++) {
        final a = dayClasses[i];
        final b = dayClasses[j];
        final aStart = a['startTimeMinutes'] as int;
        final aEnd = a['endTimeMinutes'] as int;
        final bStart = b['startTimeMinutes'] as int;
        final bEnd = b['endTimeMinutes'] as int;
        if (aStart < bEnd && bStart < aEnd) {
          conflicts.add({'a': a, 'b': b});
        }
      }
    }
    return conflicts;
  }

  int _getFreeMinutesToday() {
    final dayClasses = _getClassesForDay(_selectedDay);
    if (dayClasses.isEmpty) return 720; // 12 hours
    int busyMinutes = 0;
    for (final c in dayClasses) {
      busyMinutes += (c['endTimeMinutes'] as int) - (c['startTimeMinutes'] as int);
    }
    return max(0, 720 - busyMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayClasses = _getClassesForDay(_selectedDay);
    final conflicts = _detectConflicts(dayClasses);
    final freeMinutes = _getFreeMinutesToday();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Timetable'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'class') _addClass();
              else if (value == 'task') _addTask();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'class', child: ListTile(leading: Icon(Icons.school), title: Text('Add Class'))),
              const PopupMenuItem(value: 'task', child: ListTile(leading: Icon(Icons.assignment), title: Text('Add Task'))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Day selector
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final isSelected = _selectedDay == i;
                      return InkWell(
                        onTap: () => setState(() => _selectedDay = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primaryContainer : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _dayNames[i],
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const Divider(height: 1),

                // Free time indicator
                if (freeMinutes > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.free_breakfast, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${freeMinutes ~/ 60}h ${freeMinutes % 60}m free today',
                          style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                // Conflict warning
                if (conflicts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${conflicts.length} schedule conflict${conflicts.length == 1 ? '' : 's'} detected!',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Classes list
                Expanded(
                  child: dayClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.schedule_outlined, size: 64, color: cs.outline.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('No classes on ${_dayNames[_selectedDay]}', style: TextStyle(color: cs.outline)),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _addClass,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Class'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: dayClasses.length,
                          itemBuilder: (context, index) {
                            final c = dayClasses[index];
                            final isConflict = conflicts.any((conf) =>
                                conf['a']['id'] == c['id'] || conf['b']['id'] == c['id']);
                            final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: isConflict
                                    ? BorderSide(color: Colors.red.withOpacity(0.5), width: 2)
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                onLongPress: () => _deleteClass(c['id'] as int),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(_typeIcon(c['classType'] as String), color: color),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c['subjectName'] as String,
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_formatMinutes(c['startTimeMinutes'] as int)} - ${_formatMinutes(c['endTimeMinutes'] as int)}',
                                              style: TextStyle(fontSize: 13, color: cs.outline),
                                            ),
                                            if ((c['room'] as String?)?.isNotEmpty == true)
                                              Text(
                                                '📍 ${c['room']}',
                                                style: TextStyle(fontSize: 12, color: cs.outline),
                                              ),
                                            if ((c['professor'] as String?)?.isNotEmpty == true)
                                              Text(
                                                '👤 ${c['professor']}',
                                                style: TextStyle(fontSize: 12, color: cs.outline),
                                              ),
                                            if (isConflict)
                                              Container(
                                                margin: const EdgeInsets.only(top: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'CONFLICT',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () => _deleteClass(c['id'] as int),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Upcoming tasks
                if (_tasks.isNotEmpty) ...[
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Upcoming Deadlines',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _tasks.take(10).length,
                      itemBuilder: (context, index) {
                        final t = _tasks[index];
                        final due = DateTime.fromMillisecondsSinceEpoch(t['dueDateMillis'] as int);
                        final daysLeft = due.difference(DateTime.now()).inDays;
                        final typeColor = _typeColor(t['taskType'] as String);

                        return Card(
                          margin: const EdgeInsets.only(right: 8, bottom: 8),
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_typeIcon(t['taskType'] as String), size: 14, color: typeColor),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        t['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  daysLeft < 0
                                      ? 'Overdue!'
                                      : daysLeft == 0
                                          ? 'Due today!'
                                          : '$daysLeft days left',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: daysLeft <= 1 ? Colors.red : cs.outline,
                                    fontWeight: daysLeft <= 1 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
