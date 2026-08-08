import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subject.dart';
import '../models/syllabus_revision_schedule.dart';

class RevisionDashboardScreen extends StatefulWidget {
  const RevisionDashboardScreen({super.key});

  @override
  State<RevisionDashboardScreen> createState() => _RevisionDashboardScreenState();
}

class _RevisionDashboardScreenState extends State<RevisionDashboardScreen> {
  List<Map<String, dynamic>> _todayRevisions = [];
  List<Map<String, dynamic>> _upcomingRevisions = [];
  List<Map<String, dynamic>> _overdueRevisions = [];
  List<Map<String, dynamic>> _completedRevisions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    final allRevisions = await db.getAllRevisionSchedules();
    final today = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    final overdue = <Map<String, dynamic>>[];
    final completed = <Map<String, dynamic>>[];

    for (final rev in allRevisions) {
      final topic = await db.getSyllabusTopic(rev.topicId);
      final unit = topic != null ? await db.getSyllabusUnit(topic.unitId) : null;
      final subject = unit != null ? await db.getSyllabusSubject(unit.subjectId) : null;

      final data = {
        'revision': rev,
        'topic': topic,
        'subject': subject,
      };

      if (rev.completed) {
        completed.add(data);
      } else if (rev.scheduledDateMillis < todayStart) {
        overdue.add(data);
      } else if (rev.scheduledDateMillis >= todayStart && rev.scheduledDateMillis < todayEnd) {
        today.add(data);
      } else {
        upcoming.add(data);
      }
    }

    setState(() {
      _todayRevisions = today;
      _upcomingRevisions = upcoming;
      _overdueRevisions = overdue;
      _completedRevisions = completed;
      _loading = false;
    });
  }

  Future<void> _markRevisionDone(SyllabusRevisionSchedule rev) async {
    final updated = rev.copyWith(
      isCompleted: 1,
      actualRevisionDateMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.updateSyllabusRevisionSchedule(updated);
    await _loadData();
  }

  Future<void> _markRevisionDoneWithScore(SyllabusRevisionSchedule rev, int score) async {
    final updated = rev.copyWith(
      isCompleted: 1,
      actualRevisionDateMillis: DateTime.now().millisecondsSinceEpoch,
      performanceScore: score,
    );
    await DatabaseHelper.instance.updateSyllabusRevisionSchedule(updated);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Today's revision streak card
        _buildStreakCard(cs),
        const SizedBox(height: 20),

        // Overdue (critical)
        if (_overdueRevisions.isNotEmpty) ...[
          _buildSectionHeader('overdue', Colors.red, _overdueRevisions.length),
          const SizedBox(height: 8),
          ..._overdueRevisions.map((r) => _buildRevisionCard(r, cs, isOverdue: true)),
          const SizedBox(height: 20),
        ],

        // Today
        if (_todayRevisions.isNotEmpty) ...[
          _buildSectionHeader('today', cs.primary, _todayRevisions.length),
          const SizedBox(height: 8),
          ..._todayRevisions.map((r) => _buildRevisionCard(r, cs)),
          const SizedBox(height: 20),
        ] else if (_overdueRevisions.isEmpty) ...[
          _buildEmptyTodayCard(cs),
          const SizedBox(height: 20),
        ],

        // Upcoming
        if (_upcomingRevisions.isNotEmpty) ...[
          _buildSectionHeader('upcoming', Colors.orange, _upcomingRevisions.length),
          const SizedBox(height: 8),
          ..._upcomingRevisions.take(5).map((r) => _buildRevisionCard(r, cs, isUpcoming: true)),
          const SizedBox(height: 20),
        ],

        // Completed this week
        if (_completedRevisions.isNotEmpty) ...[
          _buildSectionHeader('completed recently', Colors.green, _completedRevisions.length),
          const SizedBox(height: 8),
          ..._completedRevisions.take(5).map((r) => _buildCompletedCard(r, cs)),
        ],
      ],
    );
  }

  Widget _buildStreakCard(ColorScheme cs) {
    final streak = _calculateStreak();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer,
              cs.primaryContainer.withOpacity(0.7),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_fire_department, color: cs.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'revision streak',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$streak days',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    streak > 0 ? 'keep it up!' : 'start revising today',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onPrimaryContainer.withOpacity(0.7),
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

  int _calculateStreak() {
    // Simple streak calculation - count consecutive days with completed revisions
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
      final hasRevision = _completedRevisions.any((r) {
        final rev = r['revision'] as SyllabusRevisionSchedule;
        return rev.actualRevisionDateMillis != null &&
            rev.actualRevisionDateMillis! >= dayStart &&
            rev.actualRevisionDateMillis! < dayEnd;
      });
      if (hasRevision) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildRevisionCard(Map<String, dynamic> data, ColorScheme cs, {bool isOverdue = false, bool isUpcoming = false}) {
    final rev = data['revision'] as SyllabusRevisionSchedule;
    final topic = data['topic'] as SyllabusTopic?;
    final subject = data['subject'] as SyllabusSubject?;
    final date = DateTime.fromMillisecondsSinceEpoch(rev.scheduledDateMillis);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isOverdue
          ? Colors.red.withOpacity(0.06)
          : cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.red.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          topic?.name ?? 'topic ${rev.topicId}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            if (subject != null)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: subject.color, shape: BoxShape.circle),
              ),
            if (subject != null) const SizedBox(width: 6),
            if (subject != null)
              Text(subject.name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : cs.onSurfaceVariant,
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOverdue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'overdue',
                  style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              )
            else if (!isUpcoming)
              FilledButton.tonal(
                onPressed: () => _showScoreDialog(rev),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('revise', style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(width: 8),
            Text(
              'r${rev.revisionNumber}',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'how well did you remember?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(10, (i) {
                    final score = i + 1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () => _markRevisionDoneWithScore(rev, score),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: score >= 7
                                  ? Colors.green.withOpacity(0.15)
                                  : score >= 4
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$score',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: score >= 7
                                    ? Colors.green
                                    : score >= 4
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> data, ColorScheme cs) {
    final rev = data['revision'] as SyllabusRevisionSchedule;
    final topic = data['topic'] as SyllabusTopic?;
    final subject = data['subject'] as SyllabusSubject?;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: Colors.green.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.withOpacity(0.2)),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        title: Text(
          topic?.name ?? 'topic ${rev.topicId}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: subject != null
            ? Text(subject.name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
            : null,
        trailing: rev.performanceScore != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (rev.performanceScore! >= 7
                          ? Colors.green
                          : rev.performanceScore! >= 4
                              ? Colors.orange
                              : Colors.red)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'score: ${rev.performanceScore}',
                  style: TextStyle(
                    fontSize: 11,
                    color: rev.performanceScore! >= 7
                        ? Colors.green
                        : rev.performanceScore! >= 4
                            ? Colors.orange
                            : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyTodayCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.celebration, size: 40, color: cs.primary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'all caught up!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'no revisions due today. great job staying on track!',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreDialog(SyllabusRevisionSchedule rev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('revision complete'),
        content: const Text('rate your understanding (1-10):'),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _markRevisionDone(rev);
          }, child: const Text('skip rating')),
        ],
      ),
    );
  }
}
