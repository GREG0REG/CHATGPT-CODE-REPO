import 'package:flutter/material.dart';
import '../database_helper.dart';

class RevisionDashboardScreen extends StatefulWidget {
  const RevisionDashboardScreen({super.key});

  @override
  State<RevisionDashboardScreen> createState() => _RevisionDashboardScreenState();
}

class _RevisionDashboardScreenState extends State<RevisionDashboardScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _todayRevisions = [];
  List<Map<String, dynamic>> _overdueRevisions = [];
  List<Map<String, dynamic>> _upcomingRevisions = [];
  List<Map<String, dynamic>> _completedToday = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final today = await db.getTopicsForToday();
    final overdue = await db.getOverdueRevisions();
    final upcoming = await db.getUpcomingRevisions(14);
    final stats = await db.getRevisionStats();

    // Get completed revisions for today
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    setState(() {
      _todayRevisions = today;
      _overdueRevisions = overdue;
      _upcomingRevisions = upcoming;
      _stats = stats.isNotEmpty ? stats : {};
      _loading = false;
    });
  }

  Future<void> _markRevisionComplete(int revisionId, {int? performanceScore}) async {
    final db = DatabaseHelper.instance;
    await db.updateSyllabusRevisionSchedule(
      (await db.getSyllabusRevisionsForTopic(
        _todayRevisions.firstWhere((r) => r['id'] == revisionId)['topicId'] as int,
      )).firstWhere((r) => r.id == revisionId).copyWith(
        isCompleted: 1,
        actualRevisionDateMillis: DateTime.now().millisecondsSinceEpoch,
        performanceScore: performanceScore,
      ),
    );
    await _loadData();
  }

  Future<void> _showPerformanceDialog(int revisionId, String topicName) async {
    int? selectedScore;
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('how well did you know "$topicName"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('rate your understanding (1-10):', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (ctx, setDialogState) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(10, (index) {
                  final score = index + 1;
                  final isSelected = selectedScore == score;
                  Color color;
                  if (score <= 3) color = Colors.red;
                  else if (score <= 6) color = Colors.orange;
                  else color = Colors.green;
                  return ChoiceChip(
                    label: Text('$score'),
                    selected: isSelected,
                    onSelected: (_) => setDialogState(() => selectedScore = score),
                    selectedColor: color.withOpacity(0.3),
                    backgroundColor: cs.surfaceContainerHighest,
                    labelStyle: TextStyle(
                      color: isSelected ? color : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('skip')),
          FilledButton(
            onPressed: selectedScore != null ? () => Navigator.pop(ctx, selectedScore) : null,
            child: const Text('save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _markRevisionComplete(revisionId, performanceScore: result);
    } else {
      await _markRevisionComplete(revisionId);
    }
  }

  ColorScheme get cs => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('revision dashboard'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'today (${_todayRevisions.length})'),
            Tab(text: 'overdue (${_overdueRevisions.length})'),
            Tab(text: 'upcoming (${_upcomingRevisions.length})'),
            const Tab(text: 'analytics'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildOverdueTab(),
                _buildUpcomingTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildTodayTab() {
    if (_todayRevisions.isEmpty) {
      return _buildEmptyState(
        Icons.check_circle_outline,
        'no revisions for today',
        'great job! you are all caught up. new revisions will appear when topics are completed.',
        Colors.green,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayRevisions.length,
      itemBuilder: (ctx, index) {
        final r = _todayRevisions[index];
        return _buildRevisionCard(r, isToday: true);
      },
    );
  }

  Widget _buildOverdueTab() {
    if (_overdueRevisions.isEmpty) {
      return _buildEmptyState(
        Icons.celebration,
        'no overdue revisions!',
        'you are staying on top of your revision schedule. keep it up!',
        Colors.green,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _overdueRevisions.length,
      itemBuilder: (ctx, index) {
        final r = _overdueRevisions[index];
        final daysOverdue = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(r['scheduledDateMillis'] as int),
        ).inDays;
        return _buildRevisionCard(r, isOverdue: true, daysOverdue: daysOverdue);
      },
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcomingRevisions.isEmpty) {
      return _buildEmptyState(
        Icons.calendar_month,
        'no upcoming revisions',
        'complete more topics to generate revision schedules.',
        cs.primary,
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _upcomingRevisions) {
      final date = DateTime.fromMillisecondsSinceEpoch(r['scheduledDateMillis'] as int);
      final key = '${date.day}/${date.month}/${date.year}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (ctx, index) {
        final key = grouped.keys.elementAt(index);
        final items = grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                key,
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 14),
              ),
            ),
            ...items.map((r) => _buildRevisionCard(r)),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    final totalRevisions = (_stats['totalRevisions'] as int?) ?? 0;
    final completedRevisions = (_stats['completedRevisions'] as int?) ?? 0;
    final avgPerformance = (_stats['avgPerformance'] as num?)?.toDouble() ?? 0.0;
    final completionRate = totalRevisions > 0 ? completedRevisions / totalRevisions : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          Row(
            children: [
              _buildAnalyticsCard('total revisions', '$totalRevisions', Icons.repeat, Colors.blue),
              const SizedBox(width: 12),
              _buildAnalyticsCard('completed', '$completedRevisions', Icons.check_circle, Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAnalyticsCard('completion rate', '${(completionRate * 100).round()}%', Icons.trending_up, Colors.purple),
              const SizedBox(width: 12),
              _buildAnalyticsCard('avg performance', avgPerformance > 0 ? '${avgPerformance.toStringAsFixed(1)}/10' : 'N/A', Icons.star, Colors.amber),
            ],
          ),
          const SizedBox(height: 24),
          // Spaced Repetition Info
          Card(
            elevation: 0,
            color: cs.primaryContainer.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('spaced repetition schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildIntervalRow('1st revision', '1 day after completion', 'short-term memory consolidation'),
                  _buildIntervalRow('2nd revision', '3 days after', 'strengthening neural pathways'),
                  _buildIntervalRow('3rd revision', '7 days after', 'medium-term retention'),
                  _buildIntervalRow('4th revision', '14 days after', 'long-term memory formation'),
                  _buildIntervalRow('5th revision', '30 days after', 'deep mastery'),
                  _buildIntervalRow('6th revision', '60 days after', 'permanent retention'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Tips Card
          Card(
            elevation: 0,
            color: Colors.orange.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text('revision tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('active recall: close your notes and write everything you remember'),
                  _buildTip('interleaving: mix different topics instead of blocking one subject'),
                  _buildTip('self-testing: use mcqs and past papers to test understanding'),
                  _buildTip('teach someone: explain concepts aloud as if teaching a friend'),
                  _buildTip('sleep on it: review before bed for better memory consolidation'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalRow(String label, String interval, String benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label.split(' ').first.replaceAll(RegExp(r'[^0-9]'), ''),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(interval, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Text(benefit, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withOpacity(0.7), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevisionCard(Map<String, dynamic> r, {bool isToday = false, bool isOverdue = false, int daysOverdue = 0}) {
    final topicName = r['topicName'] as String? ?? 'Unknown Topic';
    final subjectName = r['subjectName'] as String? ?? 'Unknown Subject';
    final colorHex = r['colorHex'] as String? ?? '#2196F3';
    final revisionNumber = r['revisionNumber'] as int? ?? 1;
    final difficulty = r['difficulty'] as String?;
    final unitName = r['unitName'] as String? ?? '';

    Color subjectColor;
    try {
      final hex = colorHex.replaceFirst('#', '');
      subjectColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      subjectColor = cs.primary;
    }

    final intervalLabels = ['1 day', '3 days', '7 days', '14 days', '30 days', '60 days'];
    final intervalLabel = revisionNumber <= intervalLabels.length ? intervalLabels[revisionNumber - 1] : '${revisionNumber * 7} days';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isOverdue ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isOverdue ? BorderSide(color: Colors.red.withOpacity(0.5), width: 1.5) : BorderSide.none,
      ),
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
                  decoration: BoxDecoration(color: subjectColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subjectName,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text('$daysOverdue days overdue', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                  )
                else if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Text('due today', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(topicName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(unitName, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'revision $revisionNumber · $intervalLabel',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w500),
                  ),
                ),
                if (difficulty != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: difficulty == 'hard' ? Colors.red.withOpacity(0.12) : difficulty == 'medium' ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      difficulty,
                      style: TextStyle(
                        fontSize: 11,
                        color: difficulty == 'hard' ? Colors.red : difficulty == 'medium' ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showPerformanceDialog(r['id'] as int, topicName),
                icon: const Icon(Icons.check),
                label: const Text('mark as revised'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
