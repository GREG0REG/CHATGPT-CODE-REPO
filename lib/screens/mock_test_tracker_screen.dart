import 'package:flutter/material.dart';
import '../database_helper.dart';

class MockTestTrackerScreen extends StatefulWidget {
  const MockTestTrackerScreen({super.key});

  @override
  State<MockTestTrackerScreen> createState() => _MockTestTrackerScreenState();
}

class _MockTestTrackerScreenState extends State<MockTestTrackerScreen> {
  List<Map<String, dynamic>> _tests = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final tests = await db.getAllMockTestHistory();
    final stats = await db.getMockTestStats();
    setState(() {
      _tests = tests;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _addMockTest() async {
    final nameController = TextEditingController();
    final scoreController = TextEditingController();
    final totalController = TextEditingController(text: '720');
    final rankController = TextEditingController();
    final studentsController = TextEditingController();
    final notesController = TextEditingController();
    int? selectedSubjectId;

    final subjects = await DatabaseHelper.instance.getAllSyllabusSubjects();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('add mock test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'test name',
                  hintText: 'e.g. Allen Major Test 1',
                  prefixIcon: Icon(Icons.assignment),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: selectedSubjectId,
                decoration: const InputDecoration(
                  labelText: 'subject (optional)',
                  prefixIcon: Icon(Icons.book),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('full syllabus')),
                  ...subjects.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  )),
                ],
                onChanged: (v) => selectedSubjectId = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: scoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'score',
                        prefixIcon: Icon(Icons.scoreboard),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: totalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'total',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'rank',
                        prefixIcon: Icon(Icons.emoji_events),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: studentsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'total students',
                        prefixIcon: Icon(Icons.people),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'notes',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('cancel')),
          FilledButton(
            onPressed: () {
              final score = int.tryParse(scoreController.text);
              final total = int.tryParse(totalController.text);
              if (score == null || total == null || nameController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx, {
                'subjectId': selectedSubjectId,
                'testName': nameController.text.trim(),
                'score': score,
                'totalMarks': total,
                'rank': int.tryParse(rankController.text),
                'totalStudents': int.tryParse(studentsController.text),
                'dateMillis': DateTime.now().millisecondsSinceEpoch,
                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
              });
            },
            child: const Text('save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    scoreController.dispose();
    totalController.dispose();
    rankController.dispose();
    studentsController.dispose();
    notesController.dispose();

    if (result != null) {
      await DatabaseHelper.instance.insertMockTestHistory(result);
      await _loadData();
    }
  }

  Future<void> _deleteTest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('delete test?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteMockTestHistory(id);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('mock test tracker'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tests.isEmpty
              ? _buildEmptyState(cs)
              : _buildTestList(cs),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMockTest,
        icon: const Icon(Icons.add),
        label: const Text('add test'),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 80, color: cs.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('no mock tests yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('track your mock test scores here', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTestList(ColorScheme cs) {
    final avgPercentage = _stats?['avgPercentage'] ?? 0.0;
    final bestScore = _stats?['bestScore'] ?? 0;
    final totalTests = _stats?['totalTests'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard('tests', totalTests.toString(), Icons.assignment, cs.primary, cs),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard('avg %', '${avgPercentage.round()}%', Icons.trending_up, Colors.teal, cs),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard('best', bestScore.toString(), Icons.emoji_events, Colors.amber, cs),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Progress chart
        if (_tests.length >= 2)
          _buildProgressChart(cs),
        const SizedBox(height: 20),
        const Text('test history', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._tests.map((test) {
          final score = test['score'] as int;
          final total = test['totalMarks'] as int;
          final percentage = (score / total * 100).round();
          final date = DateTime.fromMillisecondsSinceEpoch(test['dateMillis'] as int);
          final rank = test['rank'] as int?;
          final totalStudents = test['totalStudents'] as int?;

          Color percentageColor;
          if (percentage >= 70) percentageColor = Colors.green;
          else if (percentage >= 50) percentageColor = Colors.orange;
          else percentageColor = Colors.red;

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
                      Expanded(
                        child: Text(
                          test['testName'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: percentageColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$percentage%',
                          style: TextStyle(
                            color: percentageColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$score / $total marks · ${date.day}/${date.month}/${date.year}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  if (rank != null && totalStudents != null)
                    Text(
                      'rank: $rank / $totalStudents students',
                      style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  if (test['notes'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        test['notes'] as String,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteTest(test['id'] as int),
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, ColorScheme cs) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart(ColorScheme cs) {
    final sortedTests = List<Map<String, dynamic>>.from(_tests)
      ..sort((a, b) => (a['dateMillis'] as int).compareTo(b['dateMillis'] as int));

    final maxScore = sortedTests.map((t) => t['totalMarks'] as int).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('score trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: sortedTests.map((test) {
                  final score = test['score'] as int;
                  final total = test['totalMarks'] as int;
                  final percentage = score / total;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(percentage * 100).round()}%',
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * percentage,
                            decoration: BoxDecoration(
                              color: percentage >= 0.7
                                  ? Colors.green
                                  : percentage >= 0.5
                                      ? Colors.orange
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
