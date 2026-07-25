import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  List<Map<String, dynamic>> _habits = [];
  bool _loading = true;
  int _bestStreak = 0;

  final List<String> _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final habits = await DatabaseHelper.instance.getAllHabits(includeArchived: false);
    int best = 0;
    for (final h in habits) {
      final streak = await DatabaseHelper.instance.getHabitStreak(h['id'] as int);
      if (streak > best) best = streak;
    }
    setState(() {
      _habits = habits;
      _bestStreak = best;
      _loading = false;
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4CAF50);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4CAF50);
    }
  }

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

  Future<void> _toggleToday(int habitId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, todayStart);
    if (log != null) {
      final newCompleted = (log['completed'] as int? ?? 1) == 0 ? 1 : 0;
      await DatabaseHelper.instance.updateHabitLog(log['id'] as int, {
        'habitId': habitId,
        'dateMillis': todayStart,
        'completed': newCompleted,
      });
    } else {
      await DatabaseHelper.instance.insertHabitLog({
        'habitId': habitId,
        'dateMillis': todayStart,
        'completed': 1,
      });
    }
    HapticFeedback.lightImpact();
    await _loadData();
  }

  Future<void> _markYesterday(int habitId) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final yesterdayMillis = yesterday.millisecondsSinceEpoch;
    final log = await DatabaseHelper.instance.getHabitLogForDate(habitId, yesterdayMillis);
    if (log == null) {
      await DatabaseHelper.instance.insertHabitLog({
        'habitId': habitId,
        'dateMillis': yesterdayMillis,
        'completed': 1,
      });
    } else if ((log['completed'] as int? ?? 0) == 0) {
      await DatabaseHelper.instance.updateHabitLog(log['id'] as int, {
        'habitId': habitId,
        'dateMillis': yesterdayMillis,
        'completed': 1,
      });
    }
    HapticFeedback.mediumImpact();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yesterday marked as done!')),
      );
    }
  }

  Future<void> _archiveHabit(int habitId) async {
    await DatabaseHelper.instance.archiveHabit(habitId, true);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit archived')),
      );
    }
  }

  Future<void> _showAddHabitDialog() async {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    int targetPerWeek = 7;
    TimeOfDay? reminderTime;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add New Habit'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Habit Name *',
                      prefixIcon: Icon(Icons.star),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: targetPerWeek,
                    decoration: const InputDecoration(
                      labelText: 'Weekly Target',
                      prefixIcon: Icon(Icons.track_changes),
                    ),
                    items: [1, 2, 3, 4, 5, 6, 7].map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n day${n == 1 ? '' : 's'}/week'),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => targetPerWeek = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reminder Time', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      reminderTime != null
                          ? '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
                          : 'None',
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
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Name is required')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'name': nameController.text.trim(),
                    'subjectName': subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                    'targetPerWeek': targetPerWeek,
                    'reminderTimeMinutes': reminderTime != null ? reminderTime!.hour * 60 + reminderTime!.minute : null,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await DatabaseHelper.instance.insertHabit(result);
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Habit Tracker')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Streak banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.white, size: 36),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Streak',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$_bestStreak day${_bestStreak == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        _bestStreak >= 7 ? Icons.emoji_events : Icons.trending_up,
                        color: Colors.white.withOpacity(0.8),
                        size: 28,
                      ),
                    ],
                  ),
                ),

                // Habits list
                Expanded(
                  child: _habits.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.self_improvement, size: 64, color: cs.outline.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text(
                                'No habits yet',
                                style: TextStyle(color: cs.outline, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to build a new habit',
                                style: TextStyle(color: cs.outline.withOpacity(0.7), fontSize: 13),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _showAddHabitDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Habit'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _habits.length,
                          itemBuilder: (context, index) {
                            final habit = _habits[index];
                            final habitId = habit['id'] as int;
                            final color = _parseColor(habit['colorHex'] as String?);
                            final name = habit['name'] as String;
                            final target = (habit['targetPerWeek'] as int?) ?? 7;
                            final subject = habit['subjectName'] as String?;

                            return Dismissible(
                              key: ValueKey(habitId),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.archive_outlined, color: Colors.white),
                                    SizedBox(height: 4),
                                    Text('Archive', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                              onDismissed: (_) => _archiveHabit(habitId),
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: cs.outline.withOpacity(0.15)),
                                ),
                                child: InkWell(
                                  onTap: () => _toggleToday(habitId),
                                  onLongPress: () => _markYesterday(habitId),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (subject != null && subject.isNotEmpty)
                                                    Text(
                                                      subject,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: cs.onSurfaceVariant,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            FutureBuilder<int>(
                                              future: DatabaseHelper.instance.getHabitStreak(habitId),
                                              builder: (context, snapshot) {
                                                final streak = snapshot.data ?? 0;
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade600),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '$streak',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.orange.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Week circles
                                        FutureBuilder<List<bool>>(
                                          future: _getWeekCompletion(habitId),
                                          builder: (context, snapshot) {
                                            final weekDone = snapshot.data ?? List.filled(7, false);
                                            final now = DateTime.now();
                                            return Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: List.generate(7, (i) {
                                                final isDone = weekDone[i];
                                                final isToday = i == now.weekday - 1;
                                                final isFuture = i > now.weekday - 1;
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isDone
                                                            ? color.withOpacity(0.9)
                                                            : isFuture
                                                                ? cs.surfaceContainerHighest
                                                                : cs.surfaceContainerHighest.withOpacity(0.5),
                                                        border: isToday
                                                            ? Border.all(color: color, width: 2)
                                                            : null,
                                                      ),
                                                      child: isDone
                                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                          : null,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _dayNames[i],
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isToday ? color : cs.outline,
                                                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        // Target text
                                        FutureBuilder<Map<String, dynamic>>(
                                          future: () async {
                                            final now = DateTime.now();
                                            final weekStart = DateTime(now.year, now.month, now.day)
                                                .subtract(Duration(days: now.weekday - 1))
                                                .millisecondsSinceEpoch;
                                            return DatabaseHelper.instance.getHabitWeeklyStats(habitId, weekStart);
                                          }(),
                                          builder: (context, snapshot) {
                                            final stats = snapshot.data;
                                            final completed = (stats?['completed'] as int?) ?? 0;
                                            return Text(
                                              '$completed / $target this week',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHabitDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }
}
