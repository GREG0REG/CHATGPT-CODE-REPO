// FILE: lib/screens/habit_screen.dart
// COMPLETE REWRITE — Study Habit Builder with Streak Science
// FEATURES: Chain visualization, weekly progress, tap-to-toggle, templates,
//           flexible habit types, stats modal, long-press menu, weekly review,
//           metric tracking (pages/minutes/count), "OR" logic display

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_screen.dart';
import '../database_helper.dart';
import '../WIDGET/simple_color_picker.dart';
import '../WIDGET/subject_picker_sheet.dart';

enum HabitType { dailyCheck, durationMinutes, countMetric }

class HabitTemplate {
  final String name;
  final String icon;
  final HabitType type;
  final int defaultTarget;
  final String? defaultSubject;
  final String? unitLabel;
  final int? metricGoal;

  const HabitTemplate({
    required this.name,
    required this.icon,
    required this.type,
    this.defaultTarget = 7,
    this.defaultSubject,
    this.unitLabel,
    this.metricGoal,
  });
}

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  List<Map<String, dynamic>> _habits = [];
  bool _loading = true;
  int _bestOverallStreak = 0;
  double _weeklyCompletionRate = 0;
  String _mostConsistentDay = '';
  bool _trendUp = false;

  // Cache for attendance subjects (for dropdown)
  List<Map<String, dynamic>> _attendanceSubjects = [];

  final List<String> _dayNamesShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final List<String> _dayNamesFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static const List<HabitTemplate> _templates = [
    HabitTemplate(name: 'Morning Review', icon: '🌅', type: HabitType.dailyCheck, defaultTarget: 7),
    HabitTemplate(name: 'Deep Work', icon: '🧠', type: HabitType.durationMinutes, defaultTarget: 5, unitLabel: 'min', metricGoal: 120),
    HabitTemplate(name: 'Anki Review', icon: '🃏', type: HabitType.countMetric, defaultTarget: 5, defaultSubject: 'Anki', unitLabel: 'cards', metricGoal: 50),
    HabitTemplate(name: 'Reading', icon: '📚', type: HabitType.countMetric, defaultTarget: 5, unitLabel: 'pages', metricGoal: 20),
    HabitTemplate(name: 'Exercise', icon: '💪', type: HabitType.durationMinutes, defaultTarget: 4, unitLabel: 'min', metricGoal: 30),
    HabitTemplate(name: 'Custom', icon: '✨', type: HabitType.dailyCheck, defaultTarget: 7),
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await _loadAttendanceSubjects();
    await _loadHabits();
    await _calculateWeeklyReview();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAttendanceSubjects() async {
    final subjects = await DatabaseHelper.instance.getAllAttendanceSubjects();
    if (mounted) setState(() => _attendanceSubjects = subjects);
  }

  Future<void> _loadHabits() async {
    final habits = await DatabaseHelper.instance.getAllHabits(includeArchived: false);
    int best = 0;
    for (final h in habits) {
      final streak = await DatabaseHelper.instance.getHabitStreak(h['id'] as int);
      if (streak > best) best = streak;
    }
    if (mounted) {
      setState(() {
        _habits = habits;
        _bestOverallStreak = best;
      });
    }
  }

  Future<void> _calculateWeeklyReview() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekStartMillis = weekStart.millisecondsSinceEpoch;

    int totalPossible = 0;
    int totalCompleted = 0;
    final dayCounts = List<int>.filled(7, 0);
    final dayTotals = List<int>.filled(7, 0);

    for (final habit in _habits) {
      final habitId = habit['id'] as int;
      final target = (habit['targetPerWeek'] as int?) ?? 7;
      totalPossible += target;

      final stats = await DatabaseHelper.instance.getHabitWeeklyStats(habitId, weekStartMillis);
      final completed = (stats['completed'] as int?) ?? 0;
      totalCompleted += completed;

      // Per-day breakdown
      final logs = await DatabaseHelper.instance.getHabitLogsForDateRange(
        habitId,
        weekStartMillis,
        weekStartMillis + const Duration(days: 7).inMilliseconds,
      );
      for (final log in logs) {
        if ((log['completed'] as int? ?? 0) == 1) {
          final date = DateTime.fromMillisecondsSinceEpoch(log['dateMillis'] as int);
          final dayIndex = date.weekday - 1;
          if (dayIndex >= 0 && dayIndex < 7) dayCounts[dayIndex]++;
        }
      }
      // Count habits active each day
      for (int i = 0; i < 7; i++) dayTotals[i]++;
    }

    double rate = totalPossible > 0 ? (totalCompleted / totalPossible * 100) : 0;
    
    // Find most consistent day
    int bestDayIndex = 0;
    double bestDayRate = 0;
    for (int i = 0; i < 7; i++) {
      if (dayTotals[i] > 0) {
        double dayRate = dayCounts[i] / dayTotals[i];
        if (dayRate > bestDayRate) {
          bestDayRate = dayRate;
          bestDayIndex = i;
        }
      }
    }

    // Trend vs last week
    final lastWeekStart = weekStart.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    int lastWeekTotal = 0;
    int lastWeekPossible = 0;
    for (final habit in _habits) {
      final habitId = habit['id'] as int;
      final target = (habit['targetPerWeek'] as int?) ?? 7;
      lastWeekPossible += target;
      final stats = await DatabaseHelper.instance.getHabitWeeklyStats(habitId, lastWeekStart);
      lastWeekTotal += (stats['completed'] as int?) ?? 0;
    }
    double lastRate = lastWeekPossible > 0 ? (lastWeekTotal / lastWeekPossible * 100) : 0;

    if (mounted) {
      setState(() {
        _weeklyCompletionRate = rate;
        _mostConsistentDay = _dayNamesFull[bestDayIndex];
        _trendUp = rate >= lastRate;
      });
    }
  }

  // ── Color parsing ──
  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4CAF50);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4CAF50);
    }
  }

  // ── Habit type helpers ──
  HabitType _getHabitType(Map<String, dynamic> habit) {
    final typeIndex = habit['habitType'] as int?;
    if (typeIndex == null || typeIndex < 0 || typeIndex > 2) return HabitType.dailyCheck;
    return HabitType.values[typeIndex];
  }

  String? _getUnitLabel(Map<String, dynamic> habit) {
    return habit['unitLabel'] as String?;
  }

  int? _getMetricGoal(Map<String, dynamic> habit) {
    return habit['metricGoal'] as int?;
  }

  String _formatMetric(int? value, String? unit) {
    if (value == null) return '';
    if (unit == null) return '$value';
    return '$value $unit';
  }

  // ── Week completion for a habit ──
  Future<List<bool>> _getWeekCompletion(int habitId) async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final result = <bool>[];
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayMillis = day.millisecondsSinceEpoch;
      final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, dayMillis);
      result.add(log != null && (log['completed'] as int? ?? 0) == 1);
    }
    return result;
  }

  // ── 14-day chain data ──
  Future<List<Map<String, dynamic>>> _getChainData(int habitId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <Map<String, dynamic>>[];
    for (int i = 13; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final dayMillis = day.millisecondsSinceEpoch;
      final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, dayMillis);
      final isCompleted = log != null && (log['completed'] as int? ?? 0) == 1;
      result.add({
        'date': day,
        'completed': isCompleted,
        'isToday': i == 0,
        'isFuture': false,
      });
    }
    return result;
  }

  // ── Get today's metric value for a habit ──
  Future<int?> _getTodayMetricValue(int habitId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, todayStart);
    if (log == null) return null;
    return log['metricValue'] as int?;
  }

  // ── Toggle any day ──
  Future<void> _toggleDay(int habitId, DateTime day, bool currentState, HabitType habitType, int? metricGoal, String? unitLabel) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayStart = DateTime(day.year, day.month, day.day);

    if (dayStart.isAfter(today)) {
      // Future day — disabled
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't mark future days")),
        );
      }
      return;
    }

    // For metric-based habits, show input dialog when marking as done
    int? metricValue;
    if (!currentState && habitType != HabitType.dailyCheck && dayStart.isAtSameMomentAs(today)) {
      metricValue = await _showMetricInputDialog(habitType, metricGoal, unitLabel);
      if (metricValue == null) return; // User cancelled
    }

    if (dayStart.isBefore(today) && !currentState) {
      // Past day, marking as done — confirm
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Mark Past Day?'),
          content: Text('Mark ${_formatDate(day)} as completed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final dayMillis = dayStart.millisecondsSinceEpoch;
    final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, dayMillis);
    if (log != null) {
      final newCompleted = (log['completed'] as int? ?? 1) == 0 ? 1 : 0;
      await DatabaseHelper.instance.updateHabitLog(log['id'] as int, {
        'habitId': habitId,
        'dateMillis': dayMillis,
        'completed': newCompleted,
        'metricValue': metricValue ?? log['metricValue'],
      });
    } else {
      await DatabaseHelper.instance.insertHabitLog({
        'habitId': habitId,
        'dateMillis': dayMillis,
        'completed': currentState ? 0 : 1,
        'metricValue': metricValue,
      });
    }

    HapticFeedback.lightImpact();
    await _loadAllData();
  }

  // ── Metric input dialog ──
  Future<int?> _showMetricInputDialog(HabitType type, int? goal, String? unitLabel) async {
    final controller = TextEditingController();
    final unit = unitLabel ?? (type == HabitType.durationMinutes ? 'minutes' : 'count');
    final goalText = goal != null ? ' (Goal: $goal $unit)' : '';

    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('How many $unit?$goalText'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter $unit',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Skip')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result;
  }

  // ── Long press: mark yesterday ──
  Future<void> _markYesterday(int habitId, HabitType habitType, int? metricGoal, String? unitLabel) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final yesterdayMillis = yesterday.millisecondsSinceEpoch;

    int? metricValue;
    if (habitType != HabitType.dailyCheck) {
      metricValue = await _showMetricInputDialog(habitType, metricGoal, unitLabel);
    }

    final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, yesterdayMillis);
    if (log == null) {
      await DatabaseHelper.instance.insertHabitLog({
        'habitId': habitId,
        'dateMillis': yesterdayMillis,
        'completed': 1,
        'metricValue': metricValue,
      });
    } else if ((log['completed'] as int? ?? 0) == 0) {
      await DatabaseHelper.instance.updateHabitLog(log['id'] as int, {
        'habitId': habitId,
        'dateMillis': yesterdayMillis,
        'completed': 1,
        'metricValue': metricValue ?? log['metricValue'],
      });
    }
    HapticFeedback.lightImpact();
    await _loadAllData();
    await WidgetService.refreshHabitWidget(); // <-- ADD THIS
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yesterday marked as done!')),
      );
    }
  }

  // ── Archive ──
  Future<void> _archiveHabit(int habitId) async {
    await DatabaseHelper.instance.archiveHabit(habitId, true);
    HapticFeedback.lightImpact();
    await _loadAllData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit archived')),
      );
    }
  }

  // ── Delete ──
  Future<void> _deleteHabit(int habitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Habit?'),
        content: const Text('This will delete the habit and all its history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteHabit(habitId);
      HapticFeedback.mediumImpact();
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit deleted')),
        );
      }
    }
  }

  // ── Show stats modal ──
  Future<void> _showStatsModal(Map<String, dynamic> habit) async {
    final habitId = habit['id'] as int;
    final name = habit['name'] as String;
    final color = _parseColor(habit['colorHex'] as String?);
    final habitType = _getHabitType(habit);
    final unitLabel = _getUnitLabel(habit);
    final metricGoal = _getMetricGoal(habit);
    
    final streak = await DatabaseHelper.instance.getHabitStreak(habitId);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .millisecondsSinceEpoch;
    final weeklyStats = await DatabaseHelper.instance.getHabitWeeklyStats(habitId, weekStart);
    
    // All-time stats
    final allLogs = await DatabaseHelper.instance.getHabitLogsForHabit(habitId);
    final totalLogs = allLogs.length;
    final completedLogs = allLogs.where((l) => (l['completed'] as int? ?? 0) == 1).length;
    final completionRate = totalLogs > 0 ? (completedLogs / totalLogs * 100).round() : 0;

    // Average metric
    double avgMetric = 0;
    int metricCount = 0;
    int totalMetric = 0;
    int maxMetric = 0;
    for (final log in allLogs) {
      final mv = log['metricValue'] as int?;
      if (mv != null) {
        totalMetric += mv;
        metricCount++;
        if (mv > maxMetric) maxMetric = mv;
      }
    }
    if (metricCount > 0) avgMetric = totalMetric / metricCount;

    // Best day of week
    final dayCounts = List<int>.filled(7, 0);
    for (final log in allLogs) {
      if ((log['completed'] as int? ?? 0) == 1) {
        final date = DateTime.fromMillisecondsSinceEpoch(log['dateMillis'] as int);
        dayCounts[date.weekday - 1]++;
      }
    }
    int bestDayIdx = 0;
    for (int i = 1; i < 7; i++) {
      if (dayCounts[i] > dayCounts[bestDayIdx]) bestDayIdx = i;
    }

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _statRow('Current Streak', '🔥 $streak days', color),
              _statRow('Completion Rate', '$completionRate%', color),
              _statRow('Best Day', _dayNamesFull[bestDayIdx], color),
              _statRow('This Week', '${weeklyStats['completed']}/${weeklyStats['targetPerWeek']}', color),
              _statRow('Total Completions', '$completedLogs', color),
              if (habitType != HabitType.dailyCheck && metricCount > 0) ...[
                const Divider(height: 24),
                Text('Metric Tracking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                _statRow('Average ${unitLabel ?? 'value'}', avgMetric.toStringAsFixed(1), color),
                _statRow('Best ${unitLabel ?? 'value'}', '$maxMetric', color),
                _statRow('Total ${unitLabel ?? 'value'}', '$totalMetric', color),
                if (metricGoal != null) _statRow('Goal', '$metricGoal ${unitLabel ?? ''}/day', color),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Add habit bottom sheet ──
  Future<void> _showAddHabitSheet() async {
    final nameController = TextEditingController();
    String? selectedSubject;
    int targetPerWeek = 7;
    HabitType habitType = HabitType.dailyCheck;
    TimeOfDay? reminderTime;
    Color selectedColor = Colors.green;
    HabitTemplate? selectedTemplate;
    String? unitLabel;
    int? metricGoal;

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 24,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('New Habit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const SizedBox(height: 20),

                    // Template selector
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _templates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final t = _templates[idx];
                          final isSelected = selectedTemplate?.name == t.name;
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedTemplate = t;
                                habitType = t.type;
                                targetPerWeek = t.defaultTarget;
                                unitLabel = t.unitLabel;
                                metricGoal = t.metricGoal;
                                if (t.defaultSubject != null) selectedSubject = t.defaultSubject;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 80,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected ? Border.all(color: cs.primary, width: 2) : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(t.icon, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Habit Name *',
                        prefixIcon: const Icon(Icons.star),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subject picker
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SubjectPickerSheet(
                            selectedSubjectName: selectedSubject,
                            onSubjectSelected: (subject) {
                              setDialogState(() => selectedSubject = subject);
                            },
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.book, color: cs.onSurfaceVariant, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedSubject ?? 'Select Subject (optional)',
                                style: TextStyle(
                                  color: selectedSubject != null ? cs.onSurface : cs.onSurfaceVariant,
                                  fontWeight: selectedSubject != null ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type selector
                    SegmentedButton<HabitType>(
                      segments: const [
                        ButtonSegment(value: HabitType.dailyCheck, label: Text('Check'), icon: Icon(Icons.check_circle_outline, size: 16)),
                        ButtonSegment(value: HabitType.durationMinutes, label: Text('Duration'), icon: Icon(Icons.timer, size: 16)),
                        ButtonSegment(value: HabitType.countMetric, label: Text('Count'), icon: Icon(Icons.format_list_numbered, size: 16)),
                      ],
                      selected: {habitType},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) setDialogState(() => habitType = sel.first);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Metric goal (for duration/count)
                    if (habitType != HabitType.dailyCheck) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: metricGoal?.toString() ?? ''),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Daily Goal ${unitLabel != null ? '($unitLabel)' : ''}',
                                prefixIcon: const Icon(Icons.track_changes),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) => metricGoal = int.tryParse(v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Unit label input
                      TextField(
                        controller: TextEditingController(text: unitLabel ?? ''),
                        decoration: InputDecoration(
                          labelText: 'Unit Label (e.g., pages, min, reps)',
                          prefixIcon: const Icon(Icons.label),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) => unitLabel = v.trim().isEmpty ? null : v.trim(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Target per week
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target: $targetPerWeek days/week', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        Slider(
                          value: targetPerWeek.toDouble(),
                          min: 1,
                          max: 7,
                          divisions: 6,
                          label: '$targetPerWeek',
                          onChanged: (v) => setDialogState(() => targetPerWeek = v.round()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Reminder time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reminder Time', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        reminderTime != null
                            ? '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
                            : 'None set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.alarm, size: 20),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) setDialogState(() => reminderTime = time);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Color picker
                    Row(
                      children: [
                        const Text('Color:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () async {
                            final color = await showDialog<Color>(
                              context: context,
                              builder: (_) => SimpleColorPickerDialog(initialColor: selectedColor),
                            );
                            if (color != null) setDialogState(() => selectedColor = color);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Add button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Name is required')),
                            );
                            return;
                          }
                          Navigator.pop(ctx, {
                            'name': nameController.text.trim(),
                            'subjectName': selectedSubject,
                            'targetPerWeek': targetPerWeek,
                            'reminderTimeMinutes': reminderTime != null ? reminderTime!.hour * 60 + reminderTime!.minute : null,
                            'colorHex': '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                            'habitType': habitType.index,
                            'metricGoal': metricGoal,
                            'unitLabel': unitLabel,
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Habit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      await DatabaseHelper.instance.insertHabit(result);
      HapticFeedback.mediumImpact();
      await _loadAllData();
    }
  }

  // ── Edit habit ──
  Future<void> _showEditSheet(Map<String, dynamic> habit) async {
    final habitId = habit['id'] as int;
    final nameController = TextEditingController(text: habit['name'] as String? ?? '');
    String? selectedSubject = habit['subjectName'] as String?;
    int targetPerWeek = (habit['targetPerWeek'] as int?) ?? 7;
    HabitType habitType = _getHabitType(habit);
    String? unitLabel = _getUnitLabel(habit);
    int? metricGoal = _getMetricGoal(habit);
    final existingReminder = habit['reminderTimeMinutes'] as int?;
    TimeOfDay? reminderTime = existingReminder != null
        ? TimeOfDay(hour: existingReminder ~/ 60, minute: existingReminder % 60)
        : null;
    Color selectedColor = _parseColor(habit['colorHex'] as String?);

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 24,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Edit Habit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Habit Name',
                        prefixIcon: const Icon(Icons.star),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SubjectPickerSheet(
                            selectedSubjectName: selectedSubject,
                            onSubjectSelected: (subject) {
                              setDialogState(() => selectedSubject = subject);
                            },
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.book, color: cs.onSurfaceVariant, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedSubject ?? 'No subject',
                                style: TextStyle(color: selectedSubject != null ? cs.onSurface : cs.onSurfaceVariant),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type selector (view only in edit)
                    SegmentedButton<HabitType>(
                      segments: const [
                        ButtonSegment(value: HabitType.dailyCheck, label: Text('Check'), icon: Icon(Icons.check_circle_outline, size: 16)),
                        ButtonSegment(value: HabitType.durationMinutes, label: Text('Duration'), icon: Icon(Icons.timer, size: 16)),
                        ButtonSegment(value: HabitType.countMetric, label: Text('Count'), icon: Icon(Icons.format_list_numbered, size: 16)),
                      ],
                      selected: {habitType},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) setDialogState(() => habitType = sel.first);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Metric goal (for duration/count)
                    if (habitType != HabitType.dailyCheck) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: metricGoal?.toString() ?? ''),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Daily Goal ${unitLabel != null ? '($unitLabel)' : ''}',
                                prefixIcon: const Icon(Icons.track_changes),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) => metricGoal = int.tryParse(v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(text: unitLabel ?? ''),
                        decoration: InputDecoration(
                          labelText: 'Unit Label',
                          prefixIcon: const Icon(Icons.label),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) => unitLabel = v.trim().isEmpty ? null : v.trim(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target: $targetPerWeek days/week', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        Slider(
                          value: targetPerWeek.toDouble(),
                          min: 1,
                          max: 7,
                          divisions: 6,
                          label: '$targetPerWeek',
                          onChanged: (v) => setDialogState(() => targetPerWeek = v.round()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reminder Time', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        reminderTime != null
                            ? '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
                            : 'None set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.alarm, size: 20),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) setDialogState(() => reminderTime = time);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Color:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () async {
                            final color = await showDialog<Color>(
                              context: context,
                              builder: (_) => SimpleColorPickerDialog(initialColor: selectedColor),
                            );
                            if (color != null) setDialogState(() => selectedColor = color);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx, {
                            'name': nameController.text.trim(),
                            'subjectName': selectedSubject,
                            'targetPerWeek': targetPerWeek,
                            'reminderTimeMinutes': reminderTime != null ? reminderTime!.hour * 60 + reminderTime!.minute : null,
                            'colorHex': '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                            'habitType': habitType.index,
                            'metricGoal': metricGoal,
                            'unitLabel': unitLabel,
                          });
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      await DatabaseHelper.instance.updateHabit(habitId, result);
      HapticFeedback.mediumImpact();
      await _loadAllData();
    }
  }

  // ── Long press menu ──
  void _showHabitMenu(Map<String, dynamic> habit, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final habitType = _getHabitType(habit);
    final unitLabel = _getUnitLabel(habit);
    final metricGoal = _getMetricGoal(habit);
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'stats', child: ListTile(leading: Icon(Icons.bar_chart), title: Text('View Stats'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'yesterday', child: ListTile(leading: Icon(Icons.history), title: Text('Mark Yesterday'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive), title: Text('Archive'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
      ],
    ).then((value) {
      final habitId = habit['id'] as int;
      switch (value) {
        case 'stats': _showStatsModal(habit); break;
        case 'edit': _showEditSheet(habit); break;
        case 'yesterday': _markYesterday(habitId, habitType, metricGoal, unitLabel); break;
        case 'archive': _archiveHabit(habitId); break;
        case 'delete': _deleteHabit(habitId); break;
      }
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Habit Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: CustomScrollView(
                slivers: [
                  // Weekly Review Card
                  SliverToBoxAdapter(
                    child: _buildWeeklyReviewCard(cs),
                  ),

                  // Habits list
                  _habits.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(cs),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildHabitCard(_habits[index], cs),
                              childCount: _habits.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHabitSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }

  Widget _buildWeeklyReviewCard(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: cs.onPrimaryContainer, size: 20),
              const SizedBox(width: 8),
              Text(
                'Weekly Review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _trendUp ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_trendUp ? Icons.trending_up : Icons.trending_flat, size: 14, color: _trendUp ? Colors.green : Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      _trendUp ? 'Trending up' : 'Steady',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _trendUp ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weeklyCompletionRate.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                    ),
                    Text(
                      'completion rate',
                      style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔥 $_bestOverallStreak',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                    ),
                    Text(
                      'best streak',
                      style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You're most consistent on $_mostConsistentDay",
            style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer.withOpacity(0.8), fontWeight: FontWeight.w500),
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
          Icon(Icons.self_improvement, size: 80, color: cs.outline.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'No habits yet',
            style: TextStyle(color: cs.outline, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Build streaks, one day at a time',
            style: TextStyle(color: cs.outline.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddHabitSheet,
            icon: const Icon(Icons.add),
            label: const Text('Start a Habit'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(Map<String, dynamic> habit, ColorScheme cs) {
    final habitId = habit['id'] as int;
    final name = habit['name'] as String;
    final color = _parseColor(habit['colorHex'] as String?);
    final target = (habit['targetPerWeek'] as int?) ?? 7;
    final subject = habit['subjectName'] as String?;
    final habitType = _getHabitType(habit);
    final unitLabel = _getUnitLabel(habit);
    final metricGoal = _getMetricGoal(habit);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outline.withOpacity(0.15)),
      ),
      child: InkWell(
        onLongPress: () {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final position = box.localToGlobal(Offset.zero);
          _showHabitMenu(habit, position);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (subject != null && subject.isNotEmpty)
                          Text(
                            subject,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        // Show habit type badge
                        if (habitType != HabitType.dailyCheck) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                habitType == HabitType.durationMinutes ? Icons.timer : Icons.format_list_numbered,
                                size: 12,
                                color: color.withOpacity(0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatMetric(metricGoal, unitLabel)}/day',
                                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Streak + Best
                  FutureBuilder<int>(
                    future: DatabaseHelper.instance.getHabitStreak(habitId),
                    builder: (context, snap) {
                      final streak = snap.data ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (streak > 0) ...[
                            Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade600),
                            const SizedBox(width: 2),
                            Text('$streak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),

              // "Don't break the chain" banner
              FutureBuilder<int>(
                future: DatabaseHelper.instance.getHabitStreak(habitId),
                builder: (context, snap) {
                  final streak = snap.data ?? 0;
                  if (streak > 3) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "🔥 Don't break the chain! ($streak days)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 16),

              // 14-day chain visualization
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getChainData(habitId),
                builder: (context, snap) {
                  final chain = snap.data ?? [];
                  return SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: chain.length,
                      itemBuilder: (context, i) {
                        final day = chain[i];
                        final isCompleted = day['completed'] as bool;
                        final isToday = day['isToday'] as bool;
                        final date = day['date'] as DateTime;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => _toggleDay(habitId, date, isCompleted, habitType, metricGoal, unitLabel),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleted
                                        ? color
                                        : isToday
                                            ? cs.surfaceContainerHighest
                                            : cs.surfaceContainerHighest.withOpacity(0.4),
                                    border: isToday
                                        ? Border.all(color: color, width: 2)
                                        : isCompleted
                                            ? null
                                            : Border.all(color: cs.outline.withOpacity(0.2)),
                                  ),
                                  child: isCompleted
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isToday ? color : cs.outline,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Week circles (Mon-Sun) with metric display
              FutureBuilder<List<bool>>(
                future: _getWeekCompletion(habitId),
                builder: (context, snap) {
                  final weekDone = snap.data ?? List.filled(7, false);
                  final now = DateTime.now();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final isDone = weekDone[i];
                      final isToday = i == now.weekday - 1;
                      return GestureDetector(
                        onTap: () {
                          final weekStart = DateTime(now.year, now.month, now.day)
                              .subtract(Duration(days: now.weekday - 1));
                          final day = weekStart.add(Duration(days: i));
                          _toggleDay(habitId, day, isDone, habitType, metricGoal, unitLabel);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? color.withOpacity(0.9)
                                    : isToday
                                        ? cs.surfaceContainerHighest
                                        : cs.surfaceContainerHighest.withOpacity(0.5),
                                border: isToday
                                    ? Border.all(color: color, width: 2)
                                    : null,
                              ),
                              child: isDone
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dayNamesShort[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: isToday ? color : cs.outline,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Today's metric display (for metric-based habits)
              if (habitType != HabitType.dailyCheck) ...[
                FutureBuilder<int?>(
                  future: _getTodayMetricValue(habitId),
                  builder: (context, snap) {
                    final todayValue = snap.data;
                    final goalText = metricGoal != null ? ' / $metricGoal' : '';
                    final unit = unitLabel ?? '';
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: todayValue != null && metricGoal != null && todayValue >= metricGoal
                            ? color.withOpacity(0.15)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            habitType == HabitType.durationMinutes ? Icons.timer : Icons.format_list_numbered,
                            size: 14,
                            color: todayValue != null && metricGoal != null && todayValue >= metricGoal
                                ? color
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            todayValue != null
                                ? '$todayValue$goalText $unit'
                                : 'Not tracked today',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: todayValue != null && metricGoal != null && todayValue >= metricGoal
                                  ? color
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          if (todayValue != null && metricGoal != null && todayValue >= metricGoal) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle, size: 14, color: color),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              // Target progress
              FutureBuilder<Map<String, dynamic>>(
                future: () async {
                  final now = DateTime.now();
                  final weekStart = DateTime(now.year, now.month, now.day)
                      .subtract(Duration(days: now.weekday - 1))
                      .millisecondsSinceEpoch;
                  return DatabaseHelper.instance.getHabitWeeklyStats(habitId, weekStart);
                }(),
                builder: (context, snap) {
                  final stats = snap.data;
                  final completed = (stats?['completed'] as int?) ?? 0;
                  final percentage = target > 0 ? (completed / target) : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completed / $target this week',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
