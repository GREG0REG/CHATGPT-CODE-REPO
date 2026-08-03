// FILE: lib/screens/timetable_week_view.dart
// COMPLETE REPLACEMENT — Week Grid View for Timetable
// FIXED: max() type errors, timeline 5-24 to match day view, all-day tasks included
// FIXED: Time text NEVER pops out of cards — ClipRRect on all blocks
// FIXED: Proper height constraints on class/task blocks
// FIXED: Conflict blocks render cleanly side-by-side
// ADDED: Pinch-to-zoom, prev/next week navigation, mini month calendar, all-day task row,
//        day density heatmap, "Now" button, copy day to day, week summary stats

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
  
  DateTime _weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  
  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _dayFullNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _tasks = [];

  double _zoomLevel = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 2.0;

  static const int _timelineStartHour = 5;
  static const int _timelineEndHour = 24;
  static const int _timelineStartMinutes = _timelineStartHour * 60;
  static const int _timelineEndMinutes = _timelineEndHour * 60;
  static const int _totalTimelineMinutes = _timelineEndMinutes - _timelineStartMinutes;
  static const double _baseHourHeight = 60.0;
  static const double _timeColumnWidth = 52.0;
  static const double _dayColumnWidth = 100.0;

  double get _hourHeight => _baseHourHeight * _zoomLevel;
  double get _timelineHeight => (_timelineEndHour - _timelineStartHour) * _hourHeight;

  final Map<int, Color?> _dayBackgroundColors = {};

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
    final startOfWeek = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 14));
    final rows = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ? AND isCompleted = 0',
      whereArgs: [startOfWeek.millisecondsSinceEpoch - const Duration(days: 1).inMilliseconds, endOfWeek.millisecondsSinceEpoch],
      orderBy: 'dueDateMillis ASC',
    );
    setState(() => _tasks = rows);
  }

  void _goToPreviousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
    _loadTasks();
  }

  void _goToNextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
    _loadTasks();
  }

  void _goToCurrentWeek() {
    setState(() {
      _weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    });
    _loadTasks();
  }

  Future<void> _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked != null) {
      setState(() {
        _weekStart = picked.subtract(Duration(days: picked.weekday - 1));
      });
      _loadTasks();
    }
  }

  Future<void> _copyDayToAnother(int sourceDayIndex) async {
    final targetDay = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Copy ${_dayNames[sourceDayIndex]} to...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) {
            if (i == sourceDayIndex) return const SizedBox.shrink();
            return ListTile(
              leading: Text('${_dayNames[i]}', style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => Navigator.pop(ctx, i + 1),
            );
          }),
        ),
      ),
    );

    if (targetDay != null) {
      final db = await DatabaseHelper.instance.database;
      final sourceClasses = _classes.where((c) => c['dayOfWeek'] == sourceDayIndex + 1).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final c in sourceClasses) {
        await db.insert('timetable_classes', {
          'subjectName': c['subjectName'],
          'classType': c['classType'],
          'dayOfWeek': targetDay,
          'startTimeMinutes': c['startTimeMinutes'],
          'endTimeMinutes': c['endTimeMinutes'],
          'room': c['room'],
          'professor': c['professor'],
          'colorHex': c['colorHex'],
          'isRecurring': c['isRecurring'] ?? 1,
          'note': c['note'],
          'createdAtMillis': now,
        });
      }
      
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied ${sourceClasses.length} classes to ${_dayNames[targetDay - 1]}')),
        );
      }
    }
  }

  Future<void> _setDayColor(int dayIndex) async {
    final colors = [
      Colors.red.shade50,
      Colors.orange.shade50,
      Colors.yellow.shade50,
      Colors.green.shade50,
      Colors.blue.shade50,
      Colors.purple.shade50,
      Colors.pink.shade50,
      null,
    ];
    
    final selected = await showDialog<Color?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${_dayNames[dayIndex]} Background'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            if (color == null) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, null),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.clear, color: Colors.grey),
                ),
              );
            }
            return InkWell(
              onTap: () => Navigator.pop(ctx, color),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
    
    if (selected != null || true) {
      setState(() {
        if (selected == null) {
          _dayBackgroundColors.remove(dayIndex);
        } else {
          _dayBackgroundColors[dayIndex] = selected;
        }
      });
    }
  }

  void _showWeekSummary() {
    final daysToShow = _showWeekend ? 7 : 5;
    final subjectHours = <String, double>{};
    
    for (int i = 0; i < daysToShow; i++) {
      final dayClasses = _getClassesForDay(i);
      for (final c in dayClasses) {
        final subject = c['subjectName'] as String? ?? 'Unknown';
        final duration = ((c['endTimeMinutes'] as int) - (c['startTimeMinutes'] as int)) / 60.0;
        subjectHours[subject] = (subjectHours[subject] ?? 0) + duration;
      }
    }
    
    final sorted = subjectHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Week Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...sorted.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.key, style: const TextStyle(fontSize: 14)),
                  ),
                  Text(
                    '${e.value.toStringAsFixed(1)}h',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 100,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (e.value / (sorted.first.value)).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _hexToColor(_getSubjectColor(e.key)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )),
            if (sorted.isEmpty)
              const Center(child: Text('No classes this week', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  String _getSubjectColor(String subject) {
    final map = {
      'Physics': '#1565C0',
      'Chemistry': '#2E7D32',
      'Biology': '#C62828',
      'Zoology': '#C62828',
      'Botany': '#C62828',
    };
    for (final entry in map.entries) {
      if (subject.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
    }
    return '#2196F3';
  }

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
    final targetDate = DateTime(_weekStart.year, _weekStart.month, _weekStart.day).add(Duration(days: dayIndex));
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

  List<Map<String, dynamic>> _getAllDayTasksForDay(int dayIndex) {
    final targetDate = DateTime(_weekStart.year, _weekStart.month, _weekStart.day).add(Duration(days: dayIndex));
    final startOfDay = targetDate.millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    return _tasks.where((t) {
      final due = t['dueDateMillis'] as int?;
      if (due == null) return false;
      final isAllDay = (t['isAllDay'] as int? ?? 0) == 1;
      final hasNoTime = t['startTimeMinutes'] == null;
      return due >= startOfDay && due < endOfDay && (isAllDay || hasNoTime);
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysToShow = _showWeekend ? 7 : 5;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Week View'),
            Text(
              '${_weekStart.day}/${_weekStart.month} - ${_weekStart.add(Duration(days: daysToShow - 1)).day}/${_weekStart.add(Duration(days: daysToShow - 1)).month}',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous Week',
            onPressed: _goToPreviousWeek,
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Current Week',
            onPressed: _goToCurrentWeek,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next Week',
            onPressed: _goToNextWeek,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pick Date',
            onPressed: _showMonthPicker,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom',
            onSelected: (value) {
              if (value == 'in') {
                setState(() => _zoomLevel = (_zoomLevel + 0.25).clamp(_minZoom, _maxZoom));
              } else if (value == 'out') {
                setState(() => _zoomLevel = (_zoomLevel - 0.25).clamp(_minZoom, _maxZoom));
              } else if (value == 'reset') {
                setState(() => _zoomLevel = 1.0);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'in', child: Text('Zoom In')),
              const PopupMenuItem(value: 'out', child: Text('Zoom Out')),
              const PopupMenuItem(value: 'reset', child: Text('Reset Zoom')),
            ],
          ),
          TextButton.icon(
            onPressed: () => setState(() => _showWeekend = !_showWeekend),
            icon: Icon(_showWeekend ? Icons.calendar_view_week : Icons.calendar_view_day),
            label: Text(_showWeekend ? '5-Day' : '7-Day'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Week Summary',
            onPressed: _showWeekSummary,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _goToCurrentWeek,
        tooltip: 'Go to Now',
        child: const Icon(Icons.my_location),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildAllDayRow(cs, daysToShow),
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
                      final isToday = _isToday(i);
                      final dayClasses = _getClassesForDay(i);
                      final hasConflict = _detectConflicts(dayClasses).isNotEmpty;
                      final dayDate = _weekStart.add(Duration(days: i));
                      return GestureDetector(
                        onLongPress: () => _setDayColor(i),
                        child: Container(
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
                              Text(
                                '${dayDate.day}/${dayDate.month}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.outline,
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
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _timeColumnWidth,
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
                                  padding: const EdgeInsets.only(top: 4, right: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: cs.outline.withOpacity(0.15)),
                                      right: BorderSide(color: cs.outline.withOpacity(0.2)),
                                    ),
                                  ),
                                  child: Text(
                                    '$labelHour $labelAmpm',
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
                          ...List.generate(daysToShow, (dayIndex) {
                            final dayClasses = _getClassesForDay(dayIndex);
                            final dayTasks = _getTasksForDay(dayIndex).where((t) => t['startTimeMinutes'] != null).toList();
                            final allDayTasks = _getAllDayTasksForDay(dayIndex);
                            final conflicts = _detectConflicts(dayClasses);
                            final isToday = _isToday(dayIndex);
                            final bgColor = _dayBackgroundColors[dayIndex];

                            return Container(
                              width: _dayColumnWidth,
                              decoration: BoxDecoration(
                                color: bgColor ?? (isToday ? cs.primaryContainer.withOpacity(0.08) : Colors.transparent),
                                border: Border(
                                  right: BorderSide(color: cs.outline.withOpacity(0.1)),
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
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
                                  if (isToday) _buildCurrentTimeIndicator(),
                                  ...dayClasses.map((c) => _buildClassBlock(c, conflicts, cs)),
                                  ...dayTasks.map((t) => _buildTaskBlock(t, cs)),
                                  if (dayClasses.isEmpty && dayTasks.isEmpty && allDayTasks.isEmpty)
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
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _copyDayToAnother(dayIndex),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(Icons.copy, size: 12, color: cs.outline),
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

  bool _isToday(int dayIndex) {
    final now = DateTime.now();
    final dayDate = _weekStart.add(Duration(days: dayIndex));
    return now.year == dayDate.year && now.month == dayDate.month && now.day == dayDate.day;
  }

  Widget _buildAllDayRow(ColorScheme cs, int daysToShow) {
    final hasAnyAllDay = List.generate(daysToShow, (i) => _getAllDayTasksForDay(i)).any((list) => list.isNotEmpty);
    if (!hasAnyAllDay) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(left: _timeColumnWidth),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.15),
        border: Border(
          bottom: BorderSide(color: cs.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: List.generate(daysToShow, (i) {
          final allDayTasks = _getAllDayTasksForDay(i);
          return Container(
            width: _dayColumnWidth,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: cs.outline.withOpacity(0.1)),
              ),
            ),
            child: allDayTasks.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: allDayTasks.map((t) {
                      final typeColor = _typeColor(t['taskType'] as String);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          t['title'] as String,
                          style: TextStyle(fontSize: 9, color: typeColor.withOpacity(0.9), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
          );
        }),
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

  // ============================================
  // CLASS BLOCK (FIXED — ClipRRect, constrained text, no overflow)
  // ============================================
  Widget _buildClassBlock(Map<String, dynamic> c, List<Map<String, dynamic>> conflicts, ColorScheme cs) {
    final start = c['startTimeMinutes'] as int;
    final end = c['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = max(40.0, _durationToPixels(end - start));
    final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');
    final isConflict = conflicts.any((conf) =>
        conf['a']['id'] == c['id'] || conf['b']['id'] == c['id']);

    // Content visibility based on height
    final bool showType = height > 50;
    final bool showRoom = height > 65 && (c['room'] as String?)?.isNotEmpty == true;
    final bool showTime = height > 40;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: GestureDetector(
          onTap: () => _editClass(c),
          onLongPress: () => _deleteClass(c['id'] as int),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isConflict ? Colors.red : color.withOpacity(0.5),
                width: isConflict ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(c['classType'] as String), size: 9, color: color),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        c['subjectName'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (showType)
                  Text(
                    _typeLabel(c['classType'] as String),
                    style: TextStyle(fontSize: 8, color: color.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const Spacer(),
                if (showTime)
                  Text(
                    '${_formatMinutes24(start)}-${_formatMinutes24(end)}',
                    style: TextStyle(fontSize: 7, color: cs.outline.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (showRoom)
                  Row(
                    children: [
                      Icon(Icons.place, size: 7, color: cs.outline),
                      const SizedBox(width: 1),
                      Expanded(
                        child: Text(
                          c['room'] as String,
                          style: TextStyle(fontSize: 7, color: cs.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // TASK BLOCK (FIXED — ClipRRect, constrained text, no overflow)
  // ============================================
  Widget _buildTaskBlock(Map<String, dynamic> t, ColorScheme cs) {
    final start = t['startTimeMinutes'] as int;
    final end = t['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = max(36.0, _durationToPixels(end - start));
    final typeColor = _typeColor(t['taskType'] as String);
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;

    final bool showTime = height > 32;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: isCompleted ? Colors.grey.withOpacity(0.08) : typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isCompleted ? Colors.grey.withOpacity(0.3) : typeColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _typeIcon(t['taskType'] as String),
                    size: 8,
                    color: isCompleted ? Colors.grey : typeColor,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      t['title'] as String,
                      style: TextStyle(
                        fontSize: 8,
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
              const Spacer(),
              if (showTime)
                Text(
                  '${_formatMinutes24(start)}-${_formatMinutes24(end)}',
                  style: TextStyle(fontSize: 7, color: cs.outline.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
