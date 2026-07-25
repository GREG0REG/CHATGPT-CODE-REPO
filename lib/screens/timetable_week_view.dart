// FILE: lib/screens/timetable_week_view.dart
// COMPLETE REPLACEMENT — Week Grid View for Timetable

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';
import 'main_screen.dart';

class TimetableWeekView extends StatefulWidget {
  const TimetableWeekView({super.key});

  @override
  State<TimetableWeekView> createState() => _TimetableWeekViewState();
}

class _TimetableWeekViewState extends State<TimetableWeekView> {
  bool _loading = true;
  bool _showWeekend = false;
  int _selectedDay = DateTime.now().weekday - 1;
  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _dayFullNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _tasks = [];

  // Timeline constants
  static const int _timelineStartHour = 7;
  static const int _timelineEndHour = 21;
  static const int _timelineStartMinutes = _timelineStartHour * 60;
  static const int _timelineEndMinutes = _timelineEndHour * 60;
  static const int _totalTimelineMinutes = _timelineEndMinutes - _timelineStartMinutes;
  static const double _hourHeight = 60.0;
  static const double _timeColumnWidth = 52.0;
  static const double _dayColumnWidth = 100.0;

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
      orderBy: 'dayOfWeek ASC, startTimeMinutes ASC',
    );
    setState(() => _classes = rows);
  }

  Future<void> _loadTasks() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfWeek = startOfToday + const Duration(days: 14).inMilliseconds;
    final rows = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ? AND isCompleted = 0',
      whereArgs: [startOfToday - const Duration(days: 1).inMilliseconds, endOfWeek],
      orderBy: 'dueDateMillis ASC',
    );
    setState(() => _tasks = rows);
  }

  // ============================================
  // EDIT CLASS
  // ============================================
  Future<void> _editClass(Map<String, dynamic> existing) async {
    final nameController = TextEditingController(text: existing['subjectName'] as String? ?? '');
    final roomController = TextEditingController(text: existing['room'] as String? ?? '');
    final profController = TextEditingController(text: existing['professor'] as String? ?? '');
    final noteController = TextEditingController(text: existing['note'] as String? ?? '');
    String classType = existing['classType'] as String? ?? 'lecture';
    int startMinutes = existing['startTimeMinutes'] as int? ?? 540;
    int endMinutes = existing['endTimeMinutes'] as int? ?? 600;
    int dayOfWeek = existing['dayOfWeek'] as int? ?? 1;
    bool isRecurring = (existing['isRecurring'] as int? ?? 1) == 1;
    DateTime? startDate = existing['startDateMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(existing['startDateMillis'] as int)
        : null;
    DateTime? endDate = existing['endDateMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(existing['endDateMillis'] as int)
        : null;

    final types = ['lecture', 'lab', 'tutorial', 'seminar', 'exam', 'quiz'];
    final typeLabels = ['Lecture', 'Lab', 'Tutorial', 'Seminar', 'Exam', 'Quiz'];
    final typeColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.red, Colors.orange];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                        startDate != null ? '${startDate.day}/${startDate.month}/${startDate.year}' : 'Not set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.date_range, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
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
                        endDate != null ? '${endDate.day}/${endDate.month}/${endDate.year}' : 'Not set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.date_range, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now().add(const Duration(days: 90)),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
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
      await db.update(
        'timetable_classes',
        {
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
    final daysToShow = _showWeekend ? 7 : 5;
    final timelineHeight = (_timelineEndHour - _timelineStartHour) * _hourHeight;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Week View'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showWeekend = !_showWeekend),
            icon: Icon(_showWeekend ? Icons.calendar_view_week : Icons.calendar_view_day),
            label: Text(_showWeekend ? '5-Day' : '7-Day'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header row with day names
                Container(
                  padding: const EdgeInsets.only(left: _timeColumnWidth),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    border: Border(
                      bottom: BorderSide(color: cs.outline.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: List.generate(daysToShow, (i) {
                      final isToday = DateTime.now().weekday - 1 == i;
                      final dayClasses = _getClassesForDay(i);
                      final hasConflict = _detectConflicts(dayClasses).isNotEmpty;
                      return Container(
                        width: _dayColumnWidth,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isToday ? cs.primaryContainer.withOpacity(0.5) : Colors.transparent,
                          border: Border(
                            right: BorderSide(color: cs.outline.withOpacity(0.1)),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dayNames[i],
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                color: isToday ? cs.onPrimaryContainer : cs.onSurface,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isToday ? cs.primary : cs.outline.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${dayClasses.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isToday ? cs.onPrimary : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasConflict) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                // Grid body
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time labels column
                          SizedBox(
                            width: _timeColumnWidth,
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
                                      fontSize: 10,
                                      color: cs.outline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // Day columns
                          ...List.generate(daysToShow, (dayIndex) {
                            final dayClasses = _getClassesForDay(dayIndex);
                            final dayTasks = _getTasksForDay(dayIndex);
                            final conflicts = _detectConflicts(dayClasses);
                            final isToday = DateTime.now().weekday - 1 == dayIndex;

                            return Container(
                              width: _dayColumnWidth,
                              decoration: BoxDecoration(
                                color: isToday ? cs.primaryContainer.withOpacity(0.08) : Colors.transparent,
                                border: Border(
                                  right: BorderSide(color: cs.outline.withOpacity(0.1)),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Hour grid lines
                                  Column(
                                    children: List.generate(_timelineEndHour - _timelineStartHour + 1, (i) {
                                      return Container(
                                        height: _hourHeight,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: cs.outline.withOpacity(0.08)),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  // Current time indicator (only for today)
                                  if (isToday) _buildCurrentTimeIndicator(),
                                  // Class blocks
                                  ...dayClasses.map((c) => _buildClassBlock(c, conflicts, cs)),
                                  // Task blocks
                                  ...dayTasks.map((t) => _buildTaskBlock(t, cs)),
                                  // Empty state overlay
                                  if (dayClasses.isEmpty && dayTasks.isEmpty)
                                    Positioned.fill(
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.event_busy, size: 32, color: cs.outline.withOpacity(0.3)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'No classes',
                                              style: TextStyle(fontSize: 11, color: cs.outline.withOpacity(0.5)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
            width: 6,
            height: 6,
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

  Widget _buildClassBlock(Map<String, dynamic> c, List<Map<String, dynamic>> conflicts, ColorScheme cs) {
    final start = c['startTimeMinutes'] as int;
    final end = c['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = max(32, _durationToPixels(end - start));
    final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');
    final isConflict = conflicts.any((conf) =>
        conf['a']['id'] == c['id'] || conf['b']['id'] == c['id']);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: () => _editClass(c),
        onLongPress: () => _deleteClass(c['id'] as int),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isConflict ? Colors.red : color.withOpacity(0.5),
              width: isConflict ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(c['classType'] as String), size: 10, color: color),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        c['subjectName'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (height > 28) ...[
                  const SizedBox(height: 1),
                  Text(
                    _typeLabel(c['classType'] as String),
                    style: TextStyle(fontSize: 8, color: color.withOpacity(0.7)),
                  ),
                ],
                if (height > 42 && (c['room'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Icon(Icons.place, size: 8, color: cs.outline),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          c['room'] as String,
                          style: TextStyle(fontSize: 8, color: cs.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (height > 50)
                  Text(
                    '${_formatMinutes24(start)}-${_formatMinutes24(end)}',
                    style: TextStyle(fontSize: 7, color: cs.outline.withOpacity(0.7)),
                  ),
              ],
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
    final height = max(28, _durationToPixels(end - start));
    final typeColor = _typeColor(t['taskType'] as String);
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.grey.withOpacity(0.08) : typeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCompleted ? Colors.grey.withOpacity(0.3) : typeColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _typeIcon(t['taskType'] as String),
                    size: 9,
                    color: isCompleted ? Colors.grey : typeColor,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      t['title'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? Colors.grey : typeColor.withOpacity(0.9),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (height > 30)
                Text(
                  '${_formatMinutes24(start)}-${_formatMinutes24(end)}',
                  style: TextStyle(fontSize: 7, color: cs.outline.withOpacity(0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
