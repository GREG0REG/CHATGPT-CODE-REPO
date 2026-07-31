// FILE: lib/screens/timetable_screen.dart
// COMPLETE REPLACEMENT — NEET Aspirant Ultimate Timetable v3.0
// FIXES: Added missing DailyGoal import, fixed Color.value deprecation
// NEW FEATURES: NEET Subject Color Coding, Revision Slot toggle,
//               Mock Test Schedule countdown, Subject Hours Tracker,
//               Subject Mastery Progress, Daily MCQ Target Banner,
//               NEET Exam Date Countdown, Smart Break Suggestions

import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:event_countdown/database_helper.dart';
import 'package:event_countdown/models/daily_goal.dart';
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

  // -- Pomodoro timer state --
  Timer? _pomodoroTimer;
  int _pomodoroSecondsLeft = 0;
  bool _isPomodoroRunning = false;
  String? _activePomodoroSubject;
  int _pomodoroTotalMinutes = 25;

  // -- NEW: Mock test schedule cache --
  List<Map<String, dynamic>> _mockTests = [];
  int _nextMockTestDays = -1;

  // -- NEW: Daily MCQ target --
  int _mcqTarget = 100;
  int _mcqAttempted = 0;
  int _mcqCorrect = 0;

  // Timeline constants: 5 AM to 12 AM (NEET schedule)
  static const int _timelineStartHour = 5;
  static const int _timelineEndHour = 24;
  static const int _timelineStartMinutes = _timelineStartHour * 60;
  static const int _timelineEndMinutes = _timelineEndHour * 60;
  static const int _totalTimelineMinutes = _timelineEndMinutes - _timelineStartMinutes;
  static const double _hourHeight = 64.0;
  static const double _timelineWidth = 60.0;

  // NEET constants
  static const List<String> _pcbSubjects = ['Physics', 'Chemistry', 'Biology', 'Zoology', 'Botany'];
  static const int _minWeeklyHoursPerSubject = 6;

  // -- NEW: NEET Subject Color Coding --
  static const Map<String, String> _neetSubjectColors = {
    'Physics': '#1565C0',    // Deep Blue
    'Chemistry': '#2E7D32',  // Green
    'Biology': '#C62828',    // Red
    'Zoology': '#C62828',    // Red (same as Biology)
    'Botany': '#C62828',     // Red (same as Biology)
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await _loadClasses();
    await _loadTasks();
    await _loadMockTests();
    await _loadMcqStats();
    if (mounted) setState(() => _loading = false);
    await WidgetService.refreshTimetableWidget();
    await WidgetService.refreshAttendanceWidget();
    await WidgetService.refreshHabitWidget();
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

  // -- NEW: Load mock test schedules --
  Future<void> _loadMockTests() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'timetable_tasks',
      where: 'taskType = ? AND dueDateMillis >= ?',
      whereArgs: ['exam', now],
      orderBy: 'dueDateMillis ASC',
      limit: 5,
    );
    setState(() => _mockTests = rows);
    if (rows.isNotEmpty) {
      final nextTest = DateTime.fromMillisecondsSinceEpoch(rows.first['dueDateMillis'] as int);
      final diff = nextTest.difference(DateTime.now()).inDays;
      setState(() => _nextMockTestDays = diff);
    } else {
      setState(() => _nextMockTestDays = -1);
    }
  }

  // -- NEW: Load daily MCQ stats from study_sessions --
  Future<void> _loadMcqStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    final sessions = await DatabaseHelper.instance.getStudySessionsForDateRange(todayStart, todayEnd);
    int attempted = 0;
    int correct = 0;
    for (final session in sessions) {
      attempted += (session.mcqsAttempted ?? 0).toInt();
      correct += (session.mcqsCorrect ?? 0).toInt();
    }
    setState(() {
      _mcqAttempted = attempted;
      _mcqCorrect = correct;
    });
  }

  // ============================================================================
  // FEATURE 1: REVISION CYCLE TRACKER
  // ============================================================================
  Map<String, int> _getTodayRevisionCount() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;
    final Map<String, int> revisionCount = {};
    for (final s in _pcbSubjects) revisionCount[s] = 0;

    for (final task in _tasks) {
      final due = task['dueDateMillis'] as int?;
      final type = task['taskType'] as String?;
      final subject = task['subjectName'] as String?;
      if (due != null && due >= todayStart && due < todayEnd &&
          type == 'study_block' && subject != null) {
        for (final pcb in _pcbSubjects) {
          if (subject.toLowerCase().contains(pcb.toLowerCase())) {
            revisionCount[pcb] = (revisionCount[pcb] ?? 0) + 1;
          }
        }
      }
    }
    return revisionCount;
  }

  Color _revisionStatusColor(int count) {
    if (count >= 3) return Colors.green;
    if (count >= 1) return Colors.orange;
    return Colors.red;
  }

  String _revisionStatusLabel(int count) {
    if (count >= 3) return 'On Track';
    if (count >= 1) return 'Needs More';
    return 'Not Started';
  }

  // ============================================================================
  // FEATURE 2: POMODORO TIMER
  // ============================================================================
  void _startPomodoro(String subject, {int minutes = 25}) {
    setState(() {
      _isPomodoroRunning = true;
      _pomodoroTotalMinutes = minutes;
      _pomodoroSecondsLeft = minutes * 60;
      _activePomodoroSubject = subject;
    });
    _pomodoroTimer?.cancel();
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_pomodoroSecondsLeft > 0) {
          _pomodoroSecondsLeft--;
        } else {
          _onPomodoroComplete();
        }
      });
    });
  }

  void _pausePomodoro() {
    _pomodoroTimer?.cancel();
    setState(() => _isPomodoroRunning = false);
  }

  void _cancelPomodoro() {
    _pomodoroTimer?.cancel();
    setState(() {
      _isPomodoroRunning = false;
      _pomodoroSecondsLeft = 0;
      _activePomodoroSubject = null;
    });
  }

  Future<void> _onPomodoroComplete() async {
    _pomodoroTimer?.cancel();
    HapticFeedback.heavyImpact();
    final subject = _activePomodoroSubject ?? 'General';
    final minutes = _pomodoroTotalMinutes;

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('study_sessions', {
      'eventId': null,
      'subjectTag': subject,
      'durationMinutes': minutes,
      'completedAtMillis': now,
      'sessionType': 'pomodoro',
      'notes': 'Pomodoro from timetable',
      'distractionCount': 0,
      'intensityRating': 3,
      'topicTag': subject,
    });

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final goal = await DatabaseHelper.instance.getDailyGoalForDate(todayStart);
    if (goal != null) {
      await DatabaseHelper.instance.addAchievedMinutes(todayStart, minutes);
      await DatabaseHelper.instance.addAchievedPomodoro(todayStart);
    } else {
      await DatabaseHelper.instance.insertOrUpdateDailyGoal(
        DailyGoal(dateMillis: todayStart, achievedMinutes: minutes, achievedPomodoros: 1),
      );
    }

    setState(() {
      _isPomodoroRunning = false;
      _pomodoroSecondsLeft = 0;
      _activePomodoroSubject = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pomodoro complete! $minutes min of $subject logged.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _formatPomodoroTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
  }

  // ============================================================================
  // FEATURE 3: SUBJECT BALANCE METER
  // ============================================================================
  Future<Map<String, double>> _getWeeklySubjectHours() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)).millisecondsSinceEpoch;
    final weekEnd = weekStart + const Duration(days: 7).inMilliseconds;
    final db = await DatabaseHelper.instance.database;

    final Map<String, double> subjectHours = {};
    for (final s in _pcbSubjects) subjectHours[s] = 0;

    final classRows = await db.query('timetable_classes');
    for (final c in classRows) {
      final subject = c['subjectName'] as String? ?? '';
      final start = ((c['startTimeMinutes'] as num?) ?? 0).toInt();
      final end = ((c['endTimeMinutes'] as num?) ?? 0).toInt();
      final duration = (end - start) / 60.0;
      for (final pcb in _pcbSubjects) {
        if (subject.toLowerCase().contains(pcb.toLowerCase())) {
          subjectHours[pcb] = (subjectHours[pcb] ?? 0) + duration;
        }
      }
    }

    final sessionRows = await db.rawQuery(
      "SELECT subjectTag, SUM(durationMinutes) as total FROM study_sessions"
      " WHERE completedAtMillis >= ? AND completedAtMillis < ? GROUP BY subjectTag",
      [weekStart, weekEnd]);
    for (final row in sessionRows) {
      final subject = (row['subjectTag'] as String?) ?? '';
      final minutes = ((row['total'] as num?) ?? 0).toInt();
      for (final pcb in _pcbSubjects) {
        if (subject.toLowerCase().contains(pcb.toLowerCase())) {
          subjectHours[pcb] = (subjectHours[pcb] ?? 0) + (minutes / 60.0);
        }
      }
    }
    return subjectHours;
  }

  // ============================================================================
  // FEATURE 4: STREAK HEATMAP
  // ============================================================================
  Future<Map<int, int>> _getWeeklyStudyMinutes() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final db = await DatabaseHelper.instance.database;
    final Map<int, int> dayMinutes = {};

    for (int i = 0; i < 7; i++) {
      final dayStart = weekStart.add(Duration(days: i));
      final startMillis = DateTime(dayStart.year, dayStart.month, dayStart.day).millisecondsSinceEpoch;
      final endMillis = startMillis + const Duration(days: 1).inMilliseconds;
      final result = await db.rawQuery(
        "SELECT COALESCE(SUM(durationMinutes), 0) as total FROM study_sessions"
        " WHERE completedAtMillis >= ? AND completedAtMillis < ?",
        [startMillis, endMillis]);
      dayMinutes[i] = ((result.first['total'] as num?) ?? 0).toInt();
    }
    return dayMinutes;
  }

  Color _heatmapColor(int minutes) {
    if (minutes >= 300) return Colors.green;
    if (minutes >= 180) return Colors.lightGreen;
    if (minutes >= 60) return Colors.yellow;
    if (minutes > 0) return Colors.orange;
    return Colors.grey.shade300;
  }

  // ============================================================================
  // FEATURE 5: SMART SUBJECT ROTATION
  // ============================================================================
  Future<String?> _getWeakestSubject() async {
    final weeklyHours = await _getWeeklySubjectHours();
    String? weakest;
    double minHours = double.infinity;
    for (final entry in weeklyHours.entries) {
      if (entry.value < minHours) {
        minHours = entry.value;
        weakest = entry.key;
      }
    }
    return (minHours < _minWeeklyHoursPerSubject) ? weakest : null;
  }

  // ============================================================================
  // NEW FEATURE 6: NEET SUBJECT COLOR CODING
  // ============================================================================
  String _getNeetSubjectColor(String subjectName) {
    for (final entry in _neetSubjectColors.entries) {
      if (subjectName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return '#2196F3'; // Default blue
  }

  bool _isNeetSubject(String subjectName) {
    return _pcbSubjects.any((s) => subjectName.toLowerCase().contains(s.toLowerCase()));
  }

  // ============================================================================
  // NEW FEATURE 7: SUBJECT MASTERY PROGRESS
  // ============================================================================
  Future<Map<String, double>> _getSubjectMasteryProgress() async {
    final db = await DatabaseHelper.instance.database;
    final Map<String, double> mastery = {};
    for (final s in _pcbSubjects) mastery[s] = 0.0;

    // Calculate mastery based on study hours + MCQ accuracy
    final result = await db.rawQuery("""
      SELECT subjectTag, 
        SUM(durationMinutes) as totalMinutes,
        SUM(mcqsAttempted) as attempted,
        SUM(mcqsCorrect) as correct
      FROM study_sessions
      WHERE subjectTag IS NOT NULL
      GROUP BY subjectTag
    """);

    for (final row in result) {
      final subject = (row['subjectTag'] as String?) ?? '';
      final minutes = ((row['totalMinutes'] as num?) ?? 0).toInt();
      final attempted = ((row['attempted'] as num?) ?? 0).toInt();
      final correct = ((row['correct'] as num?) ?? 0).toInt();

      for (final pcb in _pcbSubjects) {
        if (subject.toLowerCase().contains(pcb.toLowerCase())) {
          // Mastery = 50% from hours (max 20h = 100%) + 50% from accuracy
          double hoursScore = (minutes / 60.0 / 20.0).clamp(0.0, 1.0) * 50.0;
          double accuracyScore = attempted > 0
              ? ((correct / attempted) * 100).clamp(0.0, 100.0) * 0.5
              : 0.0;
          mastery[pcb] = (hoursScore + accuracyScore).clamp(0.0, 100.0);
        }
      }
    }
    return mastery;
  }

  // ============================================================================
  // NEW FEATURE 8: SMART BREAK SUGGESTIONS
  // ============================================================================
  List<Map<String, dynamic>> _getSmartBreakSuggestions() {
    final freeSlots = _getFreeSlotsForDay(_selectedDay);
    final suggestions = <Map<String, dynamic>>[];

    for (final slot in freeSlots) {
      final duration = slot['duration'] as int;
      if (duration >= 15 && duration <= 45) {
        suggestions.add({
          'start': slot['start'],
          'end': slot['end'],
          'duration': duration,
          'type': duration >= 30 ? 'power_nap' : 'quick_break',
          'label': duration >= 30 ? 'Power Nap 🛌' : 'Quick Break ☕',
        });
      }
    }
    return suggestions;
  }

  // ============================================================================
  // ADD CLASS (with NEET quick-subject chips + Revision Slot toggle + Color Coding)
  // ============================================================================
  Future<void> _addClass() async {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final profController = TextEditingController();
    final noteController = TextEditingController();
    String classType = 'lecture';
    int startMinutes = 540;
    int endMinutes = 600;
    int dayOfWeek = _selectedDay + 1;
    bool isRecurring = true;
    bool isRevisionSlot = false; // -- NEW: Revision Slot toggle
    DateTime? startDate;
    DateTime? endDate;

    final types = ['lecture', 'lab', 'tutorial', 'seminar', 'exam', 'quiz', 'revision'];
    final typeLabels = ['Lecture', 'Lab', 'Tutorial', 'Seminar', 'Exam', 'Quiz', 'Revision'];
    final typeColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.red, Colors.orange, Colors.amber];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Auto-assign color based on subject
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
                    decoration: const InputDecoration(
                      labelText: 'Subject Name *',
                      prefixIcon: Icon(Icons.book),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  // -- NEET quick subject chips --
                  Wrap(
                    spacing: 6,
                    children: _pcbSubjects.map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        nameController.text = s;
                        setDialogState(() {});
                      },
                      backgroundColor: _hexToColor(_neetSubjectColors[s] ?? '#2196F3').withOpacity(0.1),
                      side: BorderSide(color: _hexToColor(_neetSubjectColors[s] ?? '#2196F3').withOpacity(0.3)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  // -- NEW: Revision Slot toggle --
                  if (_isNeetSubject(nameController.text))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('NEET Revision Slot'),
                      subtitle: const Text('Mark as dedicated revision period'),
                      value: isRevisionSlot,
                      onChanged: (v) => setDialogState(() => isRevisionSlot = v),
                    ),
                  const SizedBox(height: 8),
                  // -- NEW: Auto color preview --
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
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _hexToColor(autoColor),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Auto color: $autoColor',
                            style: TextStyle(fontSize: 12, color: _hexToColor(autoColor)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: classType,
                    decoration: const InputDecoration(
                      labelText: 'Class Type', prefixIcon: Icon(Icons.category),
                    ),
                    items: List.generate(types.length, (i) => DropdownMenuItem(
                      value: types[i],
                      child: Row(children: [
                        Icon(Icons.circle, color: typeColors[i], size: 12),
                        const SizedBox(width: 8),
                        Text(typeLabels[i]),
                      ]),
                    )),
                    onChanged: (v) => setDialogState(() => classType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration: const InputDecoration(
                      labelText: 'Day', prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(7, (i) => DropdownMenuItem(
                      value: i + 1, child: Text(_dayNames[i]),
                    )),
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
                          if (time != null) setDialogState(() => endMinutes = time.hour * 60 + time.minute);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
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
                      subtitle: Text(startDate != null ? '${startDate!.day}/${startDate!.month}/${startDate!.year}' : 'Not set', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.date_range, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (picked != null) setDialogState(() => startDate = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Date', style: TextStyle(fontSize: 12)),
                      subtitle: Text(endDate != null ? '${endDate!.day}/${endDate!.month}/${endDate!.year}' : 'Not set', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.date_range, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 90)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
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
                    'startDate': startDate,
                    'endDate': endDate,
                    'isRevisionSlot': isRevisionSlot,
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
        'colorHex': autoColor, // -- NEW: Auto NEET color coding
        'isRecurring': (result['isRecurring'] as bool) ? 1 : 0,
        'startDateMillis': result['startDate'] != null
            ? DateTime(result['startDate'].year, result['startDate'].month, result['startDate'].day).millisecondsSinceEpoch
            : null,
        'endDateMillis': result['endDate'] != null
            ? DateTime(result['endDate'].year, result['endDate'].month, result['endDate'].day).millisecondsSinceEpoch
            : null,
        'note': result['isRevisionSlot'] == true
            ? '[REVISION SLOT] ${result['note']}'
            : result['note'],
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  // ============================================================================
  // ADD TASK (with NEET quick-subject chips)
  // ============================================================================
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
                      value: types[i], child: Text(typeLabels[i]),
                    )),
                    onChanged: (v) => setDialogState(() => taskType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Subject (optional)', prefixIcon: Icon(Icons.book)),
                  ),
                  const SizedBox(height: 8),
                  // -- NEET quick subject chips --
                  Wrap(
                    spacing: 6,
                    children: _pcbSubjects.map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () => subjectController.text = s,
                      backgroundColor: _hexToColor(_neetSubjectColors[s] ?? '#2196F3').withOpacity(0.1),
                      side: BorderSide(color: _hexToColor(_neetSubjectColors[s] ?? '#2196F3').withOpacity(0.3)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
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

  // ============================================================================
  // SUGGEST STUDY BLOCK — ENHANCED with Smart Subject Rotation
  // ============================================================================
  Future<void> _suggestStudyBlock() async {
    final freeSlots = _getFreeSlotsForDay(_selectedDay);
    if (freeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No free slots available today')));
      return;
    }

    freeSlots.sort((a, b) => (b['duration'] as int).compareTo(a['duration'] as int));
    final bestSlot = freeSlots.first;

    // -- Smart subject suggestion --
    final weakestSubject = await _getWeakestSubject();
    final suggestedSubject = weakestSubject ?? 'Physics';

    final subjectController = TextEditingController(text: suggestedSubject);
    int durationMinutes = (bestSlot['duration'] as int).clamp(30, 120);
    int startMinutes = bestSlot['start'] as int;

    final neetSubjects = ['Physics', 'Chemistry', 'Biology', 'Zoology', 'Botany'];

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
                  // -- Smart suggestion banner --
                  if (weakestSubject != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You are falling behind in $weakestSubject! Prioritize it.',
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        itemBuilder: (context) => neetSubjects.map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duration', prefixIcon: Icon(Icons.timer)),
                    items: [30, 45, 60, 90, 120, 150, 180].map((m) => DropdownMenuItem(
                      value: m, child: Text('$m minutes'),
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
        'createdAtMillis': now,
      });
      HapticFeedback.mediumImpact();
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study block added!')));
    }
  }

  // ============================================================================
  // DELETE / TOGGLE
  // ============================================================================
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

  // ============================================================================
  // HELPERS
  // ============================================================================
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

  // -- FIXED: Use .value for compatibility --
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
        if (duration >= 30) {
          freeSlots.add({'start': currentStart, 'end': itemStart, 'duration': duration});
        }
      }
      if (itemEnd > currentStart) {
        currentStart = itemEnd;
      }
    }

    if (currentStart < _timelineEndMinutes) {
      final duration = _timelineEndMinutes - currentStart;
      if (duration >= 30) {
        freeSlots.add({'start': currentStart, 'end': _timelineEndMinutes, 'duration': duration});
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

  // ============================================================================
  // WEEK VIEW
  // ============================================================================
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
            side: BorderSide(
              color: isToday ? cs.primary : cs.outlineVariant.withOpacity(0.3),
              width: isToday ? 2 : 1,
            ),
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
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: isToday ? cs.primary : cs.outline, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_dayNames[dayIndex]} ${dayDate.day}/${dayDate.month}',
                        style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.w600, color: isToday ? cs.primary : cs.onSurface),
                      ),
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
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${c['subjectName']} • ${_formatMinutes24(c['startTimeMinutes'] as int)}',
                              style: TextStyle(fontSize: 11, color: color.withOpacity(0.9), fontWeight: FontWeight.w500),
                            ),
                          );
                        }),
                        ...dayTasks.map((t) {
                          final color = _typeColor(t['taskType'] as String);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              t['title'] as String,
                              style: TextStyle(fontSize: 11, color: color.withOpacity(0.9), fontWeight: FontWeight.w500),
                            ),
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

  // ============================================================================
  // BUILD — MAIN METHOD with ALL NEET FEATURES
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayClasses = _getClassesForDay(_selectedDay);
    final dayTasks = _getTasksForDay(_selectedDay);
    final conflicts = _detectConflicts(dayClasses);
    final freeSlots = _getFreeSlotsForDay(_selectedDay);
    final hasAnyItems = dayClasses.isNotEmpty || dayTasks.isNotEmpty;
    final todayRevisions = _getTodayRevisionCount();

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
              const PopupMenuItem(value: 'task', child: ListTile(leading: Icon(Icons.assignment), title: Text('Add Task'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _weekView
              ? _buildWeekView(cs)
              : Column(
                  children: [
                    // =========================================================================
                    // Pomodoro Timer Banner (when active)
                    // =========================================================================
                    if (_isPomodoroRunning)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: cs.primary.withOpacity(0.2), shape: BoxShape.circle),
                              child: Icon(Icons.timer, color: cs.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pomodoro: ${_activePomodoroSubject ?? 'Study'}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer, fontSize: 13),
                                  ),
                                  Text(
                                    _formatPomodoroTime(_pomodoroSecondsLeft),
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.primary, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.pause_circle_filled),
                                  onPressed: _pausePomodoro,
                                  color: cs.primary,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.stop_circle),
                                  onPressed: _cancelPomodoro,
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // =========================================================================
                    // NEW: Mock Test Schedule Countdown Banner
                    // =========================================================================
                    if (_nextMockTestDays >= 0)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _nextMockTestDays <= 3 ? Colors.red.withOpacity(0.08) : Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _nextMockTestDays <= 3 ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.quiz,
                              size: 20,
                              color: _nextMockTestDays <= 3 ? Colors.red : Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Next Mock Test: ${_mockTests.isNotEmpty ? _mockTests.first['title'] : 'Unknown'}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _nextMockTestDays <= 3 ? Colors.red.shade800 : Colors.blue.shade800,
                                    ),
                                  ),
                                  Text(
                                    _nextMockTestDays == 0
                                        ? 'TODAY! Good luck! 🎯'
                                        : _nextMockTestDays == 1
                                            ? 'Tomorrow! Final revision needed'
                                            : '$_nextMockTestDays days remaining',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _nextMockTestDays <= 3 ? Colors.red.shade600 : Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_nextMockTestDays <= 7)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _nextMockTestDays <= 3 ? Colors.red : Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _nextMockTestDays <= 3 ? 'URGENT' : 'SOON',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // =========================================================================
                    // NEW: Daily MCQ Target Banner
                    // =========================================================================
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.psychology, size: 20, color: Colors.indigo.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily MCQ Target',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.indigo.shade800,
                                  ),
                                ),
                                Text(
                                  '$_mcqAttempted / $_mcqTarget attempted • ${_mcqAttempted > 0 ? ((_mcqCorrect / _mcqAttempted * 100).toStringAsFixed(1)) : '0.0'}% accuracy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  value: _mcqTarget > 0 ? (_mcqAttempted / _mcqTarget).clamp(0.0, 1.0) : 0,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.indigo.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _mcqAttempted >= _mcqTarget ? Colors.green : Colors.indigo,
                                  ),
                                ),
                              ),
                              Text(
                                '${(_mcqTarget > 0 ? (_mcqAttempted / _mcqTarget * 100).clamp(0, 100) : 0).round()}%',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // =========================================================================
                    // Revision Cycle Tracker (compact chips)
                    // =========================================================================
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sync, size: 16, color: cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                "Today's Revisions",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _pcbSubjects.map((subject) {
                              final count = todayRevisions[subject] ?? 0;
                              final statusColor = _revisionStatusColor(count);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$subject: $count',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor.withOpacity(0.9)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _revisionStatusLabel(count),
                                      style: TextStyle(fontSize: 9, color: statusColor.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // =========================================================================
                    // Subject Balance Meter
                    // =========================================================================
                    FutureBuilder<Map<String, double>>(
                      future: _getWeeklySubjectHours(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final hours = snapshot.data!;
                        final hasImbalance = hours.entries.any((e) => e.value < _minWeeklyHoursPerSubject && e.value > 0);
                        if (!hasImbalance && hours.values.every((v) => v == 0)) return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: hasImbalance ? Colors.orange.withOpacity(0.08) : Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: hasImbalance ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    hasImbalance ? Icons.warning_amber_rounded : Icons.check_circle,
                                    size: 16,
                                    color: hasImbalance ? Colors.orange : Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hasImbalance ? 'Subject Balance Alert' : 'Subject Balance: Good',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hasImbalance ? Colors.orange.shade800 : Colors.green.shade800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: hours.entries.map((e) {
                                  final isLow = e.value < _minWeeklyHoursPerSubject && e.value > 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isLow ? Colors.red.withOpacity(0.08) : Colors.green.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isLow ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '${e.key}: ${e.value.toStringAsFixed(1)}h${isLow ? ' ⚠️' : ' ✓'}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLow ? Colors.red : Colors.green.shade700),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // =========================================================================
                    // NEW: Subject Mastery Progress
                    // =========================================================================
                    FutureBuilder<Map<String, double>>(
                      future: _getSubjectMasteryProgress(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final mastery = snapshot.data!;
                        if (mastery.values.every((v) => v == 0)) return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trending_up, size: 16, color: cs.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Subject Mastery',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface),
                                  ),
                                ],
                              ),
                                                            const SizedBox(height: 8),
                              ...mastery.entries.map((e) {
                                final progress = e.value / 100.0;
                                final color = _hexToColor(_neetSubjectColors[e.key] ?? '#2196F3');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          e.key,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: progress.clamp(0.0, 1.0),
                                            minHeight: 8,
                                            backgroundColor: color.withOpacity(0.1),
                                            valueColor: AlwaysStoppedAnimation<Color>(color),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${e.value.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),

                    // =========================================================================
                    // NEW: Smart Break Suggestions
                    // =========================================================================
                    Builder(
                      builder: (context) {
                        final breakSuggestions = _getSmartBreakSuggestions();
                        if (breakSuggestions.isEmpty) return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.coffee, size: 16, color: Colors.teal.shade700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Smart Break Suggestions',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.teal.shade800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: breakSuggestions.map((breakSlot) {
                                  return ActionChip(
                                    avatar: Icon(
                                      breakSlot['type'] == 'power_nap' ? Icons.bedtime : Icons.coffee,
                                      size: 14,
                                      color: Colors.teal.shade700,
                                    ),
                                    label: Text(
                                      '${breakSlot['label']} at ${_formatMinutes(breakSlot['start'] as int)}',
                                      style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                                    ),
                                    backgroundColor: Colors.teal.withOpacity(0.1),
                                    side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${breakSlot['label']} scheduled! Rest is important for retention.'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // =========================================================================
                    // Smart Recommendation Chip
                    // =========================================================================
                    FutureBuilder<String?>(
                      future: _getWeakestSubject(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                        final weakSubject = snapshot.data!;
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.purple.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.psychology, size: 16, color: Colors.purple.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🎯 Focus on $weakSubject today — you\'re falling behind!',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple.shade800),
                                ),
                              ),
                              TextButton(
                                onPressed: _suggestStudyBlock,
                                child: Text('Fix It', style: TextStyle(fontSize: 12, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // =========================================================================
                    // Day Selector with Heatmap Overlay
                    // =========================================================================
                    FutureBuilder<Map<int, int>>(
                      future: _getWeeklyStudyMinutes(),
                      builder: (context, heatmapSnapshot) {
                        final heatmap = heatmapSnapshot.data ?? {};
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
                              final studyMinutes = heatmap[i] ?? 0;
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
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
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
                                          // Heatmap dot
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: _heatmapColor(studyMinutes),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: cs.surface, width: 1),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
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

                    // All-day tasks banner
                    ...dayTasks.where((t) => (t['isAllDay'] as int? ?? 0) == 1).map((t) {
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
                    }),

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
                      style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
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

                  // Free time gap labels
                  ...freeSlots.map((slot) => _buildFreeTimeSlot(slot, cs)),

                  // Class blocks
                  ...dayClasses.map((c) => _buildClassBlock(c, conflicts, cs)),

                  // Task blocks (only timed tasks, not all-day)
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
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          Expanded(
            child: Container(height: 2, color: Colors.red.withOpacity(0.5)),
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

  // ============================================================================
  // CLASS BLOCK — ENHANCED with Pomodoro start button + NEET Color Coding
  // ============================================================================
  Widget _buildClassBlock(Map<String, dynamic> c, List<Map<String, dynamic>> conflicts, ColorScheme cs) {
    final start = c['startTimeMinutes'] as int;
    final end = c['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = math.max(40.0, _durationToPixels(end - start));
    final storedColor = c['colorHex'] as String? ?? '#2196F3';
    final color = _hexToColor(storedColor);
    final isConflict = conflicts.any((conf) =>
        conf['a']['id'] == c['id'] || conf['b']['id'] == c['id']);
    final subject = c['subjectName'] as String? ?? '';
    final isRevisionSlot = (c['note'] as String? ?? '').contains('[REVISION SLOT]');

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
          color: isRevisionSlot
              ? Colors.amber.withOpacity(0.15)
              : color.withOpacity(0.12),
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
                          subject,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRevisionSlot)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REV',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
                      // Quick Pomodoro button for NEET subjects
                      if (_pcbSubjects.any((s) => subject.toLowerCase().contains(s.toLowerCase())) && height > 50)
                        InkWell(
                          onTap: () => _startPomodoro(subject, minutes: 25),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer, size: 10, color: Colors.deepPurple.shade700),
                                const SizedBox(width: 2),
                                Text(
                                  '25m',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                                ),
                              ],
                            ),
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

  // ============================================================================
  // TASK BLOCK — ENHANCED with Pomodoro start button
  // ============================================================================
  Widget _buildTaskBlock(Map<String, dynamic> t, ColorScheme cs) {
    final start = t['startTimeMinutes'] as int;
    final end = t['endTimeMinutes'] as int;
    final top = _minutesToPixels(start);
    final height = math.max(36.0, _durationToPixels(end - start));
    final typeColor = _typeColor(t['taskType'] as String);
    final isDeadline = t['taskType'] == 'assignment' || t['taskType'] == 'exam';
    final isCompleted = (t['isCompleted'] as int? ?? 0) == 1;
    final subject = t['subjectName'] as String? ?? '';
    final isStudyBlock = t['taskType'] == 'study_block';

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
                      // Quick Pomodoro button for study blocks
                      if (isStudyBlock && height > 40)
                        InkWell(
                          onTap: () => _startPomodoro(subject.isNotEmpty ? subject : 'Study', minutes: 25),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow, size: 10, color: Colors.deepPurple.shade700),
                                const SizedBox(width: 2),
                                Text(
                                  'Start',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                                ),
                              ],
                            ),
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

  // ============================================================================
  // DETAIL SHEETS
  // ============================================================================
  void _showClassDetails(Map<String, dynamic> c) {
    final color = _hexToColor(c['colorHex'] as String? ?? '#2196F3');
    final subject = c['subjectName'] as String? ?? '';
    final isPcbSubject = _pcbSubjects.any((s) => subject.toLowerCase().contains(s.toLowerCase()));
    final isRevisionSlot = (c['note'] as String? ?? '').contains('[REVISION SLOT]');

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
                        subject,
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
            if (isRevisionSlot)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'NEET Revision Slot',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
                    ),
                  ],
                ),
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
              _detailRow(Icons.notes, 'Note', (c['note'] as String).replaceFirst('[REVISION SLOT] ', '')),
            const SizedBox(height: 16),
            // Start Pomodoro from details sheet
            if (isPcbSubject)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startPomodoro(subject, minutes: 25);
                },
                icon: const Icon(Icons.timer),
                label: const Text('Start 25m Pomodoro'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            const SizedBox(height: 8),
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
    final subject = t['subjectName'] as String? ?? '';
    final isStudyBlock = t['taskType'] == 'study_block';

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
            // Start Pomodoro from task details
            if (isStudyBlock)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startPomodoro(subject.isNotEmpty ? subject : 'Study', minutes: 25);
                },
                icon: const Icon(Icons.timer),
                label: const Text('Start 25m Pomodoro'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 48),
                ),
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
