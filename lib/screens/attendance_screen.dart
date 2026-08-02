// FILE: lib/screens/attendance_screen.dart
// COMPLETE REWRITE — v12 NEET Edition: Sessions, bunk calculator, predictor, countdown
// FIXED: Division by zero when required=100%
// CHANGED: "Class" → "Session" throughout for revision-era NEET prep
// ENHANCED: NEET presets, medical theme, bunk calculator, attendance predictor, weekly report, smart suggestions
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';
import 'main_screen.dart';
import 'attendance_detail_screen.dart';
import 'attendance_analytics_screen.dart';

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

  static const List<Color> _colorPalette = [
    Color(0xFFE53935),
    Color(0xFFFF7043),
    Color(0xFFFFB300),
    Color(0xFF66BB6A),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFF5C6BC0),
    Color(0xFFAB47BC),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
    Color(0xFF26C6DA),
  ];

  static const List<String> _neetQuotes = [
    'Consistency beats intensity. Show up every session!',
    'Every session counts toward your white coat dream.',
    'Small steps every day lead to AIIMS.',
    'Revision today, doctor tomorrow.',
    'NEET is won in the daily grind, not on exam day.',
    'One session at a time. One rank at a time.',
    'Your future patients are counting on you.',
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

  DateTime _getNeetDate() {
    final now = DateTime.now();
    var year = now.year;
    var date = DateTime(year, 5, 1);
    while (date.weekday != DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    if (date.isBefore(now)) {
      year++;
      date = DateTime(year, 5, 1);
      while (date.weekday != DateTime.sunday) {
        date = date.add(const Duration(days: 1));
      }
    }
    return date;
  }

  String _formatTimeMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  String _dayName(DateTime dt) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
  }

  String _neetQuote() {
    final dayOfYear = int.parse(DateFormat('D').format(DateTime.now()));
    return _neetQuotes[dayOfYear % _neetQuotes.length];
  }

  // FIXED: Guard against division by zero when required=100
  String _riskText(double percentage, int absent, int total, double required) {
    if (total == 0) return 'No data yet';
    if (required >= 100.0) {
      if (percentage >= 99.99) return 'Perfect! 100% session attendance';
      return '100% required — attend every session';
    }
    if (percentage >= required) {
      final canMiss = ((total * (required / 100) - (total - absent)) / (1 - required / 100)).floor();
      return 'Can miss ${max(0, canMiss)} more sessions';
    } else {
      final needAttend = ((required / 100 * total - (total - absent)) / (required / 100)).ceil();
      return 'Need $needAttend more sessions';
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final subjectRows = await DatabaseHelper.instance.getAllAttendanceSubjects();
    final subjectData = <Map<String, dynamic>>[];

    for (final row in subjectRows) {
      final id = (row['id'] as int?) ?? 0;
      final name = row['name'] as String;
      final requiredPct = (row['requiredPercentage'] as num?)?.toDouble() ?? 75.0;
      final colorHex = row['colorHex'] as String? ?? '#2196F3';
      final color = _hexToColor(colorHex);

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

    subjectData.sort((a, b) => (a['percentage'] as double).compareTo(b['percentage'] as double));

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
      final stillExists = subjectData.any((s) => s['name'] == _selectedSubject);
      if (stillExists) {
        await _loadDetailForSubject(_selectedSubject!);
      } else {
        if (mounted) setState(() => _selectedSubject = null);
      }
    }

    // ── Write widget data for home screen widget ──
    // FIXED: Call AFTER setState completes, not before
    await WidgetService.refreshAttendanceWidget();
  }

  Future<void> _loadDetailForSubject(String subjectName) async {
    final subject = _subjects.firstWhere(
      (s) => s['name'] == subjectName,
      orElse: () => {},
    );
    if (subject.isEmpty) return;

    final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subjectName);
    final schedules = await DatabaseHelper.instance.getAttendanceSchedulesForSubject((subject['id'] as int?) ?? 0);

    if (mounted) setState(() {
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

    final neetPresets = {
      'Physics': '#FF6B6B',
      'Chemistry': '#4ECDC4',
      'Botany': '#66BB6A',
      'Zoology': '#AB47BC',
    };

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
                    'NEET Quick Add',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: neetPresets.entries.map((entry) {
                      return ActionChip(
                        avatar: Icon(
                          entry.key == 'Physics' ? Icons.bolt :
                          entry.key == 'Chemistry' ? Icons.science :
                          entry.key == 'Botany' ? Icons.eco :
                          Icons.psychology,
                          size: 18,
                          color: _hexToColor(entry.value),
                        ),
                        label: Text(entry.key),
                        backgroundColor: _hexToColor(entry.value).withOpacity(0.12),
                        side: BorderSide(color: _hexToColor(entry.value).withOpacity(0.4)),
                        onPressed: () {
                          nameController.text = entry.key;
                          setDialogState(() => selectedColor = _hexToColor(entry.value));
                        },
                      );
                    }).toList(),
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
      await DatabaseHelper.instance.insertAttendanceSubject({
        'name': result['name'],
        'requiredPercentage': result['requiredPercentage'],
        'semesterStartMillis': result['semesterStartMillis'],
        'semesterEndMillis': result['semesterEndMillis'],
        'colorHex': result['colorHex'],
      });

      await _markAttendance(result['name'] as String, 'present', DateTime.now());
      await _loadData();
    }
  }

  Future<void> _editSubject(Map<String, dynamic> subject) async {
    final nameController = TextEditingController(text: subject['name'] as String);
    final reqController = TextEditingController(text: (subject['requiredPercentage'] as double).toStringAsFixed(0));
    DateTime? semesterStart = subject['semesterStartMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch((subject['semesterStartMillis'] as int?) ?? 0)
        : null;
    DateTime? semesterEnd = subject['semesterEndMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch((subject['semesterEndMillis'] as int?) ?? 0)
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
      await DatabaseHelper.instance.updateAttendanceSubject((subject['id'] as int?) ?? 0, {
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
    int dayOfWeek = 1;
    int startTimeMinutes = 540;
    int endTimeMinutes = 600;
    final roomController = TextEditingController();
    final professorController = TextEditingController();
    String scheduleType = 'revision';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Session'),
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
                    decoration: const InputDecoration(labelText: 'Session Type'),
                    items: const [
                      DropdownMenuItem(value: 'revision', child: Text('Revision')),
                      DropdownMenuItem(value: 'practice', child: Text('Practice')),
                      DropdownMenuItem(value: 'test', child: Text('Test')),
                      DropdownMenuItem(value: 'review', child: Text('Review')),
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
                      labelText: 'Location / Place',
                      hintText: 'e.g., Study Room, Library',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: professorController,
                    decoration: const InputDecoration(
                      labelText: 'Mentor (optional)',
                      hintText: 'e.g., Dr. Sharma',
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
        title: const Text('Delete Session?'),
        content: const Text('This session slot will be removed.'),
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

  // FIXED: Removed duplicate _loadData() call — _markAttendance only writes to DB,
  // the caller is responsible for refreshing UI + widget
  Future<void> _markAttendance(String subject, String status, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, dayStart);

    if (existing != null) {
      await DatabaseHelper.instance.updateAttendanceLog((existing['id'] as int?) ?? 0, {
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
                hintText: 'e.g., Mock test, Revision block',
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
        await DatabaseHelper.instance.updateAttendanceLog((existing['id'] as int?) ?? 0, {
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
    }
  }

  Future<void> _showBulkMarkDialog() async {
    if (_subjects.isEmpty) return;

    String selectedSubject = _subjects.first['name'] as String;
    String selectedStatus = 'present';
    DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime endDate = DateTime.now();

    final statuses = ['present', 'absent', 'late', 'excused'];
    final statusLabels = ['Present', 'Absent', 'Late', 'Excused'];
    final statusColors = [Colors.green, Colors.red, Colors.orange, Colors.blue];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Bulk Mark Attendance'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.book),
                    ),
                    items: _subjects.map((s) => DropdownMenuItem(
                      value: s['name'] as String,
                      child: Text(s['name'] as String),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedSubject = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.fact_check),
                    ),
                    items: List.generate(statuses.length, (i) => DropdownMenuItem(
                      value: statuses[i],
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: statusColors[i], size: 12),
                          const SizedBox(width: 8),
                          Text(statusLabels[i]),
                        ],
                      ),
                    )),
                    onChanged: (v) => setDialogState(() => selectedStatus = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('From Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(startDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.date_range, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => startDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('To Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(endDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.date_range, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => endDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final days = endDate.difference(startDate).inDays + 1;
                  Navigator.pop(ctx, {
                    'subject': selectedSubject,
                    'status': selectedStatus,
                    'days': days,
                  });
                },
                child: const Text('Mark'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final subject = result['subject'] as String;
      final status = result['status'] as String;
      final days = (result['days'] as int?) ?? 0;

      int markedCount = 0;
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
        final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, dayStart);
        if (existing == null) {
          await DatabaseHelper.instance.insertAttendanceLog({
            'subjectName': subject,
            'dateMillis': dayStart,
            'status': status,
            'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
          });
          markedCount++;
        }
      }

      HapticFeedback.mediumImpact();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked $markedCount day(s) as $status')),
        );
      }
    }
  }

  // NEW: Bunk Calculator — how many sessions can you safely miss?
  Future<void> _showBunkCalculator() async {
    if (_subjects.isEmpty) return;
    String selectedSubject = _subjects.first['name'] as String;
    final missController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final subject = _subjects.firstWhere((s) => s['name'] == selectedSubject);
          final percentage = subject['percentage'] as double;
          final required = subject['requiredPercentage'] as double;
          final present = (subject['present'] as int?) ?? 0;
          final late = (subject['late'] as int?) ?? 0;
          final total = (subject['total'] as int?) ?? 0;
          final excused = (subject['excused'] as int?) ?? 0;
          final effectiveTotal = total - excused;
          final attended = present + (late * 0.5);
          final missCount = int.tryParse(missController.text) ?? 0;

          double newPct = 0;
          if (effectiveTotal + missCount > 0) {
            newPct = (attended / (effectiveTotal + missCount)) * 100;
          }

          String resultText;
          if (missCount <= 0) {
            resultText = 'Enter sessions to miss';
          } else if (newPct >= required) {
            resultText = 'After missing $missCount: ${newPct.toStringAsFixed(1)}% — still safe!';
          } else {
            final shortfall = required - newPct;
            resultText = 'After missing $missCount: ${newPct.toStringAsFixed(1)}% — ${shortfall.toStringAsFixed(1)}% below requirement!';
          }

          final cs = Theme.of(context).colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.calculate_outlined, color: Colors.teal),
                SizedBox(width: 8),
                Text('Bunk Calculator'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.book),
                    ),
                    items: _subjects.map((s) => DropdownMenuItem(
                      value: s['name'] as String,
                      child: Text(s['name'] as String),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedSubject = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: missController,
                    decoration: const InputDecoration(
                      labelText: 'Sessions you plan to miss',
                      prefixIcon: Icon(Icons.remove_circle_outline),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: newPct >= required ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: newPct >= required ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          newPct >= required ? Icons.check_circle : Icons.warning,
                          color: newPct >= required ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(resultText, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${percentage.toStringAsFixed(1)}% ($present P, ${late > 0 ? '$late L, ' : ''}$excused E, $effectiveTotal total)',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );

    missController.dispose();
  }

  // NEW: Attendance Predictor — what if you attend/miss N sessions?
  Future<void> _showPredictor() async {
    if (_subjects.isEmpty) return;
    String selectedSubject = _subjects.first['name'] as String;
    final countController = TextEditingController(text: '5');
    bool willAttend = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final subject = _subjects.firstWhere((s) => s['name'] == selectedSubject);
          final percentage = subject['percentage'] as double;
          final required = subject['requiredPercentage'] as double;
          final present = (subject['present'] as int?) ?? 0;
          final late = (subject['late'] as int?) ?? 0;
          final total = (subject['total'] as int?) ?? 0;
          final excused = (subject['excused'] as int?) ?? 0;
          final effectiveTotal = total - excused;
          final attended = present + (late * 0.5);
          final count = int.tryParse(countController.text) ?? 0;

          double newPct = 0;
          double newAttended = attended;
          int newTotal = effectiveTotal;
          if (willAttend) {
            newAttended += count;
          }
          newTotal += count;
          if (newTotal > 0) {
            newPct = (newAttended / newTotal) * 100;
          }

          final diff = newPct - percentage;
          final diffText = diff >= 0 ? '+${diff.toStringAsFixed(1)}%' : '${diff.toStringAsFixed(1)}%';

          final cs = Theme.of(context).colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Attendance Predictor'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.book),
                    ),
                    items: _subjects.map((s) => DropdownMenuItem(
                      value: s['name'] as String,
                      child: Text(s['name'] as String),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedSubject = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countController,
                    decoration: const InputDecoration(
                      labelText: 'Number of upcoming sessions',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Attend All'), icon: Icon(Icons.check)),
                      ButtonSegment(value: false, label: Text('Miss All'), icon: Icon(Icons.close)),
                    ],
                    selected: {willAttend},
                    onSelectionChanged: (set) => setDialogState(() => willAttend = set.first),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projected: ${newPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: newPct >= required ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          '($diffText from current ${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          newPct >= required
                              ? 'You will stay above the $required% requirement.'
                              : 'You will drop below the $required% requirement!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: newPct >= required ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );

    countController.dispose();
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All subjects marked present for today!')),
      );
    }
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
      final db = await DatabaseHelper.instance.database;
      final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subject['name'] as String);
      for (final log in logs) {
        await db.delete('attendance_logs', where: 'id = ?', whereArgs: [log['id']]);
      }
      final schedules = await DatabaseHelper.instance.getAttendanceSchedulesForSubject((subject['id'] as int?) ?? 0);
      for (final sched in schedules) {
        await db.delete('attendance_schedules', where: 'id = ?', whereArgs: [sched['id']]);
      }
      await DatabaseHelper.instance.deleteAttendanceSubject((subject['id'] as int?) ?? 0);

      await _loadData();
      if (mounted && _selectedSubject == subject['name']) {
        setState(() => _selectedSubject = null);
      }
    }
  }

  Color _riskColor(double percentage, double required) {
    if (percentage >= required + 5) return Colors.green;
    if (percentage >= required) return Colors.orange;
    if (percentage >= required - 15) return Colors.deepOrange;
    return Colors.red;
  }

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

  String _heatmapCount(String day) {
    final logs = _weekHeatmap[day] ?? [];
    if (logs.isEmpty) return '-';
    final present = logs.where((l) => l['status'] == 'present').length;
    return '$present/${logs.length}';
  }

  int _calculateStreak(String subjectName) {
    final logs = _logs.where((l) => l['subjectName'] == subjectName).toList()
      ..sort((a, b) => ((b['dateMillis'] as int?) ?? 0).compareTo((a['dateMillis'] as int?) ?? 0));

    if (logs.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();
    var expectedDate = DateTime(now.year, now.month, now.day);

    for (final log in logs) {
      final logDate = DateTime.fromMillisecondsSinceEpoch((log['dateMillis'] as int?) ?? 0);
      final normalizedLog = DateTime(logDate.year, logDate.month, logDate.day);

      if (normalizedLog == expectedDate) {
        if (log['status'] == 'present' || log['status'] == 'late') {
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else if (normalizedLog.isBefore(expectedDate)) {
        break;
      }
    }

    return streak;
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
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttendanceAnalyticsScreen(),
                ),
              ).then((_) => _loadData());
            },
            tooltip: 'Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            onPressed: _showBunkCalculator,
            tooltip: 'Bunk Calculator',
          ),
          IconButton(
            icon: const Icon(Icons.trending_up),
            onPressed: _showPredictor,
            tooltip: 'Predictor',
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: _showBulkMarkDialog,
            tooltip: 'Bulk Mark',
          ),
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
            'Add your first subject to start tracking session attendance.',
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
    if (_selectedSubject != null) {
      return _buildSubjectDetail(cs);
    }
    return _buildSubjectList(cs);
  }

  Widget _buildSubjectList(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
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
                final streak = _calculateStreak(name);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceDetailScreen(
                          subjectId: (s['id'] as int?) ?? 0,
                          subjectName: name,
                          subjectColor: color,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
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
                        Row(
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _riskColor(percentage, required),
                              ),
                            ),
                            if (streak > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department, size: 12, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$streak',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _riskText(percentage, (s['absent'] as int?) ?? 0, (s['total'] as int?) ?? 0, required),
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
          ..._subjects.map((s) {
            final percentage = s['percentage'] as double;
            final required = s['requiredPercentage'] as double;
            final color = s['color'] as Color;
            final name = s['name'] as String;
            final streak = _calculateStreak(name);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceDetailScreen(
                        subjectId: (s['id'] as int?) ?? 0,
                        subjectName: name,
                        subjectColor: color,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
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
                          if (streak > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, size: 14, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$streak',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                                  ),
                                ],
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
                              _buildTinyChip('P', (s['present'] as int?) ?? 0, Colors.green),
                              const SizedBox(width: 6),
                              _buildTinyChip('A', (s['absent'] as int?) ?? 0, Colors.red),
                              const SizedBox(width: 6),
                              _buildTinyChip('L', (s['late'] as int?) ?? 0, Colors.orange),
                              const SizedBox(width: 6),
                              _buildTinyChip('E', (s['excused'] as int?) ?? 0, Colors.blue),
                            ],
                          ),
                          Text(
                            _riskText(percentage, (s['absent'] as int?) ?? 0, (s['total'] as int?) ?? 0, required),
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
      ),
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
    final streak = _calculateStreak(_selectedSubject!);

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
            if (streak > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: const Icon(Icons.local_fire_department, size: 16, color: Colors.amber),
                  label: Text('$streak day streak'),
                  backgroundColor: Colors.amber.withOpacity(0.1),
                  side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                ),
              ),
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
                            if (streak > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$streak streak',
                                    style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
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
                  _riskText(percentage, (s['absent'] as int?) ?? 0, (s['total'] as int?) ?? 0, required),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _riskColor(percentage, required),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusChip('Present', (s['present'] as int?) ?? 0, Colors.green),
                  _buildStatusChip('Absent', (s['absent'] as int?) ?? 0, Colors.red),
                  _buildStatusChip('Late', (s['late'] as int?) ?? 0, Colors.orange),
                  _buildStatusChip('Excused', (s['excused'] as int?) ?? 0, Colors.blue),
                ],
              ),
              const SizedBox(height: 24),
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
                          'No schedule set. Add session timings to get reminders.',
                          style: TextStyle(color: cs.outline, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._schedules.map((sched) {
                  final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final dayIndex = ((sched['dayOfWeek'] as int?) ?? 1) - 1;
                  final dayName = dayIndex >= 0 && dayIndex < 7 ? dayNames[dayIndex] : '?';
                  final start = _formatTimeMinutes((sched['startTimeMinutes'] as int?) ?? 0);
                  final end = _formatTimeMinutes((sched['endTimeMinutes'] as int?) ?? 0);
                  final room = sched['room'] as String?;
                  final professor = sched['professor'] as String?;
                  final type = (sched['scheduleType'] as String? ?? 'revision').toUpperCase();

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
                        onPressed: () => _deleteSchedule((sched['id'] as int?) ?? 0),
                      ),
                    ),
                  );
                }).toList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _addSchedule((s['id'] as int?) ?? 0),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Session'),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Quick Mark', cs),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _markAttendance(_selectedSubject!, 'present', DateTime.now());
                        await _loadData();
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
                  final dt = DateTime.fromMillisecondsSinceEpoch((log['dateMillis'] as int?) ?? 0);
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
        ),
      ],
    );
  }
}

