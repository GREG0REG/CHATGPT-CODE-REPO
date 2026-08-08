import 'package:flutter/material.dart';
import '../database_helper.dart';

class DeadlineDashboardScreen extends StatefulWidget {
  const DeadlineDashboardScreen({super.key});

  @override
  State<DeadlineDashboardScreen> createState() => _DeadlineDashboardScreenState();
}

class _DeadlineDashboardScreenState extends State<DeadlineDashboardScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _overdue = [];
  List<Map<String, dynamic>> _upcoming = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final overdue = await db.getOverdueDeadlines();
    final upcoming = await db.getUpcomingDeadlines(30);
    setState(() {
      _overdue = overdue;
      _upcoming = upcoming;
      _loading = false;
    });
  }

  Future<void> _markComplete(int topicId) async {
    await DatabaseHelper.instance.markDeadlineComplete(topicId);
    // Also mark topic as completed
    final topic = await DatabaseHelper.instance.getSyllabusTopic(topicId);
    if (topic != null) {
      final updated = topic.copyWith(status: 'completed');
      await DatabaseHelper.instance.updateSyllabusTopic(updated);
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('deadline dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'overdue (${_overdue.length})'),
            Tab(text: 'upcoming (${_upcoming.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDeadlineList(_overdue, cs, isOverdue: true),
                _buildDeadlineList(_upcoming, cs, isOverdue: false),
              ],
            ),
    );
  }

  Widget _buildDeadlineList(List<Map<String, dynamic>> deadlines, ColorScheme cs, {required bool isOverdue}) {
    if (deadlines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOverdue ? Icons.check_circle : Icons.event_available,
              size: 64,
              color: isOverdue ? Colors.green.withOpacity(0.5) : cs.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isOverdue ? 'no overdue deadlines!' : 'no upcoming deadlines',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deadlines.length,
      itemBuilder: (ctx, index) {
        final d = deadlines[index];
        final topicName = d['topicName'] as String;
        final subjectName = d['subjectName'] as String;
        final colorHex = d['colorHex'] as String? ?? '#2196F3';
        final targetDate = DateTime.fromMillisecondsSinceEpoch(d['targetDateMillis'] as int);
        final daysDiff = DateTime(targetDate.year, targetDate.month, targetDate.day)
            .difference(DateTime.now())
            .inDays;

        Color subjectColor;
        try {
          final hex = colorHex.replaceFirst('#', '');
          subjectColor = Color(int.parse('FF$hex', radix: 16));
        } catch (_) {
          subjectColor = cs.primary;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      decoration: BoxDecoration(
                        color: subjectColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subjectName,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'overdue',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  topicName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isOverdue ? Colors.red : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${targetDate.day}/${targetDate.month}/${targetDate.year}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (!isOverdue) ...[
                      const SizedBox(width: 12),
                      Text(
                        daysDiff == 0 ? 'today' : '$daysDiff days left',
                        style: TextStyle(
                          color: daysDiff <= 3 ? Colors.orange : Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () => _markComplete(d['topicId'] as int),
                    child: const Text('mark complete'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
