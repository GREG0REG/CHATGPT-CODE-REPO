// FILE: lib/screens/attendance_detail_screen.dart
// NEW FILE — Standalone Subject Detail Screen (NEET Edition)
// FIXED: Division by zero when required=100%
// CHANGED: "Class" → "Session" throughout
// ENHANCED: Medical theme, NEET motivation, session predictor

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';

class AttendanceDetailScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final Color subjectColor;

  const AttendanceDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
  });

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _subject = {};
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _monthlyStats = [];
  late AnimationController _ringAnimation;
  late Animation<double> _ringProgress;

  static const Map<String, Color> _statusColors = {
    'present': Colors.green,
    'absent': Colors.red,
    'late': Colors.orange,
    'excused': Colors.blue,
  };

  static const Map<String, IconData> _statusIcons = {
    'present': Icons.check_circle,
    'absent': Icons.cancel,
    'late': Icons.watch_later,
    'excused': Icons.medical_services,
  };

  @override
  void initState() {
    super.initState();
    _ringAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringAnimation, curve: Curves.easeOutCubic),
    );
    _loadData();
  }

  @override
  void dispose() {
    _ringAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final subject = await DatabaseHelper.instance
        .getAttendanceSubjectById(widget.subjectId);
    if (subject == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final stats = await DatabaseHelper.instance
        .getAttendanceStatsForSubject(widget.subjectName);
    final present = (stats['present'] as int?) ?? 0;
    final absent = (stats['absent'] as int?) ?? 0;
    final late = (stats['late'] as int?) ?? 0;
    final excused = (stats['excused'] as int?) ?? 0;
    final total = (stats['total'] as int?) ?? 0;

    final effectiveTotal = total - excused;
    final percentage = effectiveTotal > 0
        ? ((present + late * 0.5) / effectiveTotal * 100)
        : 0.0;

    final required = (subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0;

    final schedules = await DatabaseHelper.instance
        .getAttendanceSchedulesForSubject(widget.subjectId);

    final allLogs = await DatabaseHelper.instance
        .getAttendanceLogsForSubject(widget.subjectName);

    final monthlyStats = await _buildMonthlyStats(widget.subjectName);

    if (mounted) {
      setState(() {
        _subject = {
          ...subject,
          'present': present,
          'absent': absent,
          'late': late,
          'excused': excused,
          'total': total,
          'percentage': percentage,
          'effectiveTotal': effectiveTotal,
        };
        _schedules = schedules;
        _logs = allLogs;
        _monthlyStats = monthlyStats;
        _loading = false;
      });
      _ringAnimation.forward(from: 0.0);
    }

    await WidgetService.refreshAttendanceWidget();
  }

  Future<List<Map<String, dynamic>>> _buildMonthlyStats(String subjectName) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final months = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final start = month.millisecondsSinceEpoch;
      final end = nextMonth.millisecondsSinceEpoch;

      final result = await db.rawQuery("""
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
          SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
          SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late
        FROM attendance_logs
        WHERE subjectName = ? AND dateMillis >= ? AND dateMillis < ?
      """, [subjectName, start, end]);

      final row = result.first;
      final total = (row['total'] as int?) ?? 0;
      final present = (row['present'] as int?) ?? 0;
      final late = (row['late'] as int?) ?? 0;
      final effective = total > 0 ? total : 1;
      final pct = ((present + late * 0.5) / effective * 100);

      months.add({
        'month': DateFormat('MMM').format(month),
        'percentage': pct,
        'total': total,
      });
    }
    return months;
  }

  String _formatTimeMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  String _dayName(int dayOfWeek) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dayOfWeek - 1];
  }

  // FIXED: Guard against division by zero when required=100
  String _riskText(double percentage, int absent, int total, double required) {
    if (total == 0) return 'Start marking attendance to see projections';
    if (required >= 100.0) {
      if (percentage >= 99.99) return 'Perfect! 100% session attendance';
      return '100% required — attend every session';
    }
    if (percentage >= required) {
      final canMiss = ((total * (required / 100) - (total - absent)) / (1 - required / 100)).floor();
      return 'On track — can miss ${max(0, canMiss)} more sessions';
    } else {
      final needAttend =
          ((required / 100 * total - (total - absent)) / (required / 100))
              .ceil();
      return 'Need to attend $needAttend more sessions to reach $required%';
    }
  }

  Color _riskColor(double percentage, double required) {
    if (percentage >= required + 10) return Colors.green;
    if (percentage >= required) return Colors.orange;
    if (percentage >= required - 15) return Colors.deepOrange;
    return Colors.red;
  }

  // FIXED: Guard against division by zero when required=100
  String _semesterProjection(double percentage, int total, double required) {
    if (total == 0) return 'Mark attendance to see semester projection';
    final semesterStart = _subject['semesterStartMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _subject['semesterStartMillis'] as int)
        : null;
    final semesterEnd = _subject['semesterEndMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _subject['semesterEndMillis'] as int)
        : null;

    if (semesterStart == null || semesterEnd == null) {
      return 'Set semester dates in Edit Subject for full projection';
    }

    final totalDays = semesterEnd.difference(semesterStart).inDays;
    final elapsedDays = DateTime.now().difference(semesterStart).inDays;
    if (elapsedDays <= 0 || totalDays <= 0) return 'Semester hasn\'t started yet';

    final progress = elapsedDays / totalDays;
    final expectedTotal = (total / progress).round();
    final expectedPresent = (expectedTotal * (percentage / 100)).round();

    final projectedPct = percentage;

    if (projectedPct >= required) {
      final buffer = projectedPct - required;
      return 'At current rate, you\'ll finish at ${projectedPct.toStringAsFixed(1)}% (${buffer.toStringAsFixed(1)}% above requirement)';
    } else {
      final shortfall = required - projectedPct;
      return 'At current rate, you\'ll hit ${projectedPct.toStringAsFixed(1)}% — ${shortfall.toStringAsFixed(1)}% below requirement!';
    }
  }

  int _currentStreak() {
    if (_logs.isEmpty) return 0;
    final sorted = _logs.toList()
      ..sort((a, b) => (b['dateMillis'] as int).compareTo(a['dateMillis'] as int));
    
    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    
    for (final log in sorted) {
      final status = log['status'] as String;
      final date = log['dateMillis'] as int;
      if (status == 'present' || status == 'late') {
        if (streak == 0 && date == today) {
          streak = 1;
        } else if (streak > 0) {
          final expectedDate = today - (streak * const Duration(days: 1).inMilliseconds);
          if (date == expectedDate) {
            streak++;
          } else {
            break;
          }
        }
      } else if (status == 'absent' && date >= today - const Duration(days: 1).inMilliseconds) {
        break;
      }
    }
    return streak;
  }

  Future<void> _markAttendance(String status, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final existing = await DatabaseHelper.instance
        .getAttendanceLogForSubjectAndDate(widget.subjectName, dayStart);

    if (existing != null) {
      await DatabaseHelper.instance.updateAttendanceLog(existing['id'] as int, {
        'subjectName': widget.subjectName,
        'subjectId': widget.subjectId,
        'dateMillis': dayStart,
        'status': status,
        'note': existing['note'],
        'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await DatabaseHelper.instance.insertAttendanceLog({
        'subjectName': widget.subjectName,
        'subjectId': widget.subjectId,
        'dateMillis': dayStart,
        'status': status,
        'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
    }

    HapticFeedback.mediumImpact();
    await _loadData();
  }

  Future<void> _showMarkDialog({DateTime? specificDate}) async {
    final date = specificDate ?? DateTime.now();
    final statuses = ['present', 'absent', 'late', 'excused'];
    final statusLabels = ['Present', 'Absent', 'Late', 'Excused'];
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark: ${widget.subjectName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEEE, dd MMM yyyy').format(date),
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(statuses.length, (i) {
              return ListTile(
                leading: Icon(
                  _statusIcons[statuses[i]],
                  color: _statusColors[statuses[i]],
                ),
                title: Text(statusLabels[i]),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.pop(ctx, {'status': statuses[i]}),
              );
            }),
            const Divider(height: 24),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g., Mock test, Revision block',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    final noteText = noteController.text.trim();
    noteController.dispose();

    if (result != null) {
      final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      final existing = await DatabaseHelper.instance
          .getAttendanceLogForSubjectAndDate(widget.subjectName, dayStart);

      if (existing != null) {
        await DatabaseHelper.instance.updateAttendanceLog(existing['id'] as int, {
          'subjectName': widget.subjectName,
          'subjectId': widget.subjectId,
          'dateMillis': dayStart,
          'status': result['status'],
          'note': noteText.isEmpty ? existing['note'] : noteText,
          'markedAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await DatabaseHelper.instance.insertAttendanceLog({
          'subjectName': widget.subjectName,
          'subjectId': widget.subjectId,
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

  Future<void> _addSchedule() async {
    int dayOfWeek = DateTime.now().weekday;
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Add Session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration: const InputDecoration(
                      labelText: 'Day of Week',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'revision', child: Text('Revision')),
                      DropdownMenuItem(value: 'practice', child: Text('Practice')),
                      DropdownMenuItem(
                          value: 'test', child: Text('Test')),
                      DropdownMenuItem(
                          value: 'review', child: Text('Review')),
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
                              initialTime: TimeOfDay(
                                hour: startTimeMinutes ~/ 60,
                                minute: startTimeMinutes % 60,
                              ),
                            );
                            if (time != null) {
                              setDialogState(() =>
                                  startTimeMinutes = time.hour * 60 + time.minute);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Time',
                              prefixIcon: Icon(Icons.access_time),
                            ),
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
                              initialTime: TimeOfDay(
                                hour: endTimeMinutes ~/ 60,
                                minute: endTimeMinutes % 60,
                              ),
                            );
                            if (time != null) {
                              setDialogState(() =>
                                  endTimeMinutes = time.hour * 60 + time.minute);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Time',
                              prefixIcon: Icon(Icons.access_time),
                            ),
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
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: professorController,
                    decoration: const InputDecoration(
                      labelText: 'Mentor (optional)',
                      hintText: 'e.g., Dr. Sharma',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
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
                onPressed: () => Navigator.pop(ctx, {
                  'subjectId': widget.subjectId,
                  'dayOfWeek': dayOfWeek,
                  'startTimeMinutes': startTimeMinutes,
                  'endTimeMinutes': endTimeMinutes,
                  'room': roomController.text.trim().isEmpty
                      ? null
                      : roomController.text.trim(),
                  'professor': professorController.text.trim().isEmpty
                      ? null
                      : professorController.text.trim(),
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
      await _loadData();
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Session?'),
        content: const Text('This session slot will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAttendanceSchedule(scheduleId);
      await _loadData();
    }
  }

  Future<void> _editSubject() async {
    final nameController =
        TextEditingController(text: _subject['name'] as String? ?? '');
    final reqController = TextEditingController(
      text: ((_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0)
          .toStringAsFixed(0),
    );
    DateTime? semesterStart = _subject['semesterStartMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _subject['semesterStartMillis'] as int)
        : null;
    DateTime? semesterEnd = _subject['semesterEndMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _subject['semesterEndMillis'] as int)
        : null;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Subject'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reqController,
                    decoration: const InputDecoration(
                      labelText: 'Required Attendance %',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
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
                                  ? DateFormat('dd MMM yyyy')
                                      .format(semesterStart!)
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
                              initialDate: semesterEnd ??
                                  DateTime.now()
                                      .add(const Duration(days: 120)),
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
                                  ? DateFormat('dd MMM yyyy')
                                      .format(semesterEnd!)
                                  : 'Select date',
                            ),
                          ),
                        ),
                      ),
                    ],
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
                      'requiredPercentage':
                          double.tryParse(reqController.text) ?? 75.0,
                      'semesterStartMillis':
                          semesterStart?.millisecondsSinceEpoch,
                      'semesterEndMillis': semesterEnd?.millisecondsSinceEpoch,
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
      await DatabaseHelper.instance.updateAttendanceSubject(widget.subjectId, {
        'name': result['name'],
        'requiredPercentage': result['requiredPercentage'],
        'semesterStartMillis': result['semesterStartMillis'],
        'semesterEndMillis': result['semesterEndMillis'],
        'colorHex': _subject['colorHex'] ?? '#2196F3',
      });
      await _loadData();
    }
  }

  Future<void> _deleteLog(int logId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Record?'),
        content: const Text('This attendance record will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAttendanceLog(logId);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  floating: false,
                  backgroundColor: widget.subjectColor,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.subjectName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.subjectColor,
                            widget.subjectColor.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Icon(
                            Icons.school,
                            size: 80,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _editSubject,
                      tooltip: 'Edit Subject',
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildProgressRing(cs),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _riskColor(
                              _subject['percentage'] as double,
                              (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _riskColor(
                                _subject['percentage'] as double,
                                (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0,
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _subject['percentage'] as double >=
                                        ((_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0)
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: _riskColor(
                                  _subject['percentage'] as double,
                                  (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _riskText(
                                    _subject['percentage'] as double,
                                    _subject['absent'] as int,
                                    _subject['total'] as int,
                                    (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _riskColor(
                                      _subject['percentage'] as double,
                                      (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_subject['semesterStartMillis'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _semesterProjection(
                                      _subject['percentage'] as double,
                                      _subject['total'] as int,
                                      (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildStatusChips(cs),
                      const SizedBox(height: 24),
                      _buildQuickMarkButtons(cs),
                      const SizedBox(height: 24),
                      if (_monthlyStats.isNotEmpty) ...[
                        _buildSectionTitle('6-Month Trend', cs),
                        const SizedBox(height: 12),
                        _buildMiniSparkline(cs),
                        const SizedBox(height: 24),
                      ],
                      _buildStreakCard(cs),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Schedule', cs),
                      const SizedBox(height: 12),
                      _buildScheduleList(cs),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Recent Logs (Last 30 Days)', cs),
                      const SizedBox(height: 12),
                      _buildRecentLogs(cs),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressRing(ColorScheme cs) {
    final percentage = (_subject['percentage'] as double).clamp(0.0, 100.0);
    final required = (_subject['requiredPercentage'] as num?)?.toDouble() ?? 75.0;
    final riskColor = _riskColor(percentage, required);

    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: AnimatedBuilder(
          animation: _ringProgress,
          builder: (context, child) {
            final animValue = _ringProgress.value * (percentage / 100);
            return Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 16,
                  backgroundColor: cs.outlineVariant.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                ),
                CircularProgressIndicator(
                  value: animValue.clamp(0.0, 1.0),
                  strokeWidth: 16,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(riskColor),
                  strokeCap: StrokeCap.round,
                ),
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _ThresholdPainter(
                    threshold: required / 100,
                    color: cs.outline.withOpacity(0.5),
                    strokeWidth: 16,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                      Text(
                        'of $required% required',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.outline,
                        ),
                      ),
                      if (percentage >= required)
                        const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChips(ColorScheme cs) {
    final present = _subject['present'] as int;
    final absent = _subject['absent'] as int;
    final late = _subject['late'] as int;
    final excused = _subject['excused'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatusChip('Present', present, Colors.green, Icons.check_circle),
          _buildStatusChip('Absent', absent, Colors.red, Icons.cancel),
          _buildStatusChip('Late', late, Colors.orange, Icons.watch_later),
          _buildStatusChip('Excused', excused, Colors.blue, Icons.medical_services),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color, IconData icon) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMarkButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Quick Mark Today', cs),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickMarkButton(
                  'Present',
                  Colors.green,
                  Icons.check_circle,
                  () => _markAttendance('present', DateTime.now()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickMarkButton(
                  'Absent',
                  Colors.red,
                  Icons.cancel,
                  () => _markAttendance('absent', DateTime.now()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickMarkButton(
                  'Late',
                  Colors.orange,
                  Icons.watch_later,
                  () => _markAttendance('late', DateTime.now()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickMarkButton(
                  'Excused',
                  Colors.blue,
                  Icons.medical_services,
                  () => _markAttendance('excused', DateTime.now()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showMarkDialog(specificDate: DateTime.now()),
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Mark with Note / Different Date'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMarkButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildMiniSparkline(ColorScheme cs) {
    final maxPct = _monthlyStats
        .map((m) => m['percentage'] as double)
        .reduce((a, b) => a > b ? a : b);
    final minPct = _monthlyStats
        .map((m) => m['percentage'] as double)
        .reduce((a, b) => a < b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _SparklinePainter(
                  data: _monthlyStats.map((m) => m['percentage'] as double).toList(),
                  maxValue: max(maxPct, 100),
                  minValue: max(minPct - 10, 0),
                  color: widget.subjectColor,
                  fillColor: widget.subjectColor.withOpacity(0.1),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _monthlyStats.map((m) {
                return Text(
                  m['month'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.outline,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(ColorScheme cs) {
    final streak = _currentStreak();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              Colors.orange.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak Day${streak == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    streak > 0
                        ? 'Current attendance streak! Keep it up!'
                        : 'No active streak. Mark present today!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList(ColorScheme cs) {
    if (_schedules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: cs.outline, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No schedule set',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Add session timings to get reminders and better tracking.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ..._schedules.map((sched) {
            final dayIndex = (sched['dayOfWeek'] as int) - 1;
            final dayName = dayIndex >= 0 && dayIndex < 7
                ? _dayName(sched['dayOfWeek'] as int)
                : '?';
            final start = _formatTimeMinutes(sched['startTimeMinutes'] as int);
            final end = _formatTimeMinutes(sched['endTimeMinutes'] as int);
            final room = sched['room'] as String?;
            final professor = sched['professor'] as String?;
            final type = (sched['scheduleType'] as String? ?? 'revision').toUpperCase();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: widget.subjectColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.subjectColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  '$start — $end',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
            onPressed: _addSchedule,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogs(ColorScheme cs) {
    final recentLogs = _logs.take(30).toList();
    if (recentLogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'No attendance records yet.',
              style: TextStyle(color: cs.outline),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: recentLogs.map((log) {
          final dt = DateTime.fromMillisecondsSinceEpoch(log['dateMillis'] as int);
          final status = log['status'] as String;
          final statusColor = _statusColors[status] ?? Colors.grey;
          final statusIcon = _statusIcons[status] ?? Icons.help;

          return Dismissible(
            key: Key('log-${log['id']}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete, color: cs.error),
            ),
            onDismissed: (_) => _deleteLog(log['id'] as int),
            child: Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                title: Text(
                  DateFormat('EEEE, dd MMM yyyy').format(dt),
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                subtitle: log['note'] != null
                    ? Text(
                        log['note'] as String,
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      )
                    : null,
                onTap: () => _showMarkDialog(specificDate: dt),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: widget.subjectColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdPainter extends CustomPainter {
  final double threshold;
  final Color color;
  final double strokeWidth;

  _ThresholdPainter({
    required this.threshold,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final angle = -pi / 2 + (threshold * 2 * pi);
    final x = center.dx + radius * cos(angle);
    final y = center.dy + radius * sin(angle);

    canvas.drawCircle(Offset(x, y), 6, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final double minValue;
  final Color color;
  final Color fillColor;

  _SparklinePainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.color,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final dx = size.width / (data.length - 1);

    double getY(double value) {
      return size.height - ((value - minValue) / (maxValue - minValue)) * size.height;
    }

    path.moveTo(0, getY(data[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      final x = i * dx;
      final y = getY(data[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo((data.length - 1) * dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(Offset(i * dx, getY(data[i])), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
