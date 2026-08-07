import 'package:flutter/material.dart';
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

class _SyllabusTopicScreenState extends State<SyllabusTopicScreen> {
  SyllabusTopic? _topic;
  List<SyllabusSubtopic> _subtopics = [];
  List<SyllabusResource> _resources = [];
  List<SyllabusRevisionSchedule> _revisions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _updateTopicStatus(TopicStatus newStatus) async {
    if (_topic == null) return;
    final updated = SyllabusTopic(
      id: _topic!.id,
      unitId: _topic!.unitId,
      name: _topic!.name,
      orderIndex: _topic!.orderIndex,
      status: newStatus.name,
      difficulty: _topic!.difficulty,
      estimatedMinutes: _topic!.estimatedMinutes,
      createdAtMillis: _topic!.createdAtMillis,
    );
    await DatabaseHelper.instance.updateSyllabusTopic(updated);
    // If completed, auto-generate revision schedule
    if (newStatus == TopicStatus.completed) {
      await DatabaseHelper.instance.generateRevisionSchedules(_topic!.id!);
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_topic?.name ?? 'Topic'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status selector
                  Text('Status', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<TopicStatus>(
                    segments: const [
                      ButtonSegment(value: TopicStatus.notStarted, label: Text('Not Started')),
                      ButtonSegment(value: TopicStatus.inProgress, label: Text('In Progress')),
                      ButtonSegment(value: TopicStatus.completed, label: Text('Completed')),
                      ButtonSegment(value: TopicStatus.needsRevision, label: Text('Needs Revision')),
                    ],
                    selected: {_topic!.statusEnum},
                    onSelectionChanged: (Set<TopicStatus> newSelection) {
                      _updateTopicStatus(newSelection.first);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Subtopics
                  Text('Subtopics', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._subtopics.map((st) => CheckboxListTile(
                        title: Text(st.name),
                        value: st.status == 'completed',
                        onChanged: (value) async {
                          final updated = SyllabusSubtopic(
                            id: st.id,
                            topicId: st.topicId,
                            name: st.name,
                            orderIndex: st.orderIndex,
                            status: value == true ? 'completed' : 'notStarted',
                            notes: st.notes,
                            createdAtMillis: st.createdAtMillis,
                          );
                          await DatabaseHelper.instance.updateSyllabusSubtopic(updated);
                          await _loadData();
                        },
                      )),
                  const SizedBox(height: 20),

                  // Resources
                  Text('Resources', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._resources.map((r) => ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(r.title),
                        subtitle: Text(r.resourceType),
                      )),
                  const SizedBox(height: 20),

                  // Revision Schedule
                  Text('Revision Schedule', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._revisions.map((r) => ListTile(
                        leading: r.completed ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.pending),
                        title: Text('Revision ${r.revisionNumber}'),
                        subtitle: Text(DateTime.fromMillisecondsSinceEpoch(r.scheduledDateMillis).toString().substring(0, 10)),
                      )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SyllabusAddEditScreen(
                parentTopicId: widget.topicId,
                level: 'subtopic',
              ),
            ),
          );
          if (result == true) await _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Subtopic'),
      ),
    );
  }
}
