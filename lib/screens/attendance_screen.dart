// FILE: lib/screens/attendance_screen.dart
// NEW FILE — Attendance Tracker with calendar grid and subject dashboard

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<String> _subjects = [];
  Map<String, Map<String, dynamic>> _subjectStats = {};
  Map<String, List<Map<String, dynamic>>> _subjectLogs = {};
  bool _loading = true;
  String? _selectedSubject;
  DateTime _focusedMonth = DateTime.now();

  final List<String> _statusOptions = ['present', 'absent', 'late', 'excused'];
  final Map<String, Color> _statusColors = {
    'present': Colors.green,
    'absent': Colors.red,
    'late': Colors.orange,
    'excused': Colors.blue,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subjects = await DatabaseHelper.instance.getAttendanceSubjects();
    final stats = <String, Map<String, dynamic>>{};
    final logs = <String, List<Map<String, dynamic>>>{};

    for (final subject in subjects) {
      stats[subject] = await DatabaseHelper.instance.getAttendanceStatsForSubject(subject);
      logs[subject] = await DatabaseHelper.instance.getAttendanceLogsForSubject(subject);
    }

    if (mounted) {
      setState(() {
        _subjects = subjects;
        _subjectStats = stats;
        _subjectLogs = logs;
        _loading = false;
      });
    }
  }

  double _getPercentage(String subject) {
    final stats = _subjectStats[subject];
    if (stats == null) return 0;
    final total = (stats['total'] as int?) ?? 0;
    if (total == 0) return 0;
    final present = (stats['present'] as int?) ?? 0;
    final excused = (stats['excused'] as int?) ?? 0;
    return ((present + excused) / total) * 100;
  }

  Color _getPercentageColor(double pct) {
    if (pct >= 75) return Colors.green;
    if (pct >= 60) return Colors.orange;
    return Colors.red;
  }

  Future<void> _markAttendance(String subject, DateTime date, String status, {String? note}) async {
    final dateMillis = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    
    final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, dateMillis);
    
    if (existing != null) {
      await DatabaseHelper.instance.updateAttendanceLog(
        existing['id'] as int,
        {
          'subjectName': subject,
          'dateMillis': dateMillis,
          'status': status,
          'note': note,
        },
      );
    } else {
      await DatabaseHelper.instance.insertAttendanceLog({
        'subjectName': subject,
        'dateMillis': dateMillis,
        'status': status,
        'note': note,
      });
    }
    
    HapticFeedback.lightImpact();
    await _loadData();
    await WidgetService.refreshAttendanceWidget();
  }

  Future<void> _bulkMarkTodayPresent() async {
    final today = DateTime.now();
    final todayMillis = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    
    for (final subject in _subjects) {
      final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, todayMillis);
      if (existing == null) {
        await DatabaseHelper.instance.insertAttendanceLog({
          'subjectName': subject,
          'dateMillis': todayMillis,
          'status': 'present',
        });
      }
    }
    
    HapticFeedback.mediumImpact();
    await _loadData();
    await WidgetService.refreshAttendanceWidget();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All today's classes marked present")),
      );
    }
  }

  void _showStatusBottomSheet(String subject, DateTime date) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$subject — ${date.month}/${date.day}/${date.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._statusOptions.map((status) {
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: _statusColors[status],
                    ),
                    title: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: const TextStyle(fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _markAttendance(subject, date, status);
                    },
                  );
                }),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.grey,
                  ),
                  title: const Text('Clear', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final dateMillis = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
                    final existing = await DatabaseHelper.instance.getAttendanceLogForSubjectAndDate(subject, dateMillis);
                    if (existing != null) {
                      await DatabaseHelper.instance.deleteAttendanceLog(existing['id'] as int);
                      await _loadData();
                      await WidgetService.refreshAttendanceWidget();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSubjectDetail(String subject) {
    setState(() => _selectedSubject = subject);
  }

  void _backToDashboard() {
    setState(() => _selectedSubject = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedSubject != null) {
      return _buildSubjectDetailView(_selectedSubject!, cs);
    }

    return _buildDashboardView(cs);
  }

  Widget _buildDashboardView(ColorScheme cs) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_subjects.length} subjects tracked',
                    style: TextStyle(color: cs.outline),
                  ),
                  const SizedBox(height: 16),
                  if (_subjects.isEmpty)
                    _buildEmptyState(cs)
                  else
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final subject = _subjects[index];
                          final pct = _getPercentage(subject);
                          final color = _getPercentageColor(pct);
                          final stats = _subjectStats[subject]!;
                          final total = (stats['total'] as int?) ?? 0;
                          final present = (stats['present'] as int?) ?? 0;

                          return GestureDetector(
                            onTap: () => _openSubjectDetail(subject),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withOpacity(0.15),
                                    color.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CircularProgressIndicator(
                                          value: total > 0 ? pct / 100 : 0,
                                          strokeWidth: 6,
                                          backgroundColor: cs.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                        ),
                                        Center(
                                          child: Text(
                                            '${pct.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$present/$total classes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_subjects.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _bulkMarkTodayPresent,
                      icon: const Icon(Icons.done_all),
                      label: const Text("Mark all today's classes as present"),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSubjectDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
    );
  }

  Widget _buildSubjectDetailView(String subject, ColorScheme cs) {
    final logs = _subjectLogs[subject] ?? [];
    final stats = _subjectStats[subject]!;
    final pct = _getPercentage(subject);
    final color = _getPercentageColor(pct);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToDashboard,
        ),
        title: Text(subject),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteSubjectDialog(subject),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  cs.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow('Present', stats['present'] ?? 0, Colors.green),
                      _buildStatRow('Absent', stats['absent'] ?? 0, Colors.red),
                      _buildStatRow('Late', stats['late'] ?? 0, Colors.orange),
                      _buildStatRow('Excused', stats['excused'] ?? 0, Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Calendar
          Expanded(
            child: _buildCalendarGrid(subject, logs, cs),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStatusBottomSheet(subject, DateTime.now()),
        child: const Icon(Icons.edit_calendar),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13)),
          Text(
            '$count',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(String subject, List<Map<String, dynamic>> logs, ColorScheme cs) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    // Build log lookup
    final logMap = <int, String>{};
    for (final log in logs) {
      final date = DateTime.fromMillisecondsSinceEpoch(log['dateMillis'] as int);
      if (date.year == year && date.month == month) {
        logMap[date.day] = log['status'] as String;
      }
    }

    return Column(
      children: [
        // Month navigator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(year, month - 1);
                }),
              ),
              Text(
                '${_monthName(month)} $year',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(year, month + 1);
                }),
              ),
            ],
          ),
        ),
        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Days grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox.shrink();
              }
              final day = index - startWeekday + 1;
              final status = logMap[day];
              final isToday = DateTime.now().year == year &&
                  DateTime.now().month == month &&
                  DateTime.now().day == day;

              return GestureDetector(
                onTap: () => _showStatusBottomSheet(
                  subject,
                  DateTime(year, month, day),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status != null
                        ? _statusColors[status]?.withOpacity(0.2)
                        : isToday
                            ? cs.primary.withOpacity(0.1)
                            : null,
                    border: isToday
                        ? Border.all(color: cs.primary, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? cs.primary : cs.onSurface,
                          ),
                        ),
                        if (status != null)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusColors[status],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 64,
              color: cs.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No subjects yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a subject to start tracking attendance',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Subject name (e.g. Physics)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final today = DateTime.now();
                final todayMillis = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
                await DatabaseHelper.instance.insertAttendanceLog({
                  'subjectName': name,
                  'dateMillis': todayMillis,
                  'status': 'present',
                });
                Navigator.pop(ctx);
                await _loadData();
                await WidgetService.refreshAttendanceWidget();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSubjectDialog(String subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Delete all attendance records for "$subject"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final logs = await DatabaseHelper.instance.getAttendanceLogsForSubject(subject);
              for (final log in logs) {
                await DatabaseHelper.instance.deleteAttendanceLog(log['id'] as int);
              }
              Navigator.pop(ctx);
              _backToDashboard();
              await _loadData();
              await WidgetService.refreshAttendanceWidget();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }
}
