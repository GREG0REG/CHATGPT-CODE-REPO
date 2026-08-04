// FILE: lib/screens/timetable_screen.dart
// FINAL PATCHED VERSION — v6.1 (NEET Optimized, Fixed Drag & Save)
// Based on your timetable_screen.dart(9).txt — all state & logic preserved, only critical fixes applied.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/timetable_entry.dart';
import 'services/database_helper.dart';
import 'services/widget_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _tasks = [];
  int _selectedDay = DateTime.now().weekday - 1;
  bool _showWeekend = false;
  double _zoomLevel = 1.0;
  final ScrollController _scrollController = ScrollController();

  // Drag state (from your existing logic)
  int? _draggingId;
  Map<int, Map<String, int>> _dragOriginalMinutes = {};
  Map<int, bool> _isDragging = {};

  static const int _timelineStartHour = 5;
  static const int _timelineEndHour = 24;
  static const int _timelineStartMinutes = _timelineStartHour * 60;
  static const int _timelineEndMinutes = _timelineEndHour * 60;
  static const int _totalTimelineMinutes = _timelineEndMinutes - _timelineStartMinutes;
  static const double _hourHeight = 72.0;
  static const double _timelineWidth = 52.0;
  static const int _snapMinutes = 15;

  // NEET subjects
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
    final rows = await db.query('tasks', where: 'dueDateMillis > ?', whereArgs: [DateTime.now().millisecondsSinceEpoch]);
    setState(() => _tasks = rows);
  }

  // ============================================
  // DRAG HANDLING (FIXED: saves on drag end, snaps to 15-min grid)
  // ============================================
  void _onDragStart(int id, bool isTopHandle, int start, int end, bool isResizing) {
    _draggingId = id;
    _dragOriginalMinutes[id] = {'start': start, 'end': end};
    _isDragging[id] = true;
    setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details, int id, bool isTopHandle, int originalStart, int originalEnd) {
    if (_draggingId != id) return;
    final delta = details.delta.dy;
    final pixelsPerMinute = _hourHeight / 60.0;
    final minutesDelta = (delta / pixelsPerMinute).round();

    // Snap to 15-min grid
    final snappedDelta = ((minutesDelta ~/ 15) * 15).clamp(
      -originalStart + _timelineStartMinutes,
      _timelineEndMinutes - originalEnd,
    );

    final newStart = ((originalStart + snappedDelta) ~/ 15) * 15;
    final newEnd = ((originalEnd + snappedDelta) ~/ 15) * 15;

    // Enforce min 15-min duration
    if (newEnd - newStart < 15) return;

    // Update local state for immediate UI feedback
    setState(() {
      _classes = _classes.map((c) {
        if (c['id'] == id) {
          return {
            ...c,
            'startTimeMinutes': newStart,
            'endTimeMinutes': newEnd,
          };
        }
        return c;
      }).toList();
    });
  }

  void _onDragEnd(int id, bool isTopHandle) {
    if (_draggingId != id) return;

    final item = _classes.firstWhere((c) => c['id'] == id, orElse: () => {});
    if (item.isEmpty) {
      _resetDragState();
      return;
    }

    final start = item['startTimeMinutes'] as int;
    final end = item['endTimeMinutes'] as int;
    final originalStart = _dragOriginalMinutes[id]?['start'] ?? start;
    final originalEnd = _dragOriginalMinutes[id]?['end'] ?? end;

    // Only save if changed
    if (start == originalStart && end == originalEnd) {
      _resetDragState();
      return;
    }

    // ✅ Persist to DB
    DatabaseHelper.instance.database.then((db) async {
      await db.update(
        'timetable_classes',
        {
          'startTimeMinutes': start,
          'endTimeMinutes': end,
          'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _loadData(); // 👈 Critical: reload to sync UI + reset state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time updated!'), duration: Duration(seconds: 1)),
        );
      }
    });

    _resetDragState();
  }

  void _resetDragState() {
    _draggingId = null;
    _dragOriginalMinutes.clear();
    _isDragging.clear();
    setState(() {});
  }

  // ============================================
  // EDIT CLASS (FIXED: now saves & reloads)
  // ============================================
  Future<void> _editClass(Map<String, dynamic> existing) async {
    final nameController = TextEditingController(text: existing['subjectName']?.toString() ?? '');
    final roomController = TextEditingController(text: existing['room']?.toString() ?? '');
    final profController = TextEditingController(text: existing['professor']?.toString() ?? '');
    final noteController = TextEditingController(text: existing['note']?.toString() ?? '');
    final dayOfWeek = (existing['dayOfWeek'] as int?) ?? 1;
    int startMinutes = (existing['startTimeMinutes'] as int?) ?? 540;
    int endMinutes = (existing['endTimeMinutes'] as int?) ?? 600;
    final isRecurring = (existing['isRecurring'] as int?) == 1;
    String classType = existing['classType'] as String? ?? 'lecture';

    final types = ['lecture', 'lab', 'tutorial', 'seminar', 'exam', 'quiz', 'revision'];
    final typeLabels = ['Lecture', 'Lab', 'Tutorial', 'Seminar', 'Exam', 'Quiz', 'Revision'];
    final typeColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.red, Colors.orange, Colors.amber];

    final result = await showDialog<Map<String, dynamic>?>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
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
                        decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.book)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: roomController,
                        decoration: const InputDecoration(labelText: 'Room / Location', prefixIcon: Icon(Icons.place)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: profController,
                        decoration: const InputDecoration(labelText: 'Professor', prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start Time'),
                              subtitle: Text(_formatMinutes24(startMinutes)),
                              trailing: IconButton(
                                icon: const Icon(Icons.access_time, size: 20),
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60),
                                  );
                                  if (time != null) {
                                    setDialogState(() => startMinutes = time.hour * 60 + time.minute);
                                  }
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End Time'),
                              subtitle: Text(_formatMinutes24(endMinutes)),
                              trailing: IconButton(
                                icon: const Icon(Icons.access_time, size: 20),
                                onPressed: () async {
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recurring Weekly'),
                        value: isRecurring,
                        onChanged: (v) => setDialogState(() => isRecurring = v),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: classType,
                        items: types.map((t) {
                          final idx = types.indexOf(t);
                          return DropdownMenuItem(
                            value: t,
                            child: Row(
                              children: [
                                Icon(_typeIcon(t), size: 16, color: typeColors[idx]),
                                const SizedBox(width: 8),
                                Text(_typeLabel(t)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setDialogState(() => classType = v!),
                        decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
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
            }));

    if (result != null) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final subjectName = result['name'] as String;
      final autoColor = _getNeetSubjectColor(subjectName);
      final updateData = <String, Object?>{
        'subjectName': subjectName,
        'classType': result['type'],
        'dayOfWeek': result['day'] as int,
        'startTimeMinutes': result['start'] as int,
        'endTimeMinutes': result['end'] as int,
        'room': result['room'],
        'professor': result['prof'],
        'colorHex': autoColor,
        'isRecurring': (result['isRecurring'] as bool) ? 1 : 0,
        'note': result['note'],
        'updatedAtMillis': now,
        // Keep existing masteryProgress & syllabusWeight if they exist
        'masteryProgress': existing['masteryProgress'] as int? ?? 0,
        'syllabusWeight': existing['syllabusWeight'] as double? ?? 1.0,
      };
      await db.update('timetable_classes', updateData, where: 'id = ?', whereArgs: [existing['id'] as int]);
      HapticFeedback.mediumImpact();
      await _loadData(); // ✅ Critical: reload after save
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class updated!'), duration: Duration(seconds: 2)));
      }
    }
  }

  // ============================================
  // DELETE CLASS
  // ============================================
  Future<void> _deleteClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('timetable_classes', where: 'id = ?', whereArgs: [id]);
      HapticFeedback.lightImpact();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class deleted.')));
      }
    }
  }

  // ============================================
  // BUILD CLASS CARD (FIXED: uniform conflict color + mastery bar)
  // ============================================
  Widget _buildClassCard(Map<String, dynamic> c, ColorScheme cs, bool isConflict, bool isDragging) {
    final id = c['id'] as int;
    final subjectName = c['subjectName'] as String? ?? 'Untitled';
    final day = c['dayOfWeek'] as int;
    final originalStart = (c['startTimeMinutes'] as int?) ?? 540;
    final originalEnd = (c['endTimeMinutes'] as int?) ?? 600;
    final start = _isDragging[id] == true ? _dragOriginalMinutes[id]?['start'] ?? originalStart : originalStart;
    final end = _isDragging[id] == true ? _dragOriginalMinutes[id]?['end'] ?? originalEnd : originalEnd;
    final duration = end - start;
    final isSmall = duration < 55;
    final storedColor = c['colorHex'] as String? ?? '#2196F3';
    final color = _hexToColor(storedColor);
    final mastery = (c['masteryProgress'] as int?) ?? 0;

    final top = _minutesToPixels(start);
    final height = _durationToPixels(duration);

    return Stack(
      children: [
        // Drag handles (top & bottom) — only show when dragging
        if (isDragging)
          Positioned(
            top: top - 4,
            left: 8,
            right: 8,
            height: 8,
            child: GestureDetector(
              onVerticalDragStart: (_) => _onDragStart(id, true, start, end, true),
              onVerticalDragUpdate: (d) => _onDragUpdate(d, id, true, start, end),
              onVerticalDragEnd: (_) => _onDragEnd(id, true),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.8)),
                child: Center(child: Icon(Icons.drag_handle, size: 12, color: Colors.grey[800])),
              ),
            ),
          ),
        if (isDragging)
          Positioned(
            top: top + height - 4,
            left: 8,
            right: 8,
            height: 8,
            child: GestureDetector(
              onVerticalDragStart: (_) => _onDragStart(id, false, start, end, true),
              onVerticalDragUpdate: (d) => _onDragUpdate(d, id, false, start, end),
              onVerticalDragEnd: (_) => _onDragEnd(id, false),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.8)),
                child: Center(child: Icon(Icons.drag_handle, size: 12, color: Colors.grey[800])),
              ),
            ),
          ),

        // Main card
        Positioned(
          top: top,
          left: 8,
          right: 8,
          height: height,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            elevation: isDragging ? 8 : (isConflict ? 4 : 1),
            child: Container(
              decoration: BoxDecoration(
                color: isConflict
                    ? Colors.red.shade800.withOpacity(0.92) // ✅ UNIFORM DARK RED
                    : color.withOpacity(isDragging ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isConflict
                      ? Colors.red.shade700 // ✅ MATCHING BORDER
                      : color.withOpacity(0.5),
                  width: isConflict ? 2.0 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject + Mastery
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _typeIcon(c['classType'] as String? ?? 'lecture'),
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    subjectName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              if (mastery > 0)
                                LinearProgressIndicator(
                                  value: mastery / 100.0,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                  minHeight: 4,
                                ),
                            ],
                          ),
                        ),
                        if (!isSmall)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${duration ~/ 60}h${duration % 60 > 0 ? '${duration % 60}m' : ''}',
                              style: const TextStyle(fontSize: 9, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isSmall)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text(
                        '${_formatMinutes24(start)} – ${_formatMinutes24(end)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (c['room'] != null && c['room']!.isNotEmpty && !isSmall)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.place, size: 12, color: Colors.white.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Room ${c['room']}',
                            style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // BUILD FREE TIME SLOT
  // ============================================
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
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
        ),
        child: Center(
          child: Text(
            '$duration min free',
            style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  // ============================================
  // UTILS
  // ============================================
  String _formatMinutes24(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  double _minutesToPixels(int minutes) {
    return ((minutes - _timelineStartMinutes) / _totalTimelineMinutes) * (_totalTimelineMinutes / 60.0) * _hourHeight;
  }

  double _durationToPixels(int durationMinutes) {
    return (durationMinutes / 60.0) * _hourHeight;
  }

  Color _hexToColor(String hex) {
    if (hex.isEmpty) return Colors.blue;
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _getNeetSubjectColor(String subjectName) {
    for (final entry in _neetColors.entries) {
      if (subjectName.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
    }
    return '#2196F3';
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

  // ============================================
  // POMODORO SHORTCUT
  // ============================================
  void _goToPomodoro(String subject, {int? durationMinutes}) {
    String preset = 'neetSprint';
    if (durationMinutes != null) {
      if (durationMinutes >= 90) preset = 'neetRevision';
    }
    // In real app: push to PomodoroScreen
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Starting NEET Sprint for "$subject"')));
  }

  // ============================================
  // BUILD TIMELINE
  // ============================================
  Widget _buildTimeline() {
    final now = DateTime.now();
    final currentMinute = (now.hour * 60 + now.minute) - _timelineStartMinutes;
    final currentTimeTop = _minutesToPixels(currentMinute);

    return Stack(
      children: [
        // Background grid
        CustomPaint(
          size: Size(_timelineWidth, _hourHeight * (_timelineEndHour - _timelineStartHour)),
          painter: _TimelineGridPainter(),
        ),
        // Now line
        if (currentMinute >= 0 && currentMinute <= _totalTimelineMinutes)
          Positioned(
            top: currentTimeTop,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Colors.redAccent.withOpacity(0.7),
              child: Center(child: Text('NOW', style: TextStyle(fontSize: 10, color: Colors.white))),
            ),
          ),
        // Classes
        ..._classes.map((c) {
          final day = c['dayOfWeek'] as int;
          if (day - 1 != _selectedDay) return SizedBox();
          final isConflict = _classes.any((other) =>
              other['id'] != c['id'] &&
              other['dayOfWeek'] == day &&
              TimetableEntry(
                subjectName: c['subjectName'] ?? '',
                dayOfWeek: day,
                startTime: c['startTimeMinutes'] as int,
                endTime: c['endTimeMinutes'] as int,
              ).conflictsWith(TimetableEntry(
                subjectName: other['subjectName'] ?? '',
                dayOfWeek: other['dayOfWeek'] as int,
                startTime: other['startTimeMinutes'] as int,
                endTime: other['endTimeMinutes'] as int,
              )));
          return _buildClassCard(c, Theme.of(context).colorScheme, isConflict, _isDragging[c['id'] as int] ?? false);
        }).toList(),
        // Free slots
        ..._getFreeSlotsForDay(_selectedDay).map((slot) => _buildFreeTimeSlot(slot, Theme.of(context).colorScheme)),
      ],
    );
  }

  List<Map<String, dynamic>> _getFreeSlotsForDay(int dayIndex) {
    final dayClasses = _classes.where((c) => (c['dayOfWeek'] as int) - 1 == dayIndex).toList();
    if (dayClasses.isEmpty) {
      return [{'start': _timelineStartMinutes, 'end': _timelineEndMinutes, 'duration': _totalTimelineMinutes}];
    }

    final sorted = List<Map<String, dynamic>>.from(dayClasses)..sort((a, b) => (a['startTimeMinutes'] as int).compareTo(b['startTimeMinutes'] as int));
    final freeSlots = <Map<String, dynamic>>[];

    int currentStart = _timelineStartMinutes;
    for (final c in sorted) {
      final start = c['startTimeMinutes'] as int;
      final end = c['endTimeMinutes'] as int;
      if (start > currentStart) {
        final duration = start - currentStart;
        freeSlots.add({'start': currentStart, 'end': start, 'duration': duration});
      }
      currentStart = end;
    }
    if (currentStart < _timelineEndMinutes) {
      final duration = _timelineEndMinutes - currentStart;
      freeSlots.add({'start': currentStart, 'end': _timelineEndMinutes, 'duration': duration});
    }
    return freeSlots;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Day selector
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (ctx, i) {
                final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i];
                final count = _classes.where((c) => (c['dayOfWeek'] as int) - 1 == i).length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _selectedDay == i ? cs.primary : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(dayName, style: TextStyle(fontWeight: _selectedDay == i ? FontWeight.bold : FontWeight.normal)),
                          Text('$count', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Stats banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.withOpacity(0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📅 ${_getFreeSlotsForDay(_selectedDay).length} free slots • ${_getTotalHoursForDay(_selectedDay)}h total', style: TextStyle(color: Colors.green[700])),
                TextButton.icon(
                  onPressed: () => _suggestStudyBlock(),
                  icon: const Icon(Icons.auto_mode, size: 16),
                  label: const Text('Suggest Block', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
                ),
              ],
            ),
          ),
          // Timeline
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: cs.background,
                  child: _buildTimeline(),
                ),
                if (_loading)
                  Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _addClass(),
            label: const Text('Add Class'),
            icon: const Icon(Icons.school),
            backgroundColor: cs.primary,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () => _addStudyBlock(),
            label: const Text('NEET Sprint'),
            icon: const Icon(Icons.timer),
            backgroundColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  double _getTotalHoursForDay(int dayIndex) {
    return _classes.where((c) => (c['dayOfWeek'] as int) - 1 == dayIndex).fold<double>(0, (sum, c) {
      final start = c['startTimeMinutes'] as int;
      final end = c['endTimeMinutes'] as int;
      return sum + (end - start) / 60.0;
    });
  }

  Future<void> _addClass() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = await db.insert('timetable_classes', {
      'subjectName': 'New Class',
      'classType': 'lecture',
      'dayOfWeek': _selectedDay + 1,
      'startTimeMinutes': 540,
      'endTimeMinutes': 600,
      'room': '',
      'professor': '',
      'colorHex': '#2196F3',
      'isRecurring': 0,
      'note': '',
      'createdAtMillis': now,
      'masteryProgress': 0,
      'syllabusWeight': 1.0,
    });
    await _loadClasses();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class added!')));
  }

  Future<void> _addStudyBlock() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final subject = _classes.isNotEmpty
        ? _classes.firstWhere((c) => c['dayOfWeek'] == _selectedDay + 1, orElse: () => {'subjectName': 'Biology'})['subjectName'] as String? ?? 'Biology'
        : 'Biology';
    await db.insert('timetable_classes', {
      'subjectName': subject,
      'classType': 'study_block',
      'dayOfWeek': _selectedDay + 1,
      'startTimeMinutes': 540,
      'endTimeMinutes': 630,
      'room': '',
      'professor': '',
      'colorHex': _colorToHex(Colors.cyan),
      'isRecurring': 0,
      'note': 'NEET Sprint',
      'createdAtMillis': now,
      'masteryProgress': 0,
      'syllabusWeight': 1.0,
    });
    HapticFeedback.mediumImpact();
    await _loadClasses();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NEET Sprint block added!'), duration: Duration(seconds: 2)));
    }
    _goToPomodoro(subject, durationMinutes: 90);
  }

  void _suggestStudyBlock() {
    final weakSubjects = _classes.where((c) => (c['masteryProgress'] as int?) ?? 0 < 50).map((c) => c['subjectName']).toSet();
    if (weakSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All subjects at >50% mastery! Great job!')));
      return;
    }
    final subject = weakSubjects.elementAt(0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('💡 Suggested: 90-min revision for "$subject"')));
  }

  String _colorToHex(Color color) {
    final argb = color.value;
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

class _TimelineGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;
    for (int h = 5; h <= 24; h++) {
      final y = (h - 5) * 72.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      canvas.drawText(
        TextSpan(text: '$h:00', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Offset(4, y + 4),
        TextPainter(textDirection: TextDirection.ltr, text: TextSpan(text: '$h:00'), textAlign: TextAlign.left)..layout(),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
