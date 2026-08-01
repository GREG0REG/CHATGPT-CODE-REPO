// FILE: lib/screens/timetable_screen.dart
// COMPLETE REPLACEMENT — Polished NEET Timetable v4.0
// REMOVED: All broken DB features (MCQ, Balance, Mastery, Revision, inline Pomodoro)
// ADDED: Expandable entry drawer, Edit class, Drag-resize, Task display, Pomodoro redirect
// POLISH: Clean UI, proper spacing, consolidated layout

import 'dart:math' as math;
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
  int _selectedDay = DateTime.now().weekday - 1;
  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _weekView = false;

  // Entry drawer state
  bool _showEntryDrawer = false;
  int _entryTab = 0; // 0 = Class, 1 = Task

  // Drag resize state
  int? _draggingClassId;
  bool _draggingTop = false;
  int _dragStartY = 0;
  int _dragOriginalMinutes = 0;

  // Timeline constants
  static const int _timelineStartHour = 5;
  static const int _timelineEndHour = 24;
  static const int _timelineStartMinutes = _timelineStartHour * 60;
  static const int _timelineEndMinutes = _timelineEndHour * 60;
  static const int _totalTimelineMinutes = _timelineEndMinutes - _timelineStartMinutes;
  static const double _hourHeight = 64.0;
  static const double _timelineWidth = 56.0;

  // NEET subjects for quick chips
  static const List<String> _neetSubjects = ['Physics', 'Chemistry', 'Biology', 'Zoology', 'Botany'];
  static const Map<String, String> _neetColors = {
    'Physics': '#1565C0',
    'Chemistry': '#2E7D32',
    'Biology': '#C62828',
    'Zoology': '#C62828',
    'Botany': '#C62828',
  };

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
    final rows = await db.query('timetable_classes', orderBy: 'startTimeMinutes ASC');
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

  // ═══════════════════════════════════════════════════════════════════
  // EDIT CLASS
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _editClass(Map<String, dynamic> existing) async {
    final nameController = TextEditingController(text: existing['subjectName']?.toString() ?? '');
    final roomController = TextEditingController(text: existing['room']?.toString() ?? '');
    final profController = TextEditingController(text: existing['professor']?.toString() ?? '');
    final noteController = TextEditingController(text: existing['note']?.toString() ?? '');
    String classType = existing['classType']?.toString() ?? 'lecture';
    int startMinutes = (existing['startTimeMinutes'] as int?) ?? 540;
    int endMinutes = (existing['endTimeMinutes'] as int?) ?? 600;
    int dayOfWeek = (existing['dayOfWeek'] as int?) ?? 1;
    bool isRecurring = (existing['isRecurring'] as int? ?? 1) == 1;

    final types = ['lecture', 'lab', 'tutorial', 'seminar', 'exam', 'quiz', 'revision'];
    final typeLabels = ['Lecture', 'Lab', 'Tutorial', 'Seminar', 'Exam', 'Quiz', 'Revision'];
    final typeColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.red, Colors.orange, Colors.amber];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final autoColor = _getNeetSubjectColor(nameController.text);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Class'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Subject Name *', prefixIcon: Icon(Icons.book)),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _neetSubjects.map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        nameController.text = s;
                        setDialogState(() {});
                      },
                      backgroundColor: _hexToColor(_neetColors[s] ?? '#2196F3').withOpacity(0.1),
                      side: BorderSide(color: _hexToColor(_neetColors[s] ?? '#2196F3').withOpacity(0.3)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (_isNeetSubject(nameController.text))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _hexToColor(autoColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _hexToColor(autoColor).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 16, height: 16, decoration: BoxDecoration(color: _hexToColor(autoColor), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('Auto color: $autoColor', style: TextStyle(fontSize: 12, color: _hexToColor(autoColor))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: classType,
                    decoration: const InputDecoration(labelText: 'Class Type', prefixIcon: Icon(Icons.category)),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Row(children: [Icon(Icons.circle, color: typeColors[i], size: 12), const SizedBox(width: 8), Text(typeLabels[i])]),
                    )),
                    onChanged: (v) => setDialogState(() => classType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration: const InputDecoration(labelText: 'Day', prefixIcon: Icon(Icons.calendar_today)),
                    items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(_dayNames[i]))),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
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
                            if (endMinutes <= startMinutes) setDialogState(() => endMinutes = startMinutes + 60);
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
                          if (time != null) setDialogState(() => endMinutes = time.hour * 60 + time.minute);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: roomController, decoration: const InputDecoration(labelText: 'Room / Location', prefixIcon: Icon(Icons.place))),
                  const SizedBox(height: 12),
                  TextField(controller: profController, decoration: const InputDecoration(labelText: 'Professor', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recurring Weekly'),
                    value: isRecurring,
                    onChanged: (v) => setDialogState(() => isRecurring = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Subject name is required')));
                    return;
                  }
                  if (endMinutes <= startMinutes) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
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
                  });
                },
                child: const Text('Save'),
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
      final subjectName = result['name'] as String;
      final autoColor = _getNeetSubjectColor(subjectName);

      await db.update(
        'timetable_classes',
        {
          'subjectName': subjectName,
          'classType': result['type'],
          'dayOfWeek': result['day'],
          'startTimeMinutes': result['start'],
          'endTimeMinutes': result['end'],
          'room': result['room'],
          'professor': result['prof'],
          'colorHex': autoColor,
          'isRecurring': (result['isRecurring'] as bool) ? 1 : 0,
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

  // ═══════════════════════════════════════════════════════════════════
  // DRAG RESIZE — Update class time directly
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _updateClassTime(int id, int newStart, int newEnd) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'timetable_classes',
      {'startTimeMinutes': newStart, 'endTimeMinutes': newEnd},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadData();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DELETE
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _deleteClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Class?'),
        content: const Text('This will permanently remove this class from your timetable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
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
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
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
    await db.update('timetable_tasks', {'isCompleted': current ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADD CLASS (from drawer)
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _addClassFromDrawer() async {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final profController = TextEditingController();
    final noteController = TextEditingController();
    String classType = 'lecture';
    int startMinutes = 540;
    int endMinutes = 600;
    int dayOfWeek = _selectedDay + 1;
    bool isRecurring = true;

    final types = ['lecture', 'lab', 'tutorial', 'seminar', 'exam', 'quiz', 'revision'];
    final typeLabels = ['Lecture', 'Lab', 'Tutorial', 'Seminar', 'Exam', 'Quiz', 'Revision'];
    final typeColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.red, Colors.orange, Colors.amber];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final autoColor = _getNeetSubjectColor(nameController.text);
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
                    decoration: const InputDecoration(labelText: 'Subject Name *', prefixIcon: Icon(Icons.book)),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _neetSubjects.map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        nameController.text = s;
                        setDialogState(() {});
                      },
                      backgroundColor: _hexToColor(_neetColors[s] ?? '#2196F3').withOpacity(0.1),
                      side: BorderSide(color: _hexToColor(_neetColors[s] ?? '#2196F3').withOpacity(0.3)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (_isNeetSubject(nameController.text))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _hexToColor(autoColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _hexToColor(autoColor).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 16, height: 16, decoration: BoxDecoration(color: _hexToColor(autoColor), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('Auto color: $autoColor', style: TextStyle(fontSize: 12, color: _hexToColor(autoColor))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: classType,
                    decoration: const InputDecoration(labelText: 'Class Type', prefixIcon: Icon(Icons.category)),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Row(children: [Icon(Icons.circle, color: typeColors[i], size: 12), const SizedBox(width: 8), Text(typeLabels[i])]),
                    )),
                    onChanged: (v) => setDialogState(() => classType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration: const InputDecoration(labelText: 'Day', prefixIcon: Icon(Icons.calendar_today)),
                    items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(_dayNames[i]))),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
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
                            if (endMinutes <= startMinutes) setDialogState(() => endMinutes = startMinutes + 60);
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
                          if (time != null) setDialogState(() => endMinutes = time.hour * 60 + time.minute);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: roomController, decoration: const InputDecoration(labelText: 'Room / Location', prefixIcon: Icon(Icons.place))),
                  const SizedBox(height: 12),
                  TextField(controller: profController, decoration: const InputDecoration(labelText: 'Professor', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recurring Weekly'),
                    value: isRecurring,
                    onChanged: (v) => setDialogState(() => isRecurring = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Subject name is required')));
                    return;
                  }
                  if (endMinutes <= startMinutes) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
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
      final subjectName = result['name'] as String;
      final autoColor = _getNeetSubjectColor(subjectName);

      await db.insert('timetable_classes', {
        'subjectName': subjectName,
        'classType': result['type'],
        'dayOfWeek': result['day'],
        'startTimeMinutes': result['start'],
        'endTimeMinutes': result['end'],
        'room': result['room'],
        'professor': result['prof'],
        'colorHex': autoColor,
        'isRecurring': (result['isRecurring'] as bool) ? 1 : 0,
        'note': result['note'],
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADD TASK (from drawer)
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _addTaskFromDrawer() async {
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
                    items: List.generate(types.length, (i) => DropdownMenuItem(value: types[i], child: Text(typeLabels[i]))),
                    onChanged: (v) => setDialogState(() => taskType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Subject (optional)', prefixIcon: Icon(Icons.book)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _neetSubjects.map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () => subjectController.text = s,
                      backgroundColor: _hexToColor(_neetColors[s] ?? '#2196F3').withOpacity(0.1),
                      side: BorderSide(color: _hexToColor(_neetColors[s] ?? '#2196F3').withOpacity(0.3)),
                    )).toList(),
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
                    Row(children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start', style: TextStyle(fontSize: 12)),
                          subtitle: Text(startTimeMinutes != null ? _formatMinutes(startTimeMinutes!) : 'Not set', style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.access_time, size: 20),
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                            if (time != null) setDialogState(() => startTimeMinutes = time.hour * 60 + time.minute);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('End', style: TextStyle(fontSize: 12)),
                          subtitle: Text(endTimeMinutes != null ? _formatMinutes(endTimeMinutes!) : 'Not set', style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.access_time, size: 20),
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                            if (time != null) setDialogState(() => endTimeMinutes = time.hour * 60 + time.minute);
                          },
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)), maxLines: 2),
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

  // ═══════════════════════════════════════════════════════════════════
  // SUGGEST STUDY BLOCK
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _suggestStudyBlock() async {
    final freeSlots = _getFreeSlotsForDay(_selectedDay);
    if (freeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No free slots available today')));
      return;
    }
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
                        Text('Best free slot found:', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${_formatMinutes(bestSlot['start'] as int)} - ${_formatMinutes(bestSlot['end'] as int)} (${bestSlot['duration']} min)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject *',
                      prefixIcon: const Icon(Icons.book),
                      hintText: 'e.g. Physics, Organic Chemistry',
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (val) { subjectController.text = val; setDialogState(() {}); },
                        itemBuilder: (context) => _neetSubjects.map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duration', prefixIcon: Icon(Icons.timer)),
                    items: [30, 45, 60, 90, 120, 150, 180].map((m) => DropdownMenuItem(value: m, child: Text('$m minutes'))).toList(),
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
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Subject is required')));
                    return;
                  }
                  final endMin = startMinutes + durationMinutes;
                  if (endMin > _timelineEndMinutes) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Study block extends beyond timeline')));
                    return;
                  }
                  Navigator.pop(ctx, {'subject': subjectController.text.trim(), 'start': startMinutes, 'end': endMin});
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
        'note': null,
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study block added!')));
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // POMODORO REDIRECT
  // ═══════════════════════════════════════════════════════════════════
  void _goToPomodoro(String subject, {int? durationMinutes}) {
    Navigator.pushNamed(
      context,
      '/pomodoro',
      arguments: {
        'subject': subject,
        'preset': durationMinutes != null && durationMinutes >= 60 ? 'neetRevision' : 'neetSprint',
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════
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

  String _getNeetSubjectColor(String subjectName) {
    for (final entry in _neetColors.entries) {
      if (subjectName.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
    }
    return '#2196F3';
  }

  bool _isNeetSubject(String subjectName) {
    return _neetSubjects.any((s) => subjectName.toLowerCase().contains(s.toLowerCase()));
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
      final isAllDay = (t['isAllDay'] as int? ?? 0) == 1;
      final hasTime = t['startTimeMinutes'] != null;
      return due >= startOfDay && due < endOfDay && (hasTime || isAllDay);
    }).toList()
      ..sort((a, b) {
        final aTime = a['startTimeMinutes'] as int? ?? 0;
        final bTime = b['startTimeMinutes'] as int? ?? 0;
        return aTime.compareTo(bTime);
      });
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
        if (aStart < bEnd && bStart < aEnd) conflicts.add({'a': a, 'b': b});
      }
    }
    return conflicts;
  }

  List<Map<String, dynamic>> _getFreeSlotsForDay(int dayIndex) {
    final dayItems = <Map<String, dynamic>>[];
    final classes = _getClassesForDay(dayIndex);
    final tasks = _getTasksForDay(dayIndex).where((t) => t['startTimeMinutes'] != null).toList();

    for (final c in classes) {
      dayItems.add({'start': c['startTimeMinutes'] as int, 'end': c['endTimeMinutes'] as int, 'type': 'class'});
    }
    for (final t in tasks) {
      dayItems.add({'start': t['startTimeMinutes'] as int, 'end': t['endTimeMinutes'] as int, 'type': 'task'});
    }
    dayItems.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    final freeSlots = <Map<String, dynamic>>[];
    int currentStart = _timelineStartMinutes;
    for (final item in dayItems) {
      final itemStart = item['start'] as int;
      final itemEnd = item['end'] as int;
      if (itemStart > currentStart) {
        final duration = itemStart - currentStart;
        if (duration >= 30) freeSlots.add({'start': currentStart, 'end': itemStart, 'duration': duration});
      }
      if (itemEnd > currentStart) currentStart = itemEnd;
    }
    if (currentStart < _timelineEndMinutes) {
      final duration = _timelineEndMinutes - currentStart;
      if (duration >= 30) freeSlots.add({'start': currentStart, 'end': _timelineEndMinutes, 'duration': duration});
    }
    return freeSlots;
  }

  double _minutesToPixels(int minutes) {
    return ((minutes - _timelineStartMinutes) / _totalTimelineMinutes) * (_totalTimelineMinutes / 60.0) * _hourHeight;
  }

  double _durationToPixels(int durationMinutes) {
    return (durationMinutes / 60.0) * _hourHeight;
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
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
          IconButton(
            icon: Icon(_weekView ? Icons.view_day : Icons.view_week),
            tooltip: _weekView ? 'Day View' : 'Week View',
            onPressed: () => setState(() => _weekView = !_weekView),
          ),
          if (freeSlots.isNotEmpty && !_weekView)
            Tooltip(
              message: 'Suggest Study Block',
              child: IconButton(icon: const Icon(Icons.auto_fix_high), onPressed: _suggestStudyBlock),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _weekView
              ? _buildWeekView(cs)
              : Column(
                  children: [
                    // Day Selector
                    _buildDaySelector(cs),
                    // Conflict warning
                    if (conflicts.isNotEmpty)
                      _buildConflictBanner(cs, conflicts),
                    // Free time summary
                    if (freeSlots.isNotEmpty)
                      _buildFreeTimeBanner(cs, freeSlots),
                    // All-day tasks
                    ...dayTasks.where((t) => (t['isAllDay'] as int? ?? 0) == 1).map((t) => _buildAllDayTaskBanner(t, cs)),
                    // Timeline or Empty State
                    Expanded(
                      child: !hasAnyItems
                          ? _buildEmptyState(cs)
                          : _buildTimeline(cs, dayClasses, dayTasks, conflicts, freeSlots),
                    ),
                    // Entry Drawer Handle
                    _buildEntryDrawerHandle(cs),
                    // Entry Drawer (expandable)
                    if (_showEntryDrawer) _buildEntryDrawer(cs),
                  ],
                ),
    );
  }

  Widget _buildDaySelector(ColorScheme cs) {
    return Container(
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
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 24,
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
    );
  }

  Widget _buildConflictBanner(ColorScheme cs, List<Map<String, dynamic>> conflicts) {
    return Container(
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
    );
  }

  Widget _buildFreeTimeBanner(ColorScheme cs, List<Map<String, dynamic>> freeSlots) {
    final totalFree = freeSlots.fold<int>(0, (sum, s) => sum + (s['duration'] as int));
    return Container(
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
            '${freeSlots.length} free slot${freeSlots.length == 1 ? '' : 's'} (${totalFree ~/ 60}h ${totalFree % 60}m)',
            style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDayTaskBanner(Map<String, dynamic> t, ColorScheme cs) {
    final typeColor = _typeColor(t['taskType'] as String);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_typeIcon(t['taskType'] as String), size: 16, color: typeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'All-day: ${t['title']}',
              style: TextStyle(fontSize: 12, color: typeColor.withOpacity(0.9), fontWeight: FontWeight.w600),
            ),
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
            'Tap the arrow below to add a class or task',
            style: TextStyle(color: cs.outline.withOpacity(0.7), fontSize: 13),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time labels
            SizedBox(
              width: _timelineWidth,
              child: Column(
                children: List.generate(_timelineEndHour - _timelineStartHour + 1, (i) {
                  final hour = _timelineStartHour + i;
                  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                  final ampm = hour >= 12 ? 'PM' : 'AM';
                  final labelHour = hour == 24 ? 12 : displayHour;
                  final labelAmpm = hour == 24 ? 'AM' : ampm;
                  return Container(
                    height: _hourHeight,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 4, right: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: cs.outline.withOpacity(0.15)),
                        right: BorderSide(color: cs.outline.withOpacity(0.2)),
                      ),
                    ),
                    child: Text(
                      '$labelHour $labelAmpm',
                      style: TextStyle(fontSize: 10, color: cs.outline, fontWeight: FontWeight.w500),
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
                          border: Border(top: BorderSide(color: cs.outline.withOpacity(0.1))),
                        ),
                      );
                    }),
                  ),
                  // Current time indicator
                  _buildCurrentTimeIndicator(),
                  // Free time slots
                  ...freeSlots.map((slot) => _buildFreeTimeSlot(slot, cs)),
                  // Class blocks
                  ...dayClasses.map((c) => _buildClassBlock(c, conflicts, cs)),
                  // Task blocks (timed only)
                  ...dayTasks.where((t) => t['startTimeMinutes'] != null).map((t) => _buildTaskBlock(t, cs)),
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
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          Expanded(child: Container(height: 2, color: Colors.red.withOpacity(0.5))),
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
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            '${duration ~/ 60}h ${duration % 60}m free',
            style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CLASS BLOCK — with Edit, Drag Resize, and Pomodoro Redirect
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildClassBlock(Map<String, dynamic> c, List<Map<String, dynamic>> conflicts, ColorScheme cs) {
    final start = c['startTimeMinutes'] as int;
    final end = c['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = math.max(48.0, _durationToPixels(end - start));
    final storedColor = c['colorHex'] as String? ?? '#2196F3';
    final color = _hexToColor(storedColor);
    final isConflict = conflicts.any((conf) => conf['a']['id'] == c['id'] || conf['b']['id'] == c['id']);
    final subject = c['subjectName'] as String? ?? '';
    final duration = end - start;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isConflict ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isConflict
              ? const BorderSide(color: Colors.red, width: 2)
              : BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
        color: color.withOpacity(0.12),
        child: Column(
          children: [
            // Top drag handle
            GestureDetector(
              onVerticalDragStart: (_) {
                setState(() {
                  _draggingClassId = c['id'] as int;
                  _draggingTop = true;
                  _dragOriginalMinutes = start;
                });
              },
              onVerticalDragUpdate: (details) {
                if (_draggingClassId != c['id']) return;
                final deltaPixels = details.delta.dy;
                final deltaMinutes = (deltaPixels / _hourHeight * 60).round();
                final newStart = (_dragOriginalMinutes + deltaMinutes).clamp(_timelineStartMinutes, end - 30);
                if ((newStart - start).abs() >= 15) {
                  _updateClassTime(c['id'] as int, newStart, end);
                }
              },
              onVerticalDragEnd: (_) => setState(() => _draggingClassId = null),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Center(
                  child: Container(width: 20, height: 3, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
                ),
              ),
            ),
            // Content
            Expanded(
              child: InkWell(
                onTap: () => _editClass(c),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              subject,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isConflict)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                              child: const Text('CONFLICT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_typeLabel(c['classType'] as String), style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
                      const Spacer(),
                      Row(
                        children: [
                          if ((c['room'] as String?)?.isNotEmpty == true)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.place, size: 10, color: cs.outline),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(c['room'] as String, style: TextStyle(fontSize: 10, color: cs.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          // Pomodoro redirect button
                          if (_isNeetSubject(subject) && height > 50)
                            InkWell(
                              onTap: () => _goToPomodoro(subject, durationMinutes: duration),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer, size: 10, color: Colors.deepPurple.shade700),
                                    const SizedBox(width: 2),
                                    Text('25m', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text('${_formatMinutes24(start)} - ${_formatMinutes24(end)}', style: TextStyle(fontSize: 9, color: cs.outline.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom drag handle
            GestureDetector(
              onVerticalDragStart: (_) {
                setState(() {
                  _draggingClassId = c['id'] as int;
                  _draggingTop = false;
                  _dragOriginalMinutes = end;
                });
              },
              onVerticalDragUpdate: (details) {
                if (_draggingClassId != c['id']) return;
                final deltaPixels = details.delta.dy;
                final deltaMinutes = (deltaPixels / _hourHeight * 60).round();
                final newEnd = (_dragOriginalMinutes + deltaMinutes).clamp(start + 30, _timelineEndMinutes);
                if ((newEnd - end).abs() >= 15) {
                  _updateClassTime(c['id'] as int, start, newEnd);
                }
              },
              onVerticalDragEnd: (_) => setState(() => _draggingClassId = null),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Center(
                  child: Container(width: 20, height: 3, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TASK BLOCK — Dashed border, distinct from classes
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTaskBlock(Map<String, dynamic> t, ColorScheme cs) {
    final start = t['startTimeMinutes'] as int;
    final end = t['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = math.max(36.0, _durationToPixels(end - start));
    final typeColor = _typeColor(t['taskType'] as String);
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;
    final subject = t['subjectName'] as String? ?? '';
    final isStudyBlock = t['taskType'] == 'study_block';

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isCompleted ? Colors.grey.withOpacity(0.4) : typeColor.withOpacity(0.5),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        color: isCompleted ? Colors.grey.withOpacity(0.05) : typeColor.withOpacity(0.06),
        child: InkWell(
          onTap: () => _showTaskDetails(t),
          onLongPress: () => _deleteTask(t['id'] as int),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(t['taskType'] as String), size: 12, color: isCompleted ? Colors.grey : typeColor),
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
                    if (isStudyBlock && height > 40)
                      InkWell(
                        onTap: () => _goToPomodoro(subject.isNotEmpty ? subject : 'Study'),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, size: 10, color: Colors.deepPurple.shade700),
                              const SizedBox(width: 2),
                              Text('Start', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (height > 30)
                  Text('${_formatMinutes24(start)} - ${_formatMinutes24(end)}', style: TextStyle(fontSize: 9, color: cs.outline.withOpacity(0.7))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTRY DRAWER HANDLE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEntryDrawerHandle(ColorScheme cs) {
    return GestureDetector(
      onTap: () => setState(() => _showEntryDrawer = !_showEntryDrawer),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          border: Border(top: BorderSide(color: cs.outline.withOpacity(0.2))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: _showEntryDrawer ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_up, color: cs.outline),
            ),
            Text(
              _showEntryDrawer ? 'Tap to close' : 'Add Class or Task',
              style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTRY DRAWER — Expandable panel with Class/Task tabs
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEntryDrawer(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withOpacity(0.2))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _entryTab = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _entryTab == 0 ? cs.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school, size: 18, color: _entryTab == 0 ? cs.onPrimaryContainer : cs.outline),
                            const SizedBox(width: 8),
                            Text('Add Class', style: TextStyle(fontWeight: _entryTab == 0 ? FontWeight.bold : FontWeight.w500, color: _entryTab == 0 ? cs.onPrimaryContainer : cs.outline)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _entryTab = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _entryTab == 1 ? cs.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment, size: 18, color: _entryTab == 1 ? cs.onPrimaryContainer : cs.outline),
                            const SizedBox(width: 8),
                            Text('Add Task', style: TextStyle(fontWeight: _entryTab == 1 ? FontWeight.bold : FontWeight.w500, color: _entryTab == 1 ? cs.onPrimaryContainer : cs.outline)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_entryTab == 0) {
                        _addClassFromDrawer();
                      } else {
                        _addTaskFromDrawer();
                      }
                    },
                    icon: Icon(_entryTab == 0 ? Icons.school : Icons.assignment),
                    label: Text(_entryTab == 0 ? 'Add New Class' : 'Add New Task'),
                  ),
                ),
              ],
            ),
                        const SizedBox(height: 8),
            if (_entryTab == 0)
              OutlinedButton.icon(
                onPressed: _suggestStudyBlock,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Suggest Study Block'),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TASK DETAILS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════
  void _showTaskDetails(Map<String, dynamic> t) {
    final typeColor = _typeColor(t['taskType'] as String);
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;
    final dueDate = DateTime.fromMillisecondsSinceEpoch(t['dueDateMillis'] as int);
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    final subject = t['subjectName'] as String? ?? '';
    final isStudyBlock = t['taskType'] == 'study_block';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_typeIcon(t['taskType'] as String), color: typeColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_typeLabel(t['taskType'] as String), style: TextStyle(fontSize: 14, color: typeColor)),
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
              _detailRow(Icons.access_time, 'Time', '${_formatMinutes(t['startTimeMinutes'] as int)} - ${_formatMinutes(t['endTimeMinutes'] as int)}'),
            if ((t['subjectName'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.book, 'Subject', t['subjectName'] as String),
            if ((t['note'] as String?)?.isNotEmpty == true)
              _detailRow(Icons.notes, 'Note', t['note'] as String),
            const SizedBox(height: 16),
            if (isStudyBlock)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _goToPomodoro(subject.isNotEmpty ? subject : 'Study');
                },
                icon: const Icon(Icons.timer),
                label: const Text('Start Pomodoro'),
                style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple, minimumSize: const Size(double.infinity, 48)),
              ),
            const SizedBox(height: 8),
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
          Text('$label: ', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // WEEK VIEW
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildWeekView(ColorScheme cs) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 7,
      itemBuilder: (context, dayIndex) {
        final dayDate = weekStart.add(Duration(days: dayIndex));
        final dayClasses = _getClassesForDay(dayIndex);
        final dayTasks = _getTasksForDay(dayIndex).where((t) => t['startTimeMinutes'] != null).toList();
        final isToday = dayIndex == (now.weekday - 1);
        final conflicts = _detectConflicts(dayClasses);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: isToday ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isToday ? cs.primary : cs.outlineVariant.withOpacity(0.3), width: isToday ? 2 : 1),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedDay = dayIndex;
                _weekView = false;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: isToday ? cs.primary : cs.outline, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('${_dayNames[dayIndex]} ${dayDate.day}/${dayDate.month}', style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.w600, color: isToday ? cs.primary : cs.onSurface)),
                      const Spacer(),
                      if (conflicts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(width: 8),
                      Text('${dayClasses.length + dayTasks.length} items', style: TextStyle(fontSize: 12, color: cs.outline)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (dayClasses.isEmpty && dayTasks.isEmpty)
                    Text('No classes or tasks', style: TextStyle(fontSize: 13, color: cs.outline.withOpacity(0.7)))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...dayClasses.map((c) {
                          final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
                            child: Text('${c['subjectName']} • ${_formatMinutes24(c['startTimeMinutes'] as int)}', style: TextStyle(fontSize: 11, color: color.withOpacity(0.9), fontWeight: FontWeight.w500)),
                          );
                        }),
                        ...dayTasks.map((t) {
                          final color = _typeColor(t['taskType'] as String);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
                            child: Text(t['title'] as String, style: TextStyle(fontSize: 11, color: color.withOpacity(0.9), fontWeight: FontWeight.w500)),
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
