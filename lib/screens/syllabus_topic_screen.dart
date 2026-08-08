import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database_helper.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subtopic.dart';
import '../models/syllabus_resource.dart';
import '../models/syllabus_revision_schedule.dart';
import 'syllabus_add_edit_screen.dart';

class SyllabusTopicScreen extends StatefulWidget {
  final int topicId;
  const SyllabusTopicScreen({super.key, required this.topicId});

  @override
  State<SyllabusTopicScreen> createState() => _SyllabusTopicScreenState();
}

class _SyllabusTopicScreenState extends State<SyllabusTopicScreen>
    with SingleTickerProviderStateMixin {
  SyllabusTopic? _topic;
  List<SyllabusSubtopic> _subtopics = [];
  List<SyllabusResource> _resources = [];
  List<SyllabusRevisionSchedule> _revisions = [];
  Map<String, dynamic>? _mcqStats;
  Map<String, dynamic>? _deadlineInfo;
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
    final topic = await db.getSyllabusTopic(widget.topicId);
    final subtopics = await db.getSyllabusSubtopicsForTopic(widget.topicId);
    final resources = await db.getSyllabusResourcesForTopic(widget.topicId);
    final revisions = await db.getSyllabusRevisionsForTopic(widget.topicId);
    final mcq = await db.getTopicMcqStats(widget.topicId);
    final deadline = await db.getChapterDeadlineForTopic(widget.topicId);
    setState(() {
      _topic = topic;
      _subtopics = subtopics;
      _resources = resources;
      _revisions = revisions;
      _mcqStats = mcq;
      _deadlineInfo = deadline;
      _loading = false;
    });
  }

  Future<void> _updateTopicStatus(String newStatus) async {
    if (_topic == null) return;
    final updated = _topic!.copyWith(status: newStatus);
    await DatabaseHelper.instance.updateSyllabusTopic(updated);
    if (newStatus == 'completed') {
      await DatabaseHelper.instance.generateRevisionSchedules(_topic!.id!);
      await DatabaseHelper.instance.markDeadlineComplete(_topic!.id!);
    }
    await _loadData();
  }

  Future<void> _addSubtopic() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyllabusAddEditScreen(
          level: 'subtopic',
          parentTopicId: widget.topicId,
        ),
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _toggleSubtopic(SyllabusSubtopic subtopic) async {
    final newStatus = subtopic.status == 'completed' ? 'notStarted' : 'completed';
    final updated = subtopic.copyWith(status: newStatus);
    await DatabaseHelper.instance.updateSyllabusSubtopic(updated);
    await _loadData();
  }

  Future<void> _addResource() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final resource = SyllabusResource(
      topicId: widget.topicId,
      resourceType: file.extension ?? 'file',
      title: file.name,
      filePath: file.path,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertSyllabusResource(resource);
    await _loadData();
  }

  Future<void> _toggleRevisionComplete(SyllabusRevisionSchedule revision) async {
    final updated = revision.copyWith(
      isCompleted: revision.completed ? 0 : 1,
      actualRevisionDateMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.updateSyllabusRevisionSchedule(updated);
    await _loadData();
  }

  Future<void> _showMcqTracker() async {
    final attemptedController = TextEditingController(
      text: (_topic?.mcqsAttempted ?? 0).toString(),
    );
    final correctController = TextEditingController(
      text: (_topic?.mcqsCorrect ?? 0).toString(),
    );
    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('update mcq stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: attemptedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'mcqs attempted',
                prefixIcon: Icon(Icons.quiz_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: correctController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'mcqs correct',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('cancel')),
          FilledButton(
            onPressed: () {
              final att = int.tryParse(attemptedController.text) ?? 0;
              final corr = int.tryParse(correctController.text) ?? 0;
              Navigator.pop(ctx, {'attempted': att, 'correct': corr});
            },
            child: const Text('save'),
          ),
        ],
      ),
    );
    attemptedController.dispose();
    correctController.dispose();

    if (result != null) {
      await DatabaseHelper.instance.updateTopicMcqStats(
        widget.topicId,
        result['attempted']!,
        result['correct']!,
      );
      await _loadData();
    }
  }

  Future<void> _showSetDeadline() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadlineInfo != null
          ? DateTime.fromMillisecondsSinceEpoch(_deadlineInfo!['targetDateMillis'] as int)
          : DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final existing = await DatabaseHelper.instance.getChapterDeadlineForTopic(widget.topicId);
      if (existing != null) {
        await DatabaseHelper.instance.updateChapterDeadline(existing['id'] as int, {
          'topicId': widget.topicId,
          'targetDateMillis': picked.millisecondsSinceEpoch,
        });
      } else {
        await DatabaseHelper.instance.insertChapterDeadline({
          'topicId': widget.topicId,
          'targetDateMillis': picked.millisecondsSinceEpoch,
        });
      }
      final updatedTopic = _topic!.copyWith(
        targetCompletionDateMillis: picked.millisecondsSinceEpoch,
      );
      await DatabaseHelper.instance.updateSyllabusTopic(updatedTopic);
      await _loadData();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_topic?.name ?? 'topic'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'subtopics'),
            Tab(text: 'resources'),
            Tab(text: 'revision'),
            Tab(text: 'mcq track'),
          ],
        ),
        actions: [
          if (_topic != null && _topic!.isOverdue)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('overdue', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.red.withOpacity(0.15),
                side: BorderSide.none,
                labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSubtopicsTab(cs),
                _buildResourcesTab(cs),
                _buildRevisionTab(cs),
                _buildMcqTab(cs),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubtopic,
        icon: const Icon(Icons.add),
        label: const Text('add subtopic'),
      ),
    );
  }

  Widget _buildSubtopicsTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chips
          Wrap(
            spacing: 8,
            children: [
              _buildStatusChip('not started', 'notStarted', Colors.grey, cs),
              _buildStatusChip('in progress', 'inProgress', Colors.orange, cs),
              _buildStatusChip('completed', 'completed', Colors.green, cs),
              _buildStatusChip('needs revision', 'needsRevision', Colors.red, cs),
            ],
          ),
          const SizedBox(height: 20),
          const Text('subtopics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_subtopics.isEmpty)
            Text('no subtopics yet. tap + to add one.', style: TextStyle(color: cs.onSurfaceVariant))
          else
            ..._subtopics.map((st) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: CheckboxListTile(
                title: Text(
                  st.name,
                  style: TextStyle(
                    decoration: st.status == 'completed' ? TextDecoration.lineThrough : null,
                    color: st.status == 'completed' ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
                value: st.status == 'completed',
                onChanged: (_) => _toggleSubtopic(st),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildResourcesTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('resources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
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
                  await _loadData();
                },
              )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('add'),
                onPressed: _addResource,
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRevisionTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('revision schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (_revisions.isEmpty)
            Text(
              'complete this topic to generate revision schedule.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 10,
              children: _revisions.map((r) {
                final isDone = r.completed;
                final label = r.revisionNumber == 1 ? '1d'
                    : r.revisionNumber == 2 ? '3d'
                    : r.revisionNumber == 3 ? '7d'
                    : r.revisionNumber == 4 ? '14d'
                    : '${r.revisionNumber * 7}d';
                return GestureDetector(
                  onTap: () => _toggleRevisionComplete(r),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDone
                          ? Colors.green.withOpacity(0.15)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDone ? Colors.green : cs.outlineVariant,
                        width: isDone ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDone ? Icons.check : Icons.hourglass_empty,
                          size: 18,
                          color: isDone ? Colors.green : cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.green : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMcqTab(ColorScheme cs) {
    final attempted = _mcqStats?['attempted'] ?? 0;
    final correct = _mcqStats?['correct'] ?? 0;
    final accuracy = _mcqStats?['accuracy'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MCQ Stats Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.quiz, size: 40, color: Colors.teal),
                  const SizedBox(height: 12),
                  Text(
                    '$accuracy%',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const Text('accuracy', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('attempted', attempted.toString(), cs),
                      _buildStatColumn('correct', correct.toString(), Colors.green),
                      _buildStatColumn('wrong', (attempted - correct).toString(), Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Best mock score
          if (_topic?.bestMockScore != null)
            Card(
              elevation: 0,
              color: cs.primaryContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: const Text('best mock score'),
                trailing: Text(
                  '${_topic!.bestMockScore}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Deadline section
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(
                Icons.event_busy,
                color: _topic?.isOverdue == true ? Colors.red : cs.primary,
              ),
              title: Text(
                _deadlineInfo != null
                    ? 'deadline: ${_formatDate(_deadlineInfo!['targetDateMillis'] as int)}'
                    : 'no deadline set',
              ),
              subtitle: _topic?.daysUntilDeadline != null
                  ? Text(
                      _topic!.isOverdue
                          ? '${_topic!.daysUntilDeadline!.abs()} days overdue'
                          : '${_topic!.daysUntilDeadline} days remaining',
                      style: TextStyle(
                        color: _topic!.isOverdue ? Colors.red : Colors.green,
                      ),
                    )
                  : null,
              trailing: FilledButton.tonal(
                onPressed: _showSetDeadline,
                child: Text(_deadlineInfo != null ? 'change' : 'set'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _showMcqTracker,
            icon: const Icon(Icons.edit),
            label: const Text('update mcq stats'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ),
    );
  }

    Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatusChip(String label, String status, Color color, ColorScheme cs) {
    final isSelected = _topic?.status == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _updateTopicStatus(status),
      selectedColor: color.withOpacity(0.2),
      backgroundColor: cs.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isSelected ? color : cs.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? color : Colors.transparent),
    );
  }

  String _formatDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.day}/${d.month}/${d.year}';
  }
}
