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
    final updated = _topic!.copyWith(status: newStatus.name);
    await DatabaseHelper.instance.updateSyllabusTopic(updated);
    if (newStatus == TopicStatus.completed) {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_topic?.name ?? 'Topic')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text('Subtopics', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._subtopics.map((st) => CheckboxListTile(
                        title: Text(st.name),
                        value: st.status == 'completed',
                        onChanged: (_) => _toggleSubtopic(st),
                        controlAffinity: ListTileControlAffinity.leading,
                      )),
                  const SizedBox(height: 20),
                  const Text('Resources', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._resources.map((r) => ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(r.title),
                        subtitle: Text(r.resourceType),
                      )),
                  const SizedBox(height: 20),
                  const Text('Revision Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._revisions.map((r) => ListTile(
                        leading: r.completed
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.pending),
                        title: Text('Revision ${r.revisionNumber}'),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(r.scheduledDateMillis)
                              .toLocal()
                              .toString()
                              .substring(0, 10),
                        ),
                      )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubtopic,
        icon: const Icon(Icons.add),
        label: const Text('Add Subtopic'),
      ),
    );
  }
}
