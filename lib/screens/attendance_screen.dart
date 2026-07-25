// FILE: lib/screens/attendance_screen.dart
// COMPLETE NEW FILE — Advanced Attendance Tracker with analytics, risk prediction, widgets

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _currentWeekStart = 0;

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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final subjects = await DatabaseHelper.instance.getAttendanceSubjects();
    final subjectData = <Map<String, dynamic>>[];

    for (final name in subjects) {
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

      subjectData.add({
        'name': name,
        'percentage': percentage,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'total': total,
        'color': _subjectColor(name),
      });
    }

    subjectData.sort((a, b) => (a['percentage'] as double).compareTo(b['percentage'] as double));

    if (mounted) {
      setState(() {
        _subjects = subjectData;
        _loading = false;
      });
    }

    if (_selectedSubject != null) {
      await _loadLogsForSubject(_selectedSubject!);
    }

    await WidgetService.refreshAttendanceWidget();
  }

  Color _subjectColor(String name) {
    final colors = [
      Colors.red, Colors.orange, Colors.amber, Colors.green,
      Colors.teal, Colors.blue, Colors.indigo, Colors.purple, Colors.pink,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Future<void> _loadLogsForSubject(String subject) async {
    final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subject);
    setState(() {
      _selectedSubject = subject;
      _logs = logs;
    });
  }

  Future<void> _addSubject() async {
    final controller = TextEditingController();
    final reqController = TextEditingController(text: '75');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Subject Name',
                hintText: 'e.g., Physics',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reqController,
              decoration: const InputDecoration(
                labelText: 'Required %',
                hintText: '75',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'name': controller.text.trim(),
                  'required': double.tryParse(reqController.text) ?? 75,
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    reqController.dispose();

    if (result != null) {
      await _markAttendance(result['name'] as String, 'present', DateTime.now());
      await _loadData();
    }
  }

  Future<void> _markAttendance(String subject, String status, DateTime date) async {
    final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(
      subject,
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
    );

    if (existing != null) {
      await DatabaseHelper.instance.updateAttendanceLog(existing['id'] as int, {
        'subjectName': subject,
        'dateMillis': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
        'status': status,
        'note': existing['note'],
      });
    } else {
      await DatabaseHelper.instance.insertAttendanceLog({
        'subjectName': subject,
        'dateMillis': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
        'status': status,
      });
    }

    await WidgetService.refreshAttendanceWidget();
  }

  Future<void> _showMarkDialog(String subject) async {
    final statuses = ['present', 'absent', 'late', 'excused'];
    final statusLabels = ['Present', 'Absent', 'Late', 'Excused'];
    final statusColors = [Colors.green, Colors.red, Colors.orange, Colors.blue];

    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark Attendance: $subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ),
          ],
        ),
      ),
    );

    noteController.dispose();

    if (result != null) {
      final now = DateTime.now();
      final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(
        subject,
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
      );

      if (existing != null) {
        await DatabaseHelper.instance.updateAttendanceLog(existing['id'] as int, {
          'subjectName': subject,
          'dateMillis': DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
          'status': result['status'],
          'note': noteController.text.trim().isEmpty ? existing['note'] : noteController.text.trim(),
        });
      } else {
        await DatabaseHelper.instance.insertAttendanceLog({
          'subjectName': subject,
          'dateMillis': DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
          'status': result['status'],
          'note': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        });
      }

      HapticFeedback.mediumImpact();
      await _loadData();
      if (_selectedSubject == subject) {
        await _loadLogsForSubject(subject);
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
        });
      }
    }

    HapticFeedback.mediumImpact();
    await _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All subjects marked present for today!')),
    );
  }

  Future<void> _deleteSubject(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Delete all attendance data for "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(name);
      final db = await DatabaseHelper.instance.database;
      for (final log in logs) {
        await db.delete('attendance_logs', where: 'id = ?', whereArgs: [log['id']]);
      }
      await _loadData();
      if (_selectedSubject == name) {
        setState(() => _selectedSubject = null);
      }
    }
  }

  String _riskText(double percentage, int absent, int total) {
    if (total == 0) return 'No data yet';
    if (percentage >= 75) {
      final canMiss = ((total * 0.75 - (total - absent)) / 0.25).floor();
      return 'Can miss ${max(0, canMiss)} more classes';
    } else {
      final needAttend = ((0.75 * total - (total - absent)) / 0.75).ceil();
      return 'Need to attend $needAttend more';
    }
  }

  Color _riskColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    if (percentage >= 60) return Colors.deepOrange;
    return Colors.red;
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
        const Divider(),
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

    final atRisk = _subjects.where((s) => (s['percentage'] as double) < 75).length;

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
                      '$atRisk subject${atRisk == 1 ? '' : 's'} below 75% attendance!',
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final s = _subjects[index];
        final percentage = s['percentage'] as double;
        final color = s['color'] as Color;
        final name = s['name'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _loadLogsForSubject(name),
            borderRadius: BorderRadius.circular(12),
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
                          color: _riskColor(percentage).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _riskColor(percentage),
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
                      valueColor: AlwaysStoppedAnimation(_riskColor(percentage)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${s['present']}/${s['total']} classes • ${s['absent']} absences',
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                      Text(
                        _riskText(percentage, s['absent'] as int, s['total'] as int),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _riskColor(percentage),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                        icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                        onPressed: () => _deleteSubject(name),
                      ),
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

  Widget _buildSubjectDetail(ColorScheme cs) {
    final s = _subjects.firstWhere(
      (sub) => sub['name'] == _selectedSubject,
      orElse: () => {},
    );
    if (s.isEmpty) return const SizedBox.shrink();

    final percentage = s['percentage'] as double;
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
              icon: const Icon(Icons.edit_calendar),
              onPressed: () => _showMarkDialog(_selectedSubject!),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 10,
                        backgroundColor: cs.outlineVariant.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                      ),
                      CircularProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        strokeWidth: 10,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(_riskColor(percentage)),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _riskColor(percentage),
                              ),
                            ),
                            Text(
                              'Attendance',
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusChip('Present', s['present'] as int, Colors.green),
                  _buildStatusChip('Absent', s['absent'] as int, Colors.red),
                  _buildStatusChip('Late', s['late'] as int, Colors.orange),
                  _buildStatusChip('Excused', s['excused'] as int, Colors.blue),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Recent Logs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const SizedBox(height: 12),
              ..._logs.take(30).map((log) {
                final dt = DateTime.fromMillisecondsSinceEpoch(log['dateMillis'] as int);
                final status = log['status'] as String;
                final statusColor = {
                  'present': Colors.green,
                  'absent': Colors.red,
                  'late': Colors.orange,
                  'excused': Colors.blue,
                }[status] ?? Colors.grey;

                return ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, color: statusColor, size: 12),
                  title: Text('${dt.day}/${dt.month}/${dt.year}'),
                  trailing: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: log['note'] != null ? Text(log['note'] as String) : null,
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
