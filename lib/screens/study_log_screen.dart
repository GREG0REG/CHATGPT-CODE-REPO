// FILE: lib/screens/study_log_screen.dart
// COMPLETE REPLACEMENT — copy and paste entire file

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/study_session.dart';
import '../services/streak_service.dart';

/// Modern study session logger with immersive UI
class StudyLogScreen extends StatefulWidget {
  const StudyLogScreen({super.key});

  @override
  State<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends State<StudyLogScreen>
    with SingleTickerProviderStateMixin {
  List<StudySession> _sessions = [];
  List<String> _existingSubjects = [];
  bool _loading = true;

  // Quick log form
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  final _customMinutesController = TextEditingController();
  int _durationMinutes = 25;
  String _sessionType = 'pomodoro';
  bool _useCustomTime = false;

  final List<String> _sessionTypes = ['pomodoro', 'deep_work', 'reading', 'review', 'practice'];
  final List<int> _presetMinutes = [15, 25, 30, 45, 60, 90, 120];

  late final AnimationController _counterController;
  late final Animation<double> _counterAnimation;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _counterAnimation = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sessions = await DatabaseHelper.instance.getStudySessions(limit: 50);
    final subjects = await DatabaseHelper.instance.getAllStudySubjects();
    final subjectNames = subjects.map((s) => s.name).toList()..sort();

    setState(() {
      _sessions = sessions;
      _existingSubjects = subjectNames;
      _loading = false;
    });
    _counterController.forward(from: 0);
  }

  Future<void> _quickLog() async {
    if (_subjectController.text.trim().isEmpty) {
      _subjectController.text = 'General Study';
    }

    int minutes;
    if (_useCustomTime) {
      minutes = int.tryParse(_customMinutesController.text) ?? 25;
      if (minutes < 1) minutes = 1;
      if (minutes > 1440) minutes = 1440;
    } else {
      minutes = _durationMinutes;
    }

    final session = StudySession(
      subjectTag: _subjectController.text.trim(),
      durationMinutes: minutes,
      completedAtMillis: DateTime.now().millisecondsSinceEpoch,
      sessionType: _sessionType,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await DatabaseHelper.instance.insertStudySession(session);
    HapticFeedback.mediumImpact();

    // Update subject focus time if exists
    final subjects = await DatabaseHelper.instance.getAllStudySubjects();
    final match = subjects.where((s) => s.name == _subjectController.text.trim()).firstOrNull;
    if (match != null && match.id != null) {
      await DatabaseHelper.instance.addSubjectFocusMinutes(match.id!, minutes);
    }

    // Record streak
    await StreakService.instance.recordStudySession();

    _subjectController.clear();
    _notesController.clear();
    _customMinutesController.clear();
    _durationMinutes = 25;
    _useCustomTime = false;

    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged $minutes min study session!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteSession(int id) async {
    await DatabaseHelper.instance.deleteStudySession(id);
    HapticFeedback.mediumImpact();
    await _loadData();
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    return '${minutes}m';
  }

  String _timeAgo(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'pomodoro': return Colors.blue;
      case 'deep_work': return Colors.deepPurple;
      case 'reading': return Colors.teal;
      case 'review': return Colors.orange;
      case 'practice': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'pomodoro': return Icons.timer;
      case 'deep_work': return Icons.psychology;
      case 'reading': return Icons.menu_book;
      case 'review': return Icons.refresh;
      case 'practice': return Icons.school;
      default: return Icons.timer;
    }
  }

  // Calculate weekly sparkline data
  List<int> _getWeeklyData() {
    final now = DateTime.now();
    final data = List<int>.filled(7, 0);
    for (final s in _sessions) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.completedAtMillis);
      final daysAgo = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        data[6 - daysAgo] += s.durationMinutes;
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Calculate today's stats
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final todaySessions = _sessions.where((s) => s.completedAtMillis >= todayStart).toList();
    final todayMinutes = todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final streakInfo = _sessions.isNotEmpty ? _latestStreak() : 0;

    final weeklyData = _getWeeklyData();
    final maxWeekly = weeklyData.reduce((a, b) => a > b ? a : b);
    final sparklineHeight = maxWeekly > 0 ? weeklyData.map((m) => m / maxWeekly).toList() : List.filled(7, 0.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Study Log')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Hero Stats
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary.withOpacity(0.15), cs.secondary.withOpacity(0.08)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Today', todayMinutes, 'min', Icons.today, cs.primary),
                            _buildStatColumn('Sessions', todaySessions.length, '', Icons.timer, Colors.blue),
                            _buildStatColumn('Total', _sessions.length, '', Icons.history, Colors.purple),
                            _buildStatColumn('Streak', streakInfo, 'days', Icons.local_fire_department, Colors.orange),
                          ],
                        ),
                        if (maxWeekly > 0) ...[
                          const SizedBox(height: 16),
                          // Weekly sparkline
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              final now = DateTime.now();
                              final dayIdx = (now.weekday - 1 + i + 1) % 7;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 40 * sparklineHeight[i],
                                    decoration: BoxDecoration(
                                      color: sparklineHeight[i] > 0
                                          ? cs.primary.withOpacity(0.5 + sparklineHeight[i] * 0.5)
                                          : cs.outlineVariant.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dayNames[dayIdx],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: cs.outline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Quick Log Form
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.add_task, color: cs.onPrimaryContainer, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Quick Log',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Subject with autocomplete
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return _existingSubjects;
                            return _existingSubjects.where((s) =>
                                s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) {
                            _subjectController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            // Sync with our controller
                            if (_subjectController.text.isNotEmpty && controller.text.isEmpty) {
                              controller.text = _subjectController.text;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (v) => _subjectController.text = v,
                              decoration: InputDecoration(
                                labelText: 'Subject',
                                hintText: 'e.g., Calculus, Physics',
                                prefixIcon: const Icon(Icons.book_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _sessionType,
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  prefixIcon: const Icon(Icons.category_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                items: _sessionTypes.map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t[0].toUpperCase() + t.substring(1)),
                                )).toList(),
                                onChanged: (v) => setState(() => _sessionType = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _useCustomTime
                                ? TextField(
                                    controller: _customMinutesController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Custom minutes',
                                      hintText: 'e.g. 37',
                                      prefixIcon: const Icon(Icons.edit),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() {
                                          _useCustomTime = false;
                                          _customMinutesController.clear();
                                        }),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  )
                                : DropdownButtonFormField<int>(
                                    value: _durationMinutes,
                                    decoration: InputDecoration(
                                      labelText: 'Duration',
                                      prefixIcon: const Icon(Icons.schedule),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    items: [
                                      ..._presetMinutes.map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text('${m}m'),
                                      )),
                                      const DropdownMenuItem(value: -1, child: Text('Custom...')),
                                    ],
                                    onChanged: (v) {
                                      if (v == -1) {
                                        setState(() => _useCustomTime = true);
                                      } else if (v != null) {
                                        setState(() => _durationMinutes = v);
                                      }
                                    },
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText: 'What did you study?',
                            prefixIcon: const Icon(Icons.notes_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _quickLog,
                            icon: const Icon(Icons.add),
                            label: const Text('Log Session'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recent Sessions Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Recent Sessions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: cs.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_sessions.length} total',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sessions List
                _sessions.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.history_toggle_off, size: 32, color: cs.onPrimaryContainer),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No sessions logged yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Start logging your study time!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final s = _sessions[index];
                              final typeColor = _typeColor(s.sessionType);
                              return Dismissible(
                                key: ValueKey('session_${s.id ?? index}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: cs.errorContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                                ),
                                onDismissed: (_) {
                                  if (s.id != null) _deleteSession(s.id!);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cs.outlineVariant.withOpacity(0.15)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _typeIcon(s.sessionType),
                                          color: typeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.subjectTag ?? 'General Study',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_formatDuration(s.durationMinutes)} • ${_timeAgo(s.completedAtMillis)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.outline,
                                              ),
                                            ),
                                            if (s.notes != null && s.notes!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                s.notes!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.outline.withOpacity(0.8),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          s.sessionType[0].toUpperCase() + s.sessionType.substring(1),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: typeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _sessions.length,
                          ),
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildStatColumn(String label, int value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _counterAnimation,
          builder: (context, child) {
            final displayValue = (value * _counterAnimation.value).round();
            return Text(
              '$displayValue',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            );
          },
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  int _latestStreak() {
    // Simple streak calculation from sessions
    if (_sessions.isEmpty) return 0;
    final sorted = _sessions.toList()
      ..sort((a, b) => b.completedAtMillis.compareTo(a.completedAtMillis));
    int streak = 0;
    DateTime checkDate = DateTime.now();
    final today = DateTime(checkDate.year, checkDate.month, checkDate.day);
    final Set<String> checkedDays = {};

    for (final s in sorted) {
      final sDate = DateTime.fromMillisecondsSinceEpoch(s.completedAtMillis);
      final sDay = DateTime(sDate.year, sDate.month, sDate.day);
      final dayKey = '${sDay.year}-${sDay.month}-${sDay.day}';

      if (checkedDays.contains(dayKey)) continue;
      checkedDays.add(dayKey);

      final diff = today.difference(sDay).inDays;
      if (diff == streak) {
        streak++;
      } else if (diff > streak) {
        break;
      }
    }
    return streak;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    _customMinutesController.dispose();
    _counterController.dispose();
    super.dispose();
  }
}
