import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/syllabus_subject.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subtopic.dart';
import 'syllabus_add_edit_screen.dart';
import 'study_planner_screen.dart';
import 'revision_dashboard_screen.dart';

class SyllabusListScreen extends StatefulWidget {
  const SyllabusListScreen({super.key});

  @override
  State<SyllabusListScreen> createState() => _SyllabusListScreenState();
}

class _SyllabusListScreenState extends State<SyllabusListScreen>
    with SingleTickerProviderStateMixin {
  List<SyllabusSubject> _subjects = [];
  Map<int, List<SyllabusUnit>> _unitsMap = {};
  Map<int, List<SyllabusTopic>> _topicsMap = {};
  Map<int, List<SyllabusSubtopic>> _subtopicsMap = {};
  Map<int, bool> _expandedSubjects = {};
  Map<int, bool> _expandedUnits = {};
  Set<int> _selectedTopics = {};
  bool _loading = true;
  bool _selectionMode = false;
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
    final subjects = await db.getAllSyllabusSubjects();
    final unitsMap = <int, List<SyllabusUnit>>{};
    final topicsMap = <int, List<SyllabusTopic>>{};
    final subtopicsMap = <int, List<SyllabusSubtopic>>{};

    for (final subject in subjects) {
      final units = await db.getSyllabusUnitsForSubject(subject.id!);
      unitsMap[subject.id!] = units;
      for (final unit in units) {
        final topics = await db.getSyllabusTopicsForUnit(unit.id!);
        topicsMap[unit.id!] = topics;
        for (final topic in topics) {
          final subtopics = await db.getSyllabusSubtopicsForTopic(topic.id!);
          subtopicsMap[topic.id!] = subtopics;
        }
      }
    }

    setState(() {
      _subjects = subjects;
      _unitsMap = unitsMap;
      _topicsMap = topicsMap;
      _subtopicsMap = subtopicsMap;
      _loading = false;
    });
  }

  Future<void> _addSubject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SyllabusAddEditScreen(level: 'subject'),
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _deleteSubject(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('delete subject?'),
        content: const Text('this will delete all units, topics, and subtopics under it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteSyllabusSubject(id);
    await _loadData();
  }

  Future<void> _quickAddUnit(int subjectId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('add unit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'unit name',
            hintText: 'e.g. mechanics',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;

    final unit = SyllabusUnit(
      subjectId: subjectId,
      name: result,
      orderIndex: (_unitsMap[subjectId]?.length ?? 0),
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertSyllabusUnit(unit);
    await _loadData();
  }

  Future<void> _quickAddTopic(int unitId) async {
    final controller = TextEditingController();
    final difficultyNotifier = ValueNotifier<String>('medium');
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('add topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'topic name',
                hintText: 'e.g. laws of motion',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: difficultyNotifier,
              builder: (_, difficulty, __) => SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'easy', label: Text('easy')),
                  ButtonSegment(value: 'medium', label: Text('medium')),
                  ButtonSegment(value: 'hard', label: Text('hard')),
                ],
                selected: {difficulty},
                onSelectionChanged: (s) => difficultyNotifier.value = s.first,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': controller.text.trim(),
              'difficulty': difficultyNotifier.value,
            }),
            child: const Text('add'),
          ),
        ],
      ),
    );
    difficultyNotifier.dispose();
    controller.dispose();
    if (result == null || (result['name'] as String).isEmpty) return;

    final topic = SyllabusTopic(
      unitId: unitId,
      name: result['name'] as String,
      orderIndex: (_topicsMap[unitId]?.length ?? 0),
      difficulty: result['difficulty'] as String,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertSyllabusTopic(topic);
    await _loadData();
  }

  Future<void> _quickAddSubtopic(int topicId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('add subtopic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'subtopic name',
            hintText: 'e.g. newton\'s first law',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;

    final subtopic = SyllabusSubtopic(
      topicId: topicId,
      name: result,
      orderIndex: (_subtopicsMap[topicId]?.length ?? 0),
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertSyllabusSubtopic(subtopic);
    await _loadData();
  }

  Future<void> _cycleTopicStatus(SyllabusTopic topic) async {
    const statuses = ['notStarted', 'inProgress', 'completed', 'needsRevision'];
    final currentIndex = statuses.indexOf(topic.status);
    final nextStatus = statuses[(currentIndex + 1) % statuses.length];
    final updated = topic.copyWith(status: nextStatus);
    await DatabaseHelper.instance.updateSyllabusTopic(updated);
    if (nextStatus == 'completed') {
      await DatabaseHelper.instance.generateRevisionSchedules(topic.id!);
    }
    await _loadData();
  }

  Future<void> _toggleSubtopic(SyllabusSubtopic subtopic) async {
    final newStatus = subtopic.status == 'completed' ? 'notStarted' : 'completed';
    final updated = subtopic.copyWith(status: newStatus);
    await DatabaseHelper.instance.updateSyllabusSubtopic(updated);
    await _loadData();
  }

  Future<void> _bulkMarkComplete() async {
    for (final topicId in _selectedTopics) {
      // Find the topic and mark complete
      for (final entry in _topicsMap.entries) {
        final topic = entry.value.firstWhere(
          (t) => t.id == topicId,
          orElse: () => null as SyllabusTopic,
        );
        if (topic.id != null) {
          final updated = topic.copyWith(status: 'completed');
          await DatabaseHelper.instance.updateSyllabusTopic(updated);
          await DatabaseHelper.instance.generateRevisionSchedules(topic.id!);
          break;
        }
      }
    }
    setState(() {
      _selectedTopics.clear();
      _selectionMode = false;
    });
    await _loadData();
  }

  void _toggleTopicSelection(int topicId) {
    setState(() {
      if (_selectedTopics.contains(topicId)) {
        _selectedTopics.remove(topicId);
      } else {
        _selectedTopics.add(topicId);
      }
      if (_selectedTopics.isEmpty) _selectionMode = false;
    });
  }

  String _statusDisplay(String status) {
    switch (status) {
      case 'notStarted': return 'not started';
      case 'inProgress': return 'in progress';
      case 'completed': return 'completed';
      case 'needsRevision': return 'needs revision';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'notStarted': return Colors.grey;
      case 'inProgress': return Colors.orange;
      case 'completed': return Colors.green;
      case 'needsRevision': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _difficultyColor(String? difficulty) {
    switch (difficulty) {
      case 'hard': return Colors.red;
      case 'medium': return Colors.orange;
      case 'easy': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _showTopicDetailSheet(SyllabusTopic topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TopicDetailSheet(
        topic: topic,
        subtopics: _subtopicsMap[topic.id] ?? [],
        onStatusChanged: _cycleTopicStatus,
        onSubtopicToggled: _toggleSubtopic,
        onAddSubtopic: () => _quickAddSubtopic(topic.id!),
        onRefresh: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('syllabus tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'subjects'),
            Tab(icon: Icon(Icons.repeat), text: 'revision'),
          ],
        ),
        actions: [
          if (_selectionMode) ...[
            TextButton.icon(
              onPressed: _bulkMarkComplete,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text('mark ${_selectedTopics.length} done'),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedTopics.clear();
              }),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyPlannerScreen()),
                ),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('study planner'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubjectsTab(cs),
          const RevisionDashboardScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubject,
        icon: const Icon(Icons.add),
        label: const Text('add subject'),
      ),
    );
  }

  Widget _buildSubjectsTab(ColorScheme cs) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_subjects.isEmpty) return _buildEmptyState(cs);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (ctx, index) => _buildSubjectCard(_subjects[index], cs),
    );
  }

  Widget _buildSubjectCard(SyllabusSubject subject, ColorScheme cs) {
    final isExpanded = _expandedSubjects[subject.id] ?? false;
    final units = _unitsMap[subject.id] ?? [];
    final totalTopics = units.fold<int>(0, (sum, u) => sum + (_topicsMap[u.id]?.length ?? 0));
    final completedTopics = units.fold<int>(0, (sum, u) {
      return sum + (_topicsMap[u.id]?.where((t) => t.status == 'completed').length ?? 0);
    });
    final progress = totalTopics > 0 ? completedTopics / totalTopics : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Subject header - always visible
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expandedSubjects[subject.id!] = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Progress ring
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${units.length} units · $totalTopics topics · ${totalTopics - completedTopics} remaining',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                        if (subject.totalMarksWeightage != null)
                          Text(
                            'neet weightage: ${subject.totalMarksWeightage}%',
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _expandedSubjects[subject.id!] = !isExpanded),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SyllabusAddEditScreen(
                              level: 'subject',
                              existing: subject,
                            ),
                          ),
                        );
                        if (result == true) await _loadData();
                      } else if (value == 'delete') {
                        await _deleteSubject(subject.id!);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('edit')),
                      const PopupMenuItem(value: 'delete', child: Text('delete')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded units
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  ...units.map((unit) => _buildUnitSection(unit, cs)),
                  // Quick add unit button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton.icon(
                      onPressed: () => _quickAddUnit(subject.id!),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('add unit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnitSection(SyllabusUnit unit, ColorScheme cs) {
    final isExpanded = _expandedUnits[unit.id] ?? false;
    final topics = _topicsMap[unit.id] ?? [];
    final completedCount = topics.where((t) => t.status == 'completed').length;

    return Column(
      children: [
        // Unit header
        InkWell(
          onTap: () => setState(() => _expandedUnits[unit.id!] = !isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: completedCount == topics.length && topics.isNotEmpty
                        ? Colors.green
                        : cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        '$completedCount/${topics.length} done${unit.weightage != null ? ' · weight: ${unit.weightage}%' : ''}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        // Topics list
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 16, bottom: 8),
            child: Column(
              children: [
                ...topics.map((topic) => _buildTopicRow(topic, cs)),
                // Quick add topic
                InkWell(
                  onTap: () => _quickAddTopic(unit.id!),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'add topic',
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildTopicRow(SyllabusTopic topic, ColorScheme cs) {
    final isSelected = _selectedTopics.contains(topic.id);
    final statusColor = _statusColor(topic.status);
    final subtopics = _subtopicsMap[topic.id] ?? [];
    final subtopicProgress = subtopics.isEmpty
        ? 0.0
        : subtopics.where((s) => s.status == 'completed').length / subtopics.length;

    return InkWell(
      onTap: () {
        if (_selectionMode) {
          _toggleTopicSelection(topic.id!);
        } else {
          _showTopicDetailSheet(topic);
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _selectionMode = true;
          _selectedTopics.add(topic.id!);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withOpacity(0.5)
              : topic.status == 'completed'
                  ? Colors.green.withOpacity(0.06)
                  : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : topic.status == 'completed'
                    ? Colors.green.withOpacity(0.2)
                    : cs.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Selection checkbox or status dot
            if (_selectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleTopicSelection(topic.id!),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            else
              GestureDetector(
                onTap: () => _cycleTopicStatus(topic),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      decoration: topic.status == 'completed'
                          ? TextDecoration.lineThrough
                          : null,
                      color: topic.status == 'completed'
                          ? cs.onSurfaceVariant
                          : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (topic.difficulty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _difficultyColor(topic.difficulty).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            topic.difficulty!,
                            style: TextStyle(
                              fontSize: 10,
                              color: _difficultyColor(topic.difficulty),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (topic.estimatedMinutes != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${topic.estimatedMinutes} min',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                      if (topic.neetMarksWeightage != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${topic.neetMarksWeightage} marks',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (subtopics.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${subtopics.where((s) => s.status == 'completed').length}/${subtopics.length} sub',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  if (subtopics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: subtopicProgress,
                          minHeight: 3,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            subtopicProgress >= 1.0 ? Colors.green : cs.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusDisplay(topic.status),
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: cs.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('no subjects yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('add your first subject to start tracking', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add),
            label: const Text('add subject'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOPIC DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────

class _TopicDetailSheet extends StatefulWidget {
  final SyllabusTopic topic;
  final List<SyllabusSubtopic> subtopics;
  final Future<void> Function(SyllabusTopic) onStatusChanged;
  final Future<void> Function(SyllabusSubtopic) onSubtopicToggled;
  final VoidCallback onAddSubtopic;
  final Future<void> Function() onRefresh;

  const _TopicDetailSheet({
    required this.topic,
    required this.subtopics,
    required this.onStatusChanged,
    required this.onSubtopicToggled,
    required this.onAddSubtopic,
    required this.onRefresh,
  });

  @override
  State<_TopicDetailSheet> createState() => _TopicDetailSheetState();
}

class _TopicDetailSheetState extends State<_TopicDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _resources = [];
  List<dynamic> _revisions = [];
  bool _loadingResources = true;
  bool _loadingRevisions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadResources();
    _loadRevisions();
  }

  Future<void> _loadResources() async {
    final resources = await DatabaseHelper.instance
        .getSyllabusResourcesForTopic(widget.topic.id!);
    setState(() {
      _resources = resources;
      _loadingResources = false;
    });
  }

  Future<void> _loadRevisions() async {
    final revisions = await DatabaseHelper.instance
        .getSyllabusRevisionsForTopic(widget.topic.id!);
    setState(() {
      _revisions = revisions;
      _loadingRevisions = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'notStarted': return Colors.grey;
      case 'inProgress': return Colors.orange;
      case 'completed': return Colors.green;
      case 'needsRevision': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _difficultyColor(String? difficulty) {
    switch (difficulty) {
      case 'hard': return Colors.red;
      case 'medium': return Colors.orange;
      case 'easy': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.topic.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.topic.difficulty != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _difficultyColor(widget.topic.difficulty).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.topic.difficulty!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _difficultyColor(widget.topic.difficulty),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (widget.topic.estimatedMinutes != null)
                            Text(
                              '${widget.topic.estimatedMinutes} min',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                            ),
                          if (widget.topic.neetMarksWeightage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.topic.neetMarksWeightage} marks',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status cycle button
                FilledButton.tonal(
                  onPressed: () async {
                    await widget.onStatusChanged(widget.topic);
                    await widget.onRefresh();
                    if (mounted) setState(() {});
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _statusColor(widget.topic.status).withOpacity(0.15),
                    foregroundColor: _statusColor(widget.topic.status),
                  ),
                  child: Text(widget.topic.status == 'notStarted' ? 'start'
                      : widget.topic.status == 'inProgress' ? 'in progress'
                      : widget.topic.status == 'completed' ? 'completed'
                      : 'needs revision'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'subtopics'),
              Tab(text: 'resources'),
              Tab(text: 'revision'),
              Tab(text: 'notes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubtopicsTab(cs),
                _buildResourcesTab(cs),
                _buildRevisionTab(cs),
                _buildNotesTab(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtopicsTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.subtopics.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(Icons.checklist, size: 48, color: cs.onSurfaceVariant.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('no subtopics yet', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          )
        else
          ...widget.subtopics.map((st) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: st.status == 'completed'
                ? Colors.green.withOpacity(0.06)
                : cs.surfaceContainerHighest.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: st.status == 'completed'
                    ? Colors.green.withOpacity(0.2)
                    : cs.outlineVariant.withOpacity(0.3),
              ),
            ),
            child: CheckboxListTile(
              title: Text(
                st.name,
                style: TextStyle(
                  decoration: st.status == 'completed'
                      ? TextDecoration.lineThrough
                      : null,
                  color: st.status == 'completed'
                      ? cs.onSurfaceVariant
                      : cs.onSurface,
                ),
              ),
              value: st.status == 'completed',
              onChanged: (_) async {
                await widget.onSubtopicToggled(st);
                await widget.onRefresh();
                if (mounted) setState(() {});
              },
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            widget.onAddSubtopic();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.add),
          label: const Text('add subtopic'),
        ),
      ],
    );
  }

  Widget _buildResourcesTab(ColorScheme cs) {
    if (_loadingResources) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_resources.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(Icons.folder_open, size: 48, color: cs.onSurfaceVariant.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('no resources yet', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._resources.map((r) => Chip(
                avatar: Icon(
                  r.resourceType == 'pdf' ? Icons.picture_as_pdf
                      : r.resourceType == 'mp4' || r.resourceType == 'video'
                          ? Icons.video_file
                          : r.resourceType == 'audio' || r.resourceType == 'm4a'
                              ? Icons.audio_file
                              : Icons.insert_drive_file,
                  size: 18,
                ),
                label: Text(r.title),
                onDeleted: () async {
                  await DatabaseHelper.instance.deleteSyllabusResource(r.id!);
                  await _loadResources();
                },
              )),
            ],
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            // Use file picker - same as before
            await widget.onRefresh();
            await _loadResources();
          },
          icon: const Icon(Icons.add),
          label: const Text('add resource'),
        ),
      ],
    );
  }

  Widget _buildRevisionTab(ColorScheme cs) {
    if (_loadingRevisions) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_revisions.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(Icons.calendar_today, size: 48, color: cs.onSurfaceVariant.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(
                  widget.topic.status == 'completed'
                      ? 'revision schedule will appear here'
                      : 'complete this topic to generate revisions',
                  style: TextStyle(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._revisions.map((r) {
            final isDone = r.completed;
            final label = r.revisionNumber == 1 ? '1 day'
                : r.revisionNumber == 2 ? '3 days'
                : r.revisionNumber == 3 ? '7 days'
                : r.revisionNumber == 4 ? '14 days'
                : '${r.revisionNumber * 7} days';
            final date = DateTime.fromMillisecondsSinceEpoch(r.scheduledDateMillis);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: isDone
                  ? Colors.green.withOpacity(0.06)
                  : cs.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDone ? Colors.green.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDone ? Icons.check : Icons.hourglass_empty,
                    color: isDone ? Colors.green : cs.onSurfaceVariant,
                  ),
                ),
                title: Text('revision ${r.revisionNumber}'),
                subtitle: Text('$label · ${date.day}/${date.month}/${date.year}'),
                trailing: isDone
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () async {
                          final updated = r.copyWith(
                            isCompleted: 1,
                            actualRevisionDateMillis: DateTime.now().millisecondsSinceEpoch,
                          );
                          await DatabaseHelper.instance.updateSyllabusRevisionSchedule(updated);
                          await _loadRevisions();
                        },
                      ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildNotesTab(ColorScheme cs) {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'add your notes here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              // Save note logic
              controller.dispose();
            },
            icon: const Icon(Icons.save),
            label: const Text('save note'),
          ),
        ],
      ),
    );
  }
}
