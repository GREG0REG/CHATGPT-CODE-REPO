import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/study_session.dart';

/// Simple study session logger with subject tracking
class StudyLogScreen extends StatefulWidget {
  const StudyLogScreen({super.key});

  @override
  State<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends State<StudyLogScreen> {
  List<StudySession> _sessions = [];
  bool _loading = true;

  // Quick log form
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  int _durationMinutes = 25;
  String _sessionType = 'pomodoro';

  final List<String> _sessionTypes = ['pomodoro', 'deep_work', 'reading', 'review', 'practice'];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await DatabaseHelper.instance.getStudySessions(limit: 50);
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _quickLog() async {
    if (_subjectController.text.trim().isEmpty) {
      _subjectController.text = 'General Study';
    }

    final session = StudySession(
      subjectTag: _subjectController.text.trim(),
      durationMinutes: _durationMinutes,
      completedAtMillis: DateTime.now().millisecondsSinceEpoch,
      sessionType: _sessionType,
    );

    await DatabaseHelper.instance.insertStudySession(session);
    HapticFeedback.mediumImpact();

    // Update subject focus time if exists
    final subjects = await DatabaseHelper.instance.getAllStudySubjects();
    final match = subjects.where((s) => s.name == _subjectController.text.trim()).firstOrNull;
    if (match != null && match.id != null) {
      await DatabaseHelper.instance.addSubjectFocusMinutes(match.id!, _durationMinutes);
    }

    _subjectController.clear();
    _notesController.clear();
    _durationMinutes = 25;
    
    await _loadSessions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Study session logged!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Calculate today's stats
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final todaySessions = _sessions.where((s) => s.completedAtMillis >= todayStart).toList();
    final todayMinutes = todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    return Scaffold(
      appBar: AppBar(title: const Text('Study Log')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Today's stats
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn('Today', '${todayMinutes}m', Icons.today),
                      _statColumn('Sessions', '${todaySessions.length}', Icons.timer),
                      _statColumn('Total', '${_sessions.length}', Icons.history),
                    ],
                  ),
                ),

                // Quick log form
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            hintText: 'e.g., Calculus, Physics',
                            prefixIcon: Icon(Icons.book),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _sessionType,
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: _sessionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                                onChanged: (v) => setState(() => _sessionType = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _durationMinutes,
                                decoration: const InputDecoration(
                                  labelText: 'Duration',
                                  prefixIcon: Icon(Icons.schedule),
                                ),
                                items: [15, 25, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('${m}m'))).toList(),
                                onChanged: (v) => setState(() => _durationMinutes = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text('Recent Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

                // Recent sessions list
                Expanded(
                  child: _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 64, color: cs.outline),
                              const SizedBox(height: 16),
                              Text('No sessions logged yet', style: TextStyle(color: cs.outline)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final s = _sessions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: Icon(
                                    _typeIcon(s.sessionType),
                                    color: cs.onPrimaryContainer,
                                    size: 18,
                                  ),
                                ),
                                title: Text(s.subjectTag ?? 'General Study'),
                                subtitle: Text('${_formatDuration(s.durationMinutes)} • ${_timeAgo(s.completedAtMillis)}'),
                                trailing: Text(
                                  s.sessionType[0].toUpperCase() + s.sessionType.substring(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
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

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
