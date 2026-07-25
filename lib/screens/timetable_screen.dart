// FILE: lib/screens/timetable_screen.dart
// COMPLETE REPLACEMENT — Smart Timetable with vertical timeline, conflict detection, study suggestions

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

  // Timeline constants
  static const int _timelineStartHour = 8;
  static const int _timelineEndHour = 20;
  static const int _timelineStartMinutes = _timelineStartHour * 60; // 480
  static const int _timelineEndMinutes = _timelineEndHour * 60;     // 1200
  static const int _totalTimelineMinutes = _timelineEndMinutes - _timelineStartMinutes; // 720
  static const double _hourHeight = 72.0; // pixels per hour
  static const double _timelineWidth = 60.0; // width of time labels column

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
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfWeek = startOfToday + const Duration(days: 7).inMilliseconds;
    final rows = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ? AND isCompleted = 0',
      whereArgs: [startOfToday - const Duration(days: 1).inMilliseconds, endOfWeek],
      orderBy: 'dueDateMillis ASC',
    );
    setState(() => _tasks = rows);
  }

  // ============================================
  // ADD CLASS
  // ============================================
  Future<void> _addClass() async {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final profController = TextEditingController();
    final noteController = TextEditingController();
    String classType = 'lecture';
    int startMinutes = 540; // 9:00 AM
    int endMinutes = 600;   // 10:00 AM
    int dayOfWeek = _selectedDay + 1;
    bool isRecurring = true;
    DateTime? startDate;
    DateTime? endDate;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name *',
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: classType,
                    decoration: const InputDecoration(
                      labelText: 'Class Type',
                      prefixIcon: Icon(Icons.category),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Day',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(7, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_dayNames[i]),
                    )),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start Time', style: TextStyle(fontSize: 12)),
                          subtitle: Text(_formatMinutes(startMinutes), style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.access_time, size: 20),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60),
                            );
                            if (time != null) {
                              setDialogState(() => startMinutes = time.hour * 60 + time.minute);
                              if (endMinutes <= startMinutes) {
                                setDialogState(() => endMinutes = startMinutes + 60);
                              }
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('End Time', style: TextStyle(fontSize: 12)),
                          subtitle: Text(_formatMinutes(endMinutes), style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.access_time, size: 20),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room / Location',
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: profController,
                    decoration: const InputDecoration(
                      labelText: 'Professor',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recurring Weekly'),
                    subtitle: const Text('Repeat every week'),
                    value: isRecurring,
                    onChanged: (v) => setDialogState(() => isRecurring = v),
                  ),
                  if (!isRecurring) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Date', style: TextStyle(fontSize: 12)),
                      subtitle: Text(
                        startDate != null ? '${startDate!.day}/${startDate!.month}/${startDate!.year}' : 'Not set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.date_range, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => startDate = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Date', style: TextStyle(fontSize: 12)),
                      subtitle: Text(
                        endDate != null ? '${endDate!.day}/${endDate!.month}/${endDate!.year}' : 'Not set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.date_range, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Subject name is required')),
                    );
                    return;
                  }
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
                    'note': noteController.text.trim(),
                    'type': classType,
                    'day': dayOfWeek,
                    'start': startMinutes,
                    'end': endMinutes,
                    'isRecurring': isRecurring,
                    'startDate': startDate,
                    'endDate': endDate,
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
    noteController.dispose();

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
        'isRecurring': (result['isRecurring'] as bool) ? 1 : 0,
        'startDateMillis': result['startDate'] != null
            ? DateTime(result['startDate'].year, result['startDate'].month, result['startDate'].day).millisecondsSinceEpoch
            : null,
        'endDateMillis': result['endDate'] != null
            ? DateTime(result['endDate'].year, result['endDate'].month, result['endDate'].day).millisecondsSinceEpoch
            : null,
        'note': result['note'],
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
    }
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
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: taskType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Text(typeLabels[i]),
                    )),
                    onChanged: (v) => setDialogState(() => taskType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
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
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Title is required')),
                    );
                    return;
                  }
                  if (hasTime && startTimeMinutes != null && endTimeMinutes != null && endTimeMinutes! <= startTimeMinutes!) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time')),
                    );
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
  // SUGGEST STUDY BLOCK
  // ============================================
  Future<void> _suggestStudyBlock() async {
    final freeSlots = _getFreeSlotsForDay(_selectedDay);
    if (freeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No free slots available today')),
      );
      return;
    }

    // Pick the longest free slot
    freeSlots.sort((a, b) => (b['duration'] as int).compareTo(a['duration'] as int));
    final bestSlot = freeSlots.first;

    final subjectController = TextEditingController();
    int durationMinutes = (bestSlot['duration'] as int).clamp(30, 120);
    int startMinutes = bestSlot['start'] as int;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Suggest Study Block'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best free slot found:',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatMinutes(bestSlot['start'] as int)} - ${_formatMinutes(bestSlot['end'] as int)} (${bestSlot['duration']} min)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durationMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    items: [30, 45, 60, 90, 120].map((m) => DropdownMenuItem(
                      value: m,
                      child: Text('$m minutes'),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => durationMinutes = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Time', style: TextStyle(fontSize: 12)),
                    subtitle: Text(_formatMinutes(startMinutes), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.access_time, size: 20),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60),
                      );
                      if (time != null) setDialogState(() => startMinutes = time.hour * 60 + time.minute);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (subjectController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Subject is required')),
                    );
                    return;
                  }
                  final endMin = startMinutes + durationMinutes;
                  if (endMin > _timelineEndMinutes) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Study block extends beyond 8 PM')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'subject': subjectController.text.trim(),
                    'start': startMinutes,
                    'end': endMin,
                  });
                },
                child: const Text('Add Study Block'),
              ),
            ],
          );
        },
      ),
    );

    subjectController.dispose();

    if (result != null) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('timetable_tasks', {
        'title': 'Study: ${result['subject']}',
        'taskType': 'study_block',
        'subjectName': result['subject'],
        'dueDateMillis': DateTime.now().millisecondsSinceEpoch,
        'startTimeMinutes': result['start'],
        'endTimeMinutes': result['end'],
        'isAllDay': 0,
        'colorHex': _colorToHex(Colors.cyan),
        'isCompleted': 0,
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study block added!')),
      );
    }
  }

  // ============================================
  // DELETE
  // ============================================
  Future<void> _deleteClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Class?'),
        content: const Text('This will permanently remove this class from your timetable.'),
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
      await db.delete('timetable_classes', where: 'id = ?', whereArgs: [id]);
      await _loadData();
    }
  }

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

  String _formatMinutes24(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
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

  String _typeLabel(String type) {
    final map = {
      'lecture': 'Lecture',
      'lab': 'Lab',
      'tutorial': 'Tutorial',
      'seminar': 'Seminar',
      'exam': 'Exam',
      'quiz': 'Quiz',
      'assignment': 'Assignment',
      'revision': 'Revision',
      'personal': 'Personal',
      'study_block': 'Study Block',
    };
    return map[type] ?? type;
  }

  List<Map<String, dynamic>> _getClassesForDay(int dayIndex) {
    return _classes.where((c) => c['dayOfWeek'] == dayIndex + 1).toList()
      ..sort((a, b) => (a['startTimeMinutes'] as int).compareTo(b['startTimeMinutes'] as int));
  }

  List<Map<String, dynamic>> _getTasksForDay(int dayIndex) {
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month, now.day).add(Duration(days: dayIndex - (now.weekday - 1)));
    final startOfDay = targetDate.millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    return _tasks.where((t) {
      final due = t['dueDateMillis'] as int?;
      if (due == null) return false;
      return due >= startOfDay && due < endOfDay && t['startTimeMinutes'] != null;
    }).toList()
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

  List<Map<String, dynamic>> _getFreeSlotsForDay(int dayIndex) {
    final dayItems = <Map<String, dynamic>>[];
    final classes = _getClassesForDay(dayIndex);
    final tasks = _getTasksForDay(dayIndex);

    for (final c in classes) {
      dayItems.add({
        'start': c['startTimeMinutes'] as int,
        'end': c['endTimeMinutes'] as int,
        'type': 'class',
      });
    }
    for (final t in tasks) {
      dayItems.add({
        'start': t['startTimeMinutes'] as int,
        'end': t['endTimeMinutes'] as int,
        'type': 'task',
      });
    }

    dayItems.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    final freeSlots = <Map<String, dynamic>>[];
    int currentStart = _timelineStartMinutes;

    for (final item in dayItems) {
      final itemStart = item['start'] as int;
      final itemEnd = item['end'] as int;

      if (itemStart > currentStart) {
        final duration = itemStart - currentStart;
        if (duration >= 30) {
          freeSlots.add({
            'start': currentStart,
            'end': itemStart,
            'duration': duration,
          });
        }
      }
      if (itemEnd > currentStart) {
        currentStart = itemEnd;
      }
    }

    if (currentStart < _timelineEndMinutes) {
      final duration = _timelineEndMinutes - currentStart;
      if (duration >= 30) {
        freeSlots.add({
          'start': currentStart,
          'end': _timelineEndMinutes,
          'duration': duration,
        });
      }
    }

    return freeSlots;
  }

  double _minutesToPixels(int minutes) {
    return ((minutes - _timelineStartMinutes) / _totalTimelineMinutes) * (_totalTimelineMinutes / 60.0) * _hourHeight;
  }

  double _durationToPixels(int durationMinutes) {
    return (durationMinutes / 60.0) * _hourHeight;
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayClasses = _getClassesForDay(_selectedDay);
    final dayTasks = _getTasksForDay(_selectedDay);
    final conflicts = _detectConflicts(dayClasses);
    final freeSlots = _getFreeSlotsForDay(_selectedDay);
    final hasAnyItems = dayClasses.isNotEmpty || dayTasks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Timetable'),
        actions: [
          if (freeSlots.isNotEmpty)
            Tooltip(
              message: 'Suggest Study Block',
              child: IconButton(
                icon: const Icon(Icons.auto_fix_high),
                onPressed: _suggestStudyBlock,
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: 'Add',
            onSelected: (value) {
              if (value == 'class') _addClass();
              else if (value == 'task') _addTask();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'class', child: ListTile(leading: Icon(Icons.school), title: Text('Add Class'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'task', child: ListTile(leading: Icon(Icons.assignment), title: Text('Add Task')), contentPadding: EdgeInsets.zero),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Day selector tabs
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final isSelected = _selectedDay == i;
                      final dayClassesCount = _getClassesForDay(i).length;
                      return InkWell(
                        onTap: () => setState(() => _selectedDay = i),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primaryContainer : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayNames[i],
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected ? cs.primary : cs.outline.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$dayClassesCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Conflict warning
                if (conflicts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${conflicts.length} schedule conflict${conflicts.length == 1 ? '' : 's'} on ${_dayNames[_selectedDay]}!',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Free time summary
                if (freeSlots.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.free_breakfast, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '${freeSlots.length} free slot${freeSlots.length == 1 ? '' : 's'} (${freeSlots.fold<int>(0, (sum, s) => sum + (s['duration'] as int)) ~/ 60}h ${freeSlots.fold<int>(0, (sum, s) => sum + (s['duration'] as int)) % 60}m)',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                // Timeline or Empty State
                Expanded(
                  child: !hasAnyItems
                      ? _buildEmptyState(cs)
                      : _buildTimeline(cs, dayClasses, dayTasks, conflicts, freeSlots),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_outlined, size: 72, color: cs.outline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No classes on ${_dayNames[_selectedDay]}',
            style: TextStyle(color: cs.outline, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add a class or task',
            style: TextStyle(color: cs.outline.withOpacity(0.7), fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _addClass,
                icon: const Icon(Icons.school, size: 18),
                label: const Text('Add Class'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.assignment, size: 18),
                label: const Text('Add Task'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    ColorScheme cs,
    List<Map<String, dynamic>> dayClasses,
    List<Map<String, dynamic>> dayTasks,
    List<Map<String, dynamic>> conflicts,
    List<Map<String, dynamic>> freeSlots,
  ) {
    final timelineHeight = (_timelineEndHour - _timelineStartHour) * _hourHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time labels column
            SizedBox(
              width: _timelineWidth,
              child: Column(
                children: List.generate(_timelineEndHour - _timelineStartHour + 1, (i) {
                  final hour = _timelineStartHour + i;
                  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                  final ampm = hour >= 12 ? 'PM' : 'AM';
                  return Container(
                    height: _hourHeight,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: cs.outline.withOpacity(0.15)),
                        right: BorderSide(color: cs.outline.withOpacity(0.2)),
                      ),
                    ),
                    child: Text(
                      '$displayHour $ampm',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Timeline content
            Expanded(
              child: Stack(
                children: [
                  // Hour grid lines
                  Column(
                    children: List.generate(_timelineEndHour - _timelineStartHour + 1, (i) {
                      return Container(
                        height: _hourHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: cs.outline.withOpacity(0.1)),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Current time indicator
                  _buildCurrentTimeIndicator(),

                  // Free time gap labels
                  ...freeSlots.map((slot) => _buildFreeTimeSlot(slot, cs)),

                  // Class blocks
                  ...dayClasses.map((c) => _buildClassBlock(c, conflicts, cs)),

                  // Task blocks
                  ...dayTasks.map((t) => _buildTaskBlock(t, cs)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    if (currentMinutes < _timelineStartMinutes || currentMinutes > _timelineEndMinutes) {
      return const SizedBox.shrink();
    }
    final top = _minutesToPixels(currentMinutes);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.red.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTimeSlot(Map<String, dynamic> slot, ColorScheme cs) {
    final start = slot['start'] as int;
    final end = slot['end'] as int;
    final duration = slot['duration'] as int;
    final top = _minutesToPixels(start);
    final height = _durationToPixels(end - start);

    return Positioned(
      top: top,
      left: 8,
      right: 8,
      height: height,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.2), style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            '${duration ~/ 60}h ${duration % 60}m free',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassBlock(Map<String, dynamic> c, List<Map<String, dynamic>> conflicts, ColorScheme cs) {
    final start = c['startTimeMinutes'] as int;
    final end = c['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = max(40, _durationToPixels(end - start));
    final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');
    final isConflict = conflicts.any((conf) =>
        conf['a']['id'] == c['id'] || conf['b']['id'] == c['id']);

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onLongPress: () => _deleteClass(c['id'] as int),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: isConflict ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isConflict
                ? BorderSide(color: Colors.red, width: 2)
                : BorderSide(color: color.withOpacity(0.3), width: 1),
          ),
          color: color.withOpacity(0.12),
          child: InkWell(
            onTap: () => _showClassDetails(c),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(_typeIcon(c['classType'] as String), size: 14, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c['subjectName'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isConflict)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CONFLICT',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeLabel(c['classType'] as String),
                    style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
                  ),
                  if (height > 50) ...[
                    const Spacer(),
                    if ((c['room'] as String?)?.isNotEmpty == true)
                      Row(
                        children: [
                          Icon(Icons.place, size: 10, color: cs.outline),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              c['room'] as String,
                              style: TextStyle(fontSize: 10, color: cs.outline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if ((c['professor'] as String?)?.isNotEmpty == true)
                      Row(
                        children: [
                          Icon(Icons.person, size: 10, color: cs.outline),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              c['professor'] as String,
                              style: TextStyle(fontSize: 10, color: cs.outline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                  // Time label at bottom
                  if (height > 35)
                    Text(
                      '${_formatMinutes24(start)} - ${_formatMinutes24(end)}',
                      style: TextStyle(fontSize: 9, color: cs.outline.withOpacity(0.7)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskBlock(Map<String, dynamic> t, ColorScheme cs) {
    final start = t['startTimeMinutes'] as int;
    final end = t['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = max(36, _durationToPixels(end - start));
    final typeColor = _typeColor(t['taskType'] as String);
    final isDeadline = t['taskType'] == 'assignment' || t['taskType'] == 'exam';
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onLongPress: () => _deleteTask(t['id'] as int),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isDeadline
                ? BorderSide(color: Colors.red.withOpacity(0.6), width: 1.5)
                : BorderSide(color: typeColor.withOpacity(0.3), width: 1),
          ),
          color: isCompleted ? Colors.grey.withOpacity(0.08) : typeColor.withOpacity(0.08),
          child: InkWell(
            onTap: () => _showTaskDetails(t),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _typeIcon(t['taskType'] as String),
                        size: 12,
                        color: isCompleted ? Colors.grey : typeColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          t['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? Colors.grey : typeColor.withOpacity(0.9),
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDeadline)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DUE',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  if (height > 40 && (t['subjectName'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      t['subjectName'] as String,
                      style: TextStyle(fontSize: 10, color: cs.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (height > 30)
                    Text(
                      '${_formatMinutes24(start)} - ${_formatMinutes24(end)}',
                      style: TextStyle(fontSize: 9, color: cs.outline.withOpacity(0.7)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showClassDetails(Map<String, dynamic> c) {
    final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _typeLabel(c['classType'] as String),
                        style: TextStyle(fontSize: 14, color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.access_time, 'Time', '${_formatMinutes(c['startTimeMinutes'] as int)} - ${_formatMinutes(c['endTimeMinutes'] as int)}'),
            if ((c['room'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.place, 'Room', c['room'] as String),
            if ((c['professor'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.person, 'Professor', c['professor'] as String),
            _detailRow(Icons.calendar_today, 'Day', _dayNames[(c['dayOfWeek'] as int) - 1]),
            _detailRow(Icons.repeat, 'Recurring', (c['isRecurring'] as int? ?? 1) == 1 ? 'Yes (weekly)' : 'No'),
            if ((c['note'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.notes, 'Note', c['note'] as String),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteClass(c['id'] as int);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(Map<String, dynamic> t) {
    final typeColor = _typeColor(t['taskType'] as String);
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;
    final dueDate = DateTime.fromMillisecondsSinceEpoch(t['dueDateMillis'] as int);
    final daysLeft = dueDate.difference(DateTime.now()).inDays;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(t['taskType'] as String), color: typeColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['title'] as String,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _typeLabel(t['taskType'] as String),
                        style: TextStyle(fontSize: 14, color: typeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.calendar_today, 'Due Date', '${dueDate.day}/${dueDate.month}/${dueDate.year}'),
            _detailRow(Icons.hourglass_bottom, 'Days Left',
              daysLeft < 0 ? 'Overdue!' : daysLeft == 0 ? 'Due today!' : '$daysLeft days left',
              valueColor: daysLeft <= 1 ? Colors.red : null,
            ),
            if (t['startTimeMinutes'] != null)
              _detailRow(Icons.access_time, 'Time',
                '${_formatMinutes(t['startTimeMinutes'] as int)} - ${_formatMinutes(t['endTimeMinutes'] as int)}'),
            if ((t['subjectName'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.book, 'Subject', t['subjectName'] as String),
            if ((t['note'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.notes, 'Note', t['note'] as String),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleTaskComplete(t['id'] as int, isCompleted);
                    },
                    icon: Icon(isCompleted ? Icons.check_box_outline_blank : Icons.check_box),
                    label: Text(isCompleted ? 'Mark Incomplete' : 'Mark Complete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteTask(t['id'] as int);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
