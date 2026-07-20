import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GradeCalculatorScreen extends StatefulWidget {
  const GradeCalculatorScreen({super.key});

  @override
  State<GradeCalculatorScreen> createState() => _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends State<GradeCalculatorScreen> {
  final List<GradeComponent> _components = [];
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _scoreController = TextEditingController();
  final _totalController = TextEditingController();

  void _addComponent() {
    final name = _nameController.text.trim();
    final weight = double.tryParse(_weightController.text) ?? 0;
    final score = double.tryParse(_scoreController.text) ?? 0;
    final total = double.tryParse(_totalController.text) ?? 100;

    if (name.isEmpty || weight <= 0 || score < 0 || total <= 0) return;

    setState(() {
      _components.add(GradeComponent(
        name: name,
        weight: weight,
        score: score,
        totalPoints: total,
      ));
    });

    HapticFeedback.lightImpact();
    _nameController.clear();
    _weightController.clear();
    _scoreController.clear();
    _totalController.text = '100';
  }

  void _removeComponent(int index) {
    setState(() => _components.removeAt(index));
  }

  double get _currentGrade {
    double weightedScore = 0;
    double totalWeight = 0;
    for (final c in _components) {
      weightedScore += (c.score / c.totalPoints) * c.weight;
      totalWeight += c.weight;
    }
    if (totalWeight == 0) return 0;
    return (weightedScore / totalWeight) * 100;
  }

  double get _totalWeightUsed {
    return _components.fold(0.0, (sum, c) => sum + c.weight);
  }

  String get _letterGrade {
    final g = _currentGrade;
    if (g >= 97) return 'A+';
    if (g >= 93) return 'A';
    if (g >= 90) return 'A-';
    if (g >= 87) return 'B+';
    if (g >= 83) return 'B';
    if (g >= 80) return 'B-';
    if (g >= 77) return 'C+';
    if (g >= 73) return 'C';
    if (g >= 70) return 'C-';
    if (g >= 67) return 'D+';
    if (g >= 63) return 'D';
    if (g >= 60) return 'D-';
    return 'F';
  }

  Color get _gradeColor {
    final g = _currentGrade;
    if (g >= 90) return Colors.green;
    if (g >= 80) return Colors.lightGreen;
    if (g >= 70) return Colors.orange;
    if (g >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Grade Calculator')),
      body: Column(
        children: [
          // Grade display card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_gradeColor.withOpacity(0.8), _gradeColor.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '${_currentGrade.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _letterGrade,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total weight used: ${_totalWeightUsed.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_totalWeightUsed < 100)
                  Text(
                    'Remaining: ${(100 - _totalWeightUsed).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),

          // Input section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Component name (e.g. Midterm)',
                    prefixIcon: Icon(Icons.assignment),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weight %',
                          prefixIcon: Icon(Icons.balance),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _scoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Your score',
                          prefixIcon: Icon(Icons.check_circle),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Out of',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addComponent,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Component'),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // Components list
          Expanded(
            child: _components.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate_outlined, size: 64, color: cs.outline),
                        const SizedBox(height: 16),
                        Text(
                          'Add grade components\nto calculate your grade',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.outline),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _components.length,
                    itemBuilder: (context, index) {
                      final c = _components[index];
                      final percent = (c.score / c.totalPoints) * 100;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: percent >= 90 ? Colors.green : percent >= 70 ? Colors.orange : Colors.red,
                            child: Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                          title: Text(c.name),
                          subtitle: Text('${c.score}/${c.totalPoints} • Weight: ${c.weight}%'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeComponent(index),
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

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _scoreController.dispose();
    _totalController.dispose();
    super.dispose();
  }
}

class GradeComponent {
  final String name;
  final double weight;
  final double score;
  final double totalPoints;

  GradeComponent({
    required this.name,
    required this.weight,
    required this.score,
    required this.totalPoints,
  });
}
