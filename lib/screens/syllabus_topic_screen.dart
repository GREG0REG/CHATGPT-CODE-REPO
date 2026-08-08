import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subtopic.dart';
import '../models/syllabus_resource.dart';
import '../models/syllabus_revision_schedule.dart';
import '../models/study_session.dart'; // Needed to display Study Sessions
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
  List<Map<String, dynamic>> _studySessions = [];
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
    
    // Load study sessions linked to this topic
    final links = await db.getSyllabusStudyLinksForTopic(widget.topicId);
    final sessions = <Map<String, dynamic>>[];
    for (final link in links) {
      final session = await db.getStudySession(link.studySessionId);
      if (session != null) {
        sessions.add({
          'session': session,
          'date': DateTime.fromMillisecondsSinceEpoch(session.completedAtMillis),
        });
      }
    }
    // Sort by date descending
    sessions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    setState(() {
      _topic = topic;
      _subtopics = subtopics;
      _resources = resources;
      _revisions = revisions;
      _studySessions = sessions;
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
        builder: (_) => const SyllabusAddEditScreen(
          level: 'subtopic',
        ),
      ),
    );
    if (result == true) await _loadData();
  }

  // FIX: Wrapped in try-catch and properly triggers setState
  Future<void> _toggleSubtopic(SyllabusSubtopic subtopic) async {
    final newStatus = subtopic.status == 'completed' ? 'notStarted' : 'completed';
    final updated = subtopic.copyWith(status: newStatus);
    try {
      await DatabaseHelper.instance.updateSyllabusSubtopic(updated);
      await _loadData(); // This will setState and update the UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating subtopic: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_topic?.name ?? 'Topic')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Buttons (Design: Orange/Green/Gray)
                  Row(
                    children: [
                      _buildStatusButton('In Progress', TopicStatus.inProgress, Colors.orange, cs),
                      const SizedBox(width: 12),
                      _buildStatusButton('Completed', TopicStatus.completed, Colors.green, cs),
                      const SizedBox(width: 12),
                      _buildStatusButton('Revision', TopicStatus.needsRevision, Colors.grey, cs),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Subtopics Section
                  const Text('Subtopics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 8),
                  ..._subtopics.map((st) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2429), // Dark card
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.green,
                      checkColor: Colors.white,
                      title: Text(st.name, style: const TextStyle(color: Colors.white)),
                      // Mocking difficulty display based on status for design purposes
                      secondary: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: st.status == 'completed' ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          st.status == 'completed' ? 'Done' : 'Pending',
                          style: TextStyle(
                            color: st.status == 'completed' ? Colors.green : Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      value: st.status == 'completed',
                      onChanged: (_) => _toggleSubtopic(st),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  )),
                  const SizedBox(height: 24),

                  // Resources Section
                  const Text('Resources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._resources.map((r) => Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2429),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(r.resourceType == 'file' ? Icons.insert_drive_file : Icons.link, color: Colors.white, size: 28),
                              const SizedBox(height: 4),
                              Text(r.title, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        )),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2429),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.5), style: BorderStyle.solid, width: 1.5),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('+', style: TextStyle(color: Colors.grey, fontSize: 20)),
                              Text('Add', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Revision Schedule Section (Design: 1d, 3d, 7d, 14d, 30d)
                  const Text('Revision Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _revisions.map((r) {
                      final isCompleted = r.isCompleted == 1;
                      final isPending = !isCompleted && _revisions.indexOf(r) == 0; // Mocking first pending as current
                      Color borderColor = isCompleted ? Colors.green : (isPending ? Colors.orange : Colors.grey);
                      Color bgColor = isCompleted ? Colors.green.withOpacity(0.2) : (isPending ? Colors.orange.withOpacity(0.2) : const Color(0xFF1E2429));

                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isCompleted ? Icons.check : (isPending ? Icons.hourglass_top : Icons.lock_outline),
                              size: 16,
                              color: borderColor,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.revisionNumber}d',
                              style: TextStyle(color: isCompleted ? Colors.green : (isPending ? Colors.orange : Colors.grey), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Study Sessions Section (NEW)
                  const Text('Study Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 8),
                  if (_studySessions.isEmpty)
                    const Text('No study sessions yet. Start studying!', style: TextStyle(color: Colors.grey))
                  else
                    ..._studySessions.map((s) {
                      final session = s['session'] as StudySession;
                      final date = s['date'] as DateTime;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              '${session.durationMinutes} min — ${date.day}/${date.month} — ${session.sessionType ?? 'Pomodoro'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubtopic,
        icon: const Icon(Icons.add),
        label: const Text('Add Subtopic'),
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildStatusButton(String label, TopicStatus status, Color color, ColorScheme cs) {
    final isSelected = _topic?.statusEnum == status;
    return Expanded(
      child: InkWell(
        onTap: () => _updateTopicStatus(status),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFF1E2429),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
