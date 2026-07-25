// FILE: lib/screens/attendance_screen.dart
// COMPLETE REWRITE — v11 Attendance Tracker with subjects, schedules, heatmaps, analytics

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';
import 'main_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _subjects = [];
  String? _selectedSubject;
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _schedules = [];
  int _currentWeekStart = 0;
  Map<String, List<Map<String, dynamic>>> _weekHeatmap = {};

  // Color palette for subject picker
  static const List<Color> _colorPalette = [
    Color(0xFFE53935), // Red
    Color(0xFFFF7043), // Deep Orange
    Color(0xFFFFB300), // Amber
    Color(0xFF66BB6A), // Green
    Color(0xFF26A69A), // Teal
    Color(0xFF42A5F5), // Blue
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFAB47BC), // Purple
    Color(0xFFEC407A), // Pink
    Color(0xFF8D6E63), // Brown
    Color(0xFF78909C), // Blue Grey
    Color(0xFF26C6DA), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _weekStart(DateTime.now()).millisecondsSinceEpoch;
    _loadData();
  }

  DateTime _weekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  /// Convert minutes-since-midnight to readable time string
  String _formatTimeMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  /// Format day name from DateTime
  String _dayName(DateTime dt) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load all v11 attendance_subjects
    final subjectRows = await DatabaseHelper.instance.getAllAttendanceSubjects();
    final subjectData = <Map<String, dynamic>>[];

    for (final row in subjectRows) {
      final id = row['id'] as int;
      final name = row['name'] as String;
      final requiredPct = (row['requiredPercentage'] as num?)?.toDouble() ?? 75.0;
      final colorHex = row['colorHex'] as String? ?? '#2196F3';
      final color = _hexToColor(colorHex);

      // Get stats from attendance_logs
      final stats = await DatabaseHelper.instance.getAttendanceStatsForSubject(name);
      final present = (stats['present'] as int?) ?? 0;
      final absent = (stats['absent'] as int?) ?? 0;
      final late = (stats['late'] as int?) ?? 0;
      final excused = (stats['excused'] as int?) ?? 0;
      final total = (stats['total'] as int?) ?? 0;

      final effectiveTotal = total - excused;
      final percentage = effectiveTotal > 0
          ? ((present + late * 0.5) / effectiveTotal * 100)
          : 0.0;

      // Get schedules for this subject
      final schedules = await DatabaseHelper.instance.getAttendanceSchedulesForSubject(id);

      subjectData.add({
        'id': id,
        'name': name,
        'requiredPercentage': requiredPct,
        'percentage': percentage,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'total': total,
        'color': color,
        'colorHex': colorHex,
        'semesterStartMillis': row['semesterStartMillis'] as int?,
        'semesterEndMillis': row['semesterEndMillis'] as int?,
        'maxAllowedAbsences': row['maxAllowedAbsences'] as int?,
        'schedules': schedules,
      });
    }

    // Sort by percentage ascending (most at-risk first)
    subjectData.sort((a, b) => (a['percentage'] as double).compareTo(b['percentage'] as double));

    // Build weekly heatmap for all subjects
    final heatmap = <String, List<Map<String, dynamic>>>{};
    final weekStart = DateTime.fromMillisecondsSinceEpoch(_currentWeekStart);
    for (int i = 0; i < 5; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
      final dayLogs = await DatabaseHelper.instance.getAttendanceLogsForDate(dayStart);
      heatmap[_dayName(day)] = dayLogs;
    }

    if (mounted) {
      setState(() {
        _subjects = subjectData;
        _weekHeatmap = heatmap;
        _loading = false;
      });
    }

    if (_selectedSubject != null) {
      await _loadDetailForSubject(_selectedSubject!);
    }

    await WidgetService.refreshAttendanceWidget();
  }

  Future<void> _loadDetailForSubject(String subjectName) async {
    final subject = _subjects.firstWhere(
      (s) => s['name'] == subjectName,
      orElse: () => {},
    );
    if (subject.isEmpty) return;

    final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subjectName);
    final schedules = await DatabaseHelper.instance.getAttendanceSchedulesForSubject(subject['id'] as int);

    setState(() {
      _selectedSubject = subjectName;
      _logs = logs;
      _schedules = schedules;
    });
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _addSubject() async {
    final nameController = TextEditingController();
    final reqController = TextEditingController(text: '75');
    DateTime? semesterStart;
    DateTime? semesterEnd;
    Color selectedColor = _colorPalette[0];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Subject'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      hintText: 'e.g., Physics',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reqController,
                    decoration: const InputDecoration(
                      labelText: 'Required Attendance %',
                      hintText: '75',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Semester date range
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => semesterStart = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Semester Start',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              semesterStart != null
                                  ? DateFormat('dd MMM yyyy').format(semesterStart!)
                                  : 'Select date',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: semesterStart?.add(const Duration(days: 120)) ?? DateTime.now(),
                              firstDate: semesterStart ?? DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => semesterEnd = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Semester End',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              semesterEnd != null
                                  ? DateFormat('dd MMM yyyy').format(semesterEnd!)
                                  : 'Select date',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Subject Color',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorPalette.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
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
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, {
                      'name': nameController.text.trim(),
                      'requiredPercentage': double.tryParse(reqController.text) ?? 75.0,
                      'semesterStartMillis': semesterStart?.millisecondsSinceEpoch,
                      'semesterEndMillis': semesterEnd?.millisecondsSinceEpoch,
                      'colorHex': _colorToHex(selectedColor),
                    });
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    reqController.dispose();

    if (result != null) {
      // Insert into attendance_subjects table
      await DatabaseHelper.instance.insertAttendanceSubject({
        'name': result['name'],
        'requiredPercentage': result['requiredPercentage'],
        'semesterStartMillis': result['semesterStartMillis'],
        'semesterEndMillis': result['semesterEndMillis'],
        'colorHex': result['colorHex'],
      });

      // Auto-mark present for today
      await _markAttendance(result['name'] as String, 'present', DateTime.now());
      await _loadData();
    }
  }

  Future<void> _editSubject(Map<String, dynamic> subject) async {
    final nameController = TextEditingController(text: subject['name'] as String);
    final reqController = TextEditingController(text: (subject['requiredPercentage'] as double).toStringAsFixed(0));
    DateTime? semesterStart = subject['semesterStartMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(subject['semesterStartMillis'] as int)
        : null;
    DateTime? semesterEnd = subject['semesterEndMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(subject['semesterEndMillis'] as int)
        : null;
    Color selectedColor = subject['color'] as Color;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Subject'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reqController,
                    decoration: const InputDecoration(
                      labelText: 'Required Attendance %',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: semesterStart ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => semesterStart = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Semester Start',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              semesterStart != null
                                  ? DateFormat('dd MMM yyyy').format(semesterStart!)
                                  : 'Select date',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: semesterEnd ?? DateTime.now().add(const Duration(days: 120)),
                              firstDate: semesterStart ?? DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => semesterEnd = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Semester End',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              semesterEnd != null
                                  ? DateFormat('dd MMM yyyy').format(semesterEnd!)
                                  : 'Select date',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Subject Color',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorPalette.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
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
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, {
                      'name': nameController.text.trim(),
                      'requiredPercentage': double.tryParse(reqController.text) ?? 75.0,
                      'semesterStartMillis': semesterStart?.millisecondsSinceEpoch,
                      'semesterEndMillis': semesterEnd?.millisecondsSinceEpoch,
                      'colorHex': _colorToHex(selectedColor),
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    reqController.dispose();

    if (result != null) {
      await DatabaseHelper.instance.updateAttendanceSubject(subject['id'] as int, {
        'name': result['name'],
        'requiredPercentage': result['requiredPercentage'],
        'semesterStartMillis': result['semesterStartMillis'],
        'semesterEndMillis': result['semesterEndMillis'],
        'colorHex': result['colorHex'],
      });
      await _loadData();
    }
  }

  Future<void> _addSchedule(int subjectId) async {
    int dayOfWeek = 1; // Monday
    int startTimeMinutes = 540; // 9:00 AM
    int endTimeMinutes = 600;   // 10:00 AM
    final roomController = TextEditingController();
    final professorController = TextEditingController();
    String scheduleType = 'lecture';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Schedule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration: const InputDecoration(labelText: 'Day of Week'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Monday')),
                      DropdownMenuItem(value: 2, child: Text('Tuesday')),
                      DropdownMenuItem(value: 3, child: Text('Wednesday')),
                      DropdownMenuItem(value: 4, child: Text('Thursday')),
                      DropdownMenuItem(value: 5, child: Text('Friday')),
                      DropdownMenuItem(value: 6, child: Text('Saturday')),
                      DropdownMenuItem(value: 7, child: Text('Sunday')),
                    ],
                    onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: scheduleType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'lecture', child: Text('Lecture')),
                      DropdownMenuItem(value: 'lab', child: Text('Lab')),
                      DropdownMenuItem(value: 'tutorial', child: Text('Tutorial')),
                      DropdownMenuItem(value: 'seminar', child: Text('Seminar')),
                    ],
                    onChanged: (v) => setDialogState(() => scheduleType = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: startTimeMinutes ~/ 60, minute: startTimeMinutes % 60),
                            );
                            if (time != null) {
                              setDialogState(() => startTimeMinutes = time.hour * 60 + time.minute);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Start Time'),
                            child: Text(_formatTimeMinutes(startTimeMinutes)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: endTimeMinutes ~/ 60, minute: endTimeMinutes % 60),
                            );
                            if (time != null) {
                              setDialogState(() => endTimeMinutes = time.hour * 60 + time.minute);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'End Time'),
                            child: Text(_formatTimeMinutes(endTimeMinutes)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room / Location',
                      hintText: 'e.g., Room 301',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: professorController,
                    decoration: const InputDecoration(
                      labelText: 'Professor (optional)',
                      hintText: 'e.g., Dr. Smith',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, {
                  'subjectId': subjectId,
                  'dayOfWeek': dayOfWeek,
                  'startTimeMinutes': startTimeMinutes,
                  'endTimeMinutes': endTimeMinutes,
                  'room': roomController.text.trim().isEmpty ? null : roomController.text.trim(),
                  'professor': professorController.text.trim().isEmpty ? null : professorController.text.trim(),
                  'scheduleType': scheduleType,
                }),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    roomController.dispose();
    professorController.dispose();

    if (result != null) {
      await DatabaseHelper.instance.insertAttendanceSchedule(result);
      await _loadDetailForSubject(_subjects.firstWhere((s) => s['id'] == subjectId)['name'] as String);
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: const Text('This schedule slot will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAttendanceSchedule(scheduleId);
      if (_selectedSubject != null) {
        await _loadDetailForSubject(_selectedSubject!);
      }
      await _loadData();
    }
  }

  Future<void> _markAttendance(String subject, String status, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, dayStart);

    if (existing != null) {
      await DatabaseHelper.instance.updateAttendanceLog(existing['id'] as int, {
        'subjectName': subject,
        'dateMillis': dayStart,
        'status': status,
        'note': existing['note'],
        'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await DatabaseHelper.instance.insertAttendanceLog({
        'subjectName': subject,
        'dateMillis': dayStart,
        'status': status,
        'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await WidgetService.refreshAttendanceWidget();
  }

  Future<void> _showMarkDialog(String subject, {DateTime? specificDate}) async {
    final date = specificDate ?? DateTime.now();
    final statuses = ['present', 'absent', 'late', 'excused'];
    final statusLabels = ['Present', 'Absent', 'Late', 'Excused'];
    final statusColors = [Colors.green, Colors.red, Colors.orange, Colors.blue];
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark: $subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEEE, dd MMM yyyy').format(date),
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...List.generate(statuses.length, (i) {
              return ListTile(
                leading: Icon(Icons.circle, color: statusColors[i]),
                title: Text(statusLabels[i]),
                onTap: () => Navigator.pop(ctx, {'status': statuses[i]}),
              );
            }),
            const Divider(),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g., Medical leave',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );

    final noteText = noteController.text.trim();
    noteController.dispose();

    if (result != null) {
      final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, dayStart);

      if (existing != null) {
        await DatabaseHelper.instance.updateAttendanceLog(existing['id'] as int, {
          'subjectName': subject,
          'dateMillis': dayStart,
          'status': result['status'],
          'note': noteText.isEmpty ? existing['note'] : noteText,
          'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await DatabaseHelper.instance.insertAttendanceLog({
          'subjectName': subject,
          'dateMillis': dayStart,
          'status': result['status'],
          'note': noteText.isEmpty ? null : noteText,
          'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
      }

      HapticFeedback.mediumImpact();
      await _loadData();
      if (_selectedSubject == subject) {
        await _loadDetailForSubject(subject);
      }
    }
  }

  Future<void> _markAllTodayPresent() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    for (final subj in _subjects) {
      final name = subj['name'] as String;
      final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(name, todayStart);
      if (existing == null) {
        await DatabaseHelper.instance.insertAttendanceLog({
          'subjectName': name,
          'dateMillis': todayStart,
          'status': 'present',
          'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }

    HapticFeedback.mediumImpact();
    await _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All subjects marked present for today!')),
    );
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Delete "${subject['name']}" and all its attendance data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Delete all logs for this subject
      final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subject['name'] as String);
      final db = await DatabaseHelper.instance.database;
      for (final log in logs) {
        await db.delete('attendance_logs', where: 'id = ?', whereArgs: [log['id']]);
      }
      // Delete all schedules for this subject
      final schedules = await DatabaseHelper.instance.getAttendanceSchedulesForSubject(subject['id'] as int);
      for (final sched in schedules) {
        await db.delete('attendance_schedules', where: 'id = ?', whereArgs: [sched['id']]);
      }
      // Delete the subject itself
      await DatabaseHelper.instance.deleteAttendanceSubject(subject['id'] as int);

      await _loadData();
      if (_selectedSubject == subject['name']) {
        setState(() => _selectedSubject = null);
      }
    }
  }

  String _riskText(double percentage, int absent, int total, double required) {
    if (total == 0) return 'No data yet';
    if (percentage >= required) {
      final canMiss = ((total * (required / 100) - (total - absent)) / (1 - required / 100)).floor();
      return 'Can miss ${max(0, canMiss)} more';
    } else {
      final needAttend = ((required / 100 * total - (total - absent)) / (required / 100)).ceil();
      return 'Need $needAttend more';
    }
  }

  Color _riskColor(double percentage, double required) {
    if (percentage >= required + 5) return Colors.green;
    if (percentage >= required) return Colors.orange;
    if (percentage >= required - 15) return Colors.deepOrange;
    return Colors.red;
  }

  /// Get heatmap color intensity for a day based on attendance ratio
  Color _heatmapColor(String day) {
    final logs = _weekHeatmap[day] ?? [];
    if (logs.isEmpty) return Colors.grey.shade200;

    final present = logs.where((l) => l['status'] == 'present').length;
    final total = logs.length;
    final ratio = total > 0 ? present / total : 0.0;

    if (ratio >= 0.8) return Colors.green.shade400;
    if (ratio >= 0.5) return Colors.orange.shade300;
    if (ratio > 0) return Colors.red.shade300;
    return Colors.grey.shade200;
  }

  /// Get count text for heatmap day
  String _heatmapCount(String day) {
    final logs = _weekHeatmap[day] ?? [];
    if (logs.isEmpty) return '-';
    final present = logs.where((l) => l['status'] == 'present').length;
    return '$present/${logs.length}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSubject,
            tooltip: 'Add Subject',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? _buildEmptyState(cs)
              : _buildContent(cs),
      floatingActionButton: _subjects.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _markAllTodayPresent,
              icon: const Icon(Icons.done_all),
              label: const Text('Mark All Present'),
            )
          : null,
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: cs.outline.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            'No subjects yet!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first subject to start tracking attendance.',
            style: TextStyle(color: cs.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return Column(
      children: [
        _buildOverallStats(cs),
        _buildWeeklyHeatmap(cs),
        const Divider(height: 1),
        Expanded(
          child: _selectedSubject == null
              ? _buildSubjectList(cs)
              : _buildSubjectDetail(cs),
        ),
      ],
    );
  }

  Widget _buildOverallStats(ColorScheme cs) {
    if (_subjects.isEmpty) return const SizedBox.shrink();

    final avgPercentage = _subjects.isEmpty
        ? 0.0
        : _subjects.map((s) => s['percentage'] as double).reduce((a, b) => a + b) / _subjects.length;

    final atRisk = _subjects.where((s) {
      final req = (s['requiredPercentage'] as double);
      return (s['percentage'] as double) < req;
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.1), cs.secondary.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniStat('Overall', '${avgPercentage.toStringAsFixed(1)}%', cs.primary),
              ),
              Expanded(
                child: _buildMiniStat('Subjects', '${_subjects.length}', cs.secondary),
              ),
              Expanded(
                child: _buildMiniStat(
                  'At Risk',
                  '$atRisk',
                  atRisk > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          if (atRisk > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
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
                      '$atRisk subject${atRisk == 1 ? '' : 's'} below required attendance!',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyHeatmap(ColorScheme cs) {
    final weekStart = DateTime.fromMillisecondsSinceEpoch(_currentWeekStart);
    final days = List.generate(5, (i) => weekStart.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: () {
                      setState(() => _currentWeekStart = weekStart.subtract(const Duration(days: 7)).millisecondsSinceEpoch);
                      _loadData();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${DateFormat('dd MMM').format(days.first)} - ${DateFormat('dd MMM').format(days.last)}',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: () {
                      setState(() => _currentWeekStart = weekStart.add(const Duration(days: 7)).millisecondsSinceEpoch);
                      _loadData();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: days.map((day) {
              final dayName = _dayName(day);
              final isToday = DateTime.now().year == day.year &&
                  DateTime.now().month == day.month &&
                  DateTime.now().day == day.day;
              final heatColor = _heatmapColor(dayName);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? cs.primary : cs.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: heatColor,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(color: cs.primary, width: 2)
                              : Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                        ),
                        child: Center(
                          child: Text(
                            _heatmapCount(dayName),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: heatColor == Colors.grey.shade200 ? cs.outline : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildSubjectList(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Horizontal scrollable subject cards
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _subjects.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              final s = _subjects[index];
              final percentage = s['percentage'] as double;
              final required = s['requiredPercentage'] as double;
              final color = s['color'] as Color;
              final name = s['name'] as String;

              return GestureDetector(
                onTap: () => _loadDetailForSubject(name),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _riskColor(percentage, required),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _riskText(percentage, s['absent'] as int, s['total'] as int, required),
                        style: TextStyle(fontSize: 11, color: cs.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Detailed subject list
        ..._subjects.map((s) {
          final percentage = s['percentage'] as double;
          final required = s['requiredPercentage'] as double;
          final color = s['color'] as Color;
          final name = s['name'] as String;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
            ),
            child: InkWell(
              onTap: () => _loadDetailForSubject(name),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _riskColor(percentage, required).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _riskColor(percentage, required),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: cs.outlineVariant.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(_riskColor(percentage, required)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildTinyChip('P', s['present'] as int, Colors.green),
                            const SizedBox(width: 6),
                            _buildTinyChip('A', s['absent'] as int, Colors.red),
                            const SizedBox(width: 6),
                            _buildTinyChip('L', s['late'] as int, Colors.orange),
                            const SizedBox(width: 6),
                            _buildTinyChip('E', s['excused'] as int, Colors.blue),
                          ],
                        ),
                        Text(
                          _riskText(percentage, s['absent'] as int, s['total'] as int, required),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _riskColor(percentage, required),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _showMarkDialog(name),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Mark Today'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
                          onPressed: () => _editSubject(s),
                          tooltip: 'Edit Subject',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                          onPressed: () => _deleteSubject(s),
                          tooltip: 'Delete Subject',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTinyChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label:$count',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildSubjectDetail(ColorScheme cs) {
    final s = _subjects.firstWhere(
      (sub) => sub['name'] == _selectedSubject,
      orElse: () => {},
    );
    if (s.isEmpty) return const SizedBox.shrink();

    final percentage = s['percentage'] as double;
    final required = s['requiredPercentage'] as double;
    final color = s['color'] as Color;

    return Column(
      children: [
        AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedSubject = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedSubject!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editSubject(s),
              tooltip: 'Edit Subject',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteSubject(s),
              tooltip: 'Delete Subject',
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Circular progress indicator
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 12,
                        backgroundColor: cs.outlineVariant.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                      ),
                      CircularProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        strokeWidth: 12,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(_riskColor(percentage, required)),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _riskColor(percentage, required),
                              ),
                            ),
                            Text(
                              'of $required% required',
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _riskText(percentage, s['absent'] as int, s['total'] as int, required),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _riskColor(percentage, required),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Status chips row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusChip('Present', s['present'] as int, Colors.green),
                  _buildStatusChip('Absent', s['absent'] as int, Colors.red),
                  _buildStatusChip('Late', s['late'] as int, Colors.orange),
                  _buildStatusChip('Excused', s['excused'] as int, Colors.blue),
                ],
              ),
              const SizedBox(height: 24),

              // Trend placeholder section
              _buildSectionTitle('Trend', cs),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 40, color: cs.outline.withOpacity(0.4)),
                      const SizedBox(height: 8),
                      Text(
                        'Attendance trend chart coming soon',
                        style: TextStyle(color: cs.outline, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Schedule list section
              _buildSectionTitle('Schedule', cs),
              const SizedBox(height: 8),
              if (_schedules.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: cs.outline, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No schedule set. Add class timings to get reminders.',
                          style: TextStyle(color: cs.outline, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._schedules.map((sched) {
                  final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final dayIndex = (sched['dayOfWeek'] as int) - 1;
                  final dayName = dayIndex >= 0 && dayIndex < 7 ? dayNames[dayIndex] : '?';
                  final start = _formatTimeMinutes(sched['startTimeMinutes'] as int);
                  final end = _formatTimeMinutes(sched['endTimeMinutes'] as int);
                  final room = sched['room'] as String?;
                  final professor = sched['professor'] as String?;
                  final type = (sched['scheduleType'] as String? ?? 'lecture').toUpperCase();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            dayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      title: Text('$start - $end'),
                      subtitle: Text(
                        [
                          if (room != null && room.isNotEmpty) room,
                          if (professor != null && professor.isNotEmpty) professor,
                          type,
                        ].join(' • '),
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                        onPressed: () => _deleteSchedule(sched['id'] as int),
                      ),
                    ),
                  );
                }).toList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _addSchedule(s['id'] as int),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Schedule'),
              ),
              const SizedBox(height: 24),

              // Quick mark buttons
              _buildSectionTitle('Quick Mark', cs),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _markAttendance(_selectedSubject!, 'present', DateTime.now());
                        await _loadData();
                        await _loadDetailForSubject(_selectedSubject!);
                      },
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Present'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _markAttendance(_selectedSubject!, 'absent', DateTime.now());
                        await _loadData();
                        await _loadDetailForSubject(_selectedSubject!);
                      },
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Absent'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _markAttendance(_selectedSubject!, 'late', DateTime.now());
                        await _loadData();
                        await _loadDetailForSubject(_selectedSubject!);
                      },
                      icon: const Icon(Icons.watch_later, size: 18),
                      label: const Text('Late'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _markAttendance(_selectedSubject!, 'excused', DateTime.now());
                        await _loadData();
                        await _loadDetailForSubject(_selectedSubject!);
                      },
                      icon: const Icon(Icons.medical_services, size: 18),
                      label: const Text('Excused'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent logs
              _buildSectionTitle('Recent Logs', cs),
              const SizedBox(height: 8),
              if (_logs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'No attendance records yet.',
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
                )
              else
                ..._logs.take(30).map((log) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(log['dateMillis'] as int);
                  final status = log['status'] as String;
                  final statusColor = {
                    'present': Colors.green,
                    'absent': Colors.red,
                    'late': Colors.orange,
                    'excused': Colors.blue,
                  }[status] ?? Colors.grey;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      title: Text(
                        DateFormat('EEEE, dd MMM yyyy').format(dt),
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      subtitle: log['note'] != null
                          ? Text(
                              log['note'] as String,
                              style: TextStyle(fontSize: 11, color: cs.outline),
                            )
                          : null,
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
