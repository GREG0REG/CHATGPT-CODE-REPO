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
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    setState(() {
      _topic = topic;
      _subtopics = subtopics;
      _resources = resources;
      _revisions = revisions;
      _loading = false;
    });
  }

  Future<void> _updateTopicStatus(String newStatus) async {
    if (_topic == null) return;
    final updated = _topic!.copyWith(status: newStatus);
    await DatabaseHelper.instance.updateSyllabusTopic(updated);
    if (newStatus == 'completed') {
      await DatabaseHelper.instance.generateRevisionSchedules(_topic!.id!);
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
    );
    await DatabaseHelper.instance.updateSyllabusRevisionSchedule(updated);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_topic?.name ?? 'Topic'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
            Tab(text: 'Revision'),
          ],
          onTap: (index) {
            final statuses = ['inProgress', 'completed', 'needsRevision'];
            if (_topic != null && _topic!.status != statuses[index]) {
              _updateTopicStatus(statuses[index]);
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSubtopicsTab(cs),
                _buildSubtopicsTab(cs), // Same content, status is visual
                _buildRevisionTab(cs),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubtopic,
        icon: const Icon(Icons.add),
        label: const Text('Add Subtopic'),
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
              _buildStatusChip('Not Started', 'notStarted', Colors.grey, cs),
              _buildStatusChip('In Progress', 'inProgress', Colors.orange, cs),
              _buildStatusChip('Completed', 'completed', Colors.green, cs),
              _buildStatusChip('Needs Revision', 'needsRevision', Colors.red, cs),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Subtopics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_subtopics.isEmpty)
            Text(
              'No subtopics yet. Tap + to add one.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            ..._subtopics.map((st) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                onChanged: (_) => _toggleSubtopic(st),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: st.status != 'completed' && _topic?.difficulty != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _topic!.difficulty == 'hard'
                              ? Colors.red.withOpacity(0.12)
                              : _topic!.difficulty == 'medium'
                                  ? Colors.orange.withOpacity(0.12)
                                  : Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _topic!.difficulty![0].toUpperCase() + _topic!.difficulty!.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            color: _topic!.difficulty == 'hard'
                                ? Colors.red
                                : _topic!.difficulty == 'medium'
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                      )
                    : null,
              ),
            )),
          const SizedBox(height: 24),
          const Text(
            'Resources',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
                label: const Text('Add'),
                onPressed: _addResource,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Study Sessions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: DatabaseHelper.instance.getStudyTimeForTopic(widget.topicId),
            builder: (ctx, snapshot) {
              final minutes = snapshot.data ?? 0;
              if (minutes == 0) {
                return Text(
                  'No study sessions linked yet.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                );
              }
              final hours = minutes ~/ 60;
              final mins = minutes % 60;
              return Text(
                'Total study time: ${hours > 0 ? '$hours hr ' : ''}$mins min',
                style: TextStyle(color: cs.onSurfaceVariant),
              );
            },
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
          const Text(
            'Revision Schedule',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_revisions.isEmpty)
            Text(
              'Complete this topic to generate revision schedule.',
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
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
    );
  }
}
