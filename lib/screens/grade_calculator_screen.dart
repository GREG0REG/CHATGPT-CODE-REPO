// FILE: lib/screens/grade_calculator_screen.dart
// COMPLETE REPLACEMENT — FIXED: _gradeColor expects double, cast percent to double

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import 'package:event_countdown/services/widget_service.dart';

class GradeCalculatorScreen extends StatefulWidget {
  const GradeCalculatorScreen({super.key});

  @override
  State<GradeCalculatorScreen> createState() => _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends State<GradeCalculatorScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _components = [];
  bool _loading = true;

  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _scoreController = TextEditingController();
  final _totalController = TextEditingController(text: '100');
  final _targetGradeController = TextEditingController();

  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    setState(() => _loading = true);
    final components = await DatabaseHelper.instance.getAllGradeComponents();
    setState(() {
      _components = components;
      _loading = false;
    });
    _ringController.forward(from: 0);
  }

  Future<void> _addComponent() async {
    final name = _nameController.text.trim();
    final weight = double.tryParse(_weightController.text) ?? 0;
    final score = double.tryParse(_scoreController.text) ?? 0;
    final total = double.tryParse(_totalController.text) ?? 100;

    if (name.isEmpty || weight <= 0 || score < 0 || total <= 0) return;

    await DatabaseHelper.instance.insertGradeComponent({
      'name': name,
      'weight': weight,
      'score': score,
      'totalPoints': total,
    });

    HapticFeedback.lightImpact();
    _nameController.clear();
    _weightController.clear();
    _scoreController.clear();
    _totalController.text = '100';

    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  Future<void> _removeComponent(int id) async {
    await DatabaseHelper.instance.deleteGradeComponent(id);
    HapticFeedback.mediumImpact();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  double get _currentGrade {
    double weightedScore = 0;
    double totalWeight = 0;
    for (final c in _components) {
      weightedScore += ((c['score'] as num) / (c['totalPoints'] as num)) * (c['weight'] as num);
      totalWeight += (c['weight'] as num);
    }
    if (totalWeight == 0) return 0;
    return (weightedScore / totalWeight) * 100;
  }

  double get _totalWeightUsed {
    return _components.fold(0.0, (sum, c) => sum + (c['weight'] as num));
  }

  double get _remainingWeight {
    return (100.0 - _totalWeightUsed).clamp(0.0, 100.0);
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

  Color _gradeColor(double grade) {
    if (grade >= 90) return const Color(0xFF4CAF50);
    if (grade >= 80) return const Color(0xFF8BC34A);
    if (grade >= 70) return const Color(0xFFFFC107);
    if (grade >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String? _getPrediction() {
    final targetText = _targetGradeController.text.trim();
    if (targetText.isEmpty) return null;
    final target = double.tryParse(targetText);
    if (target == null) return null;
    final remaining = _remainingWeight;
    if (remaining <= 0) return null;

    final current = _currentGrade;
    final totalWeight = _totalWeightUsed;
    final needed = ((target * 100) - (current * totalWeight)) / remaining;
    if (needed > 100) return 'Impossible — max is 100%';
    if (needed < 0) return 'Already achieved!';
    return 'Need ${needed.toStringAsFixed(1)}% on remaining $remaining%';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grade = _currentGrade;
    final gradeColor = _gradeColor(grade);
    final totalWeight = _totalWeightUsed;
    final isOverWeight = totalWeight > 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Calculator'),
        actions: [
          if (_components.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Clear all?'),
                    content: const Text('Delete all grade components?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await DatabaseHelper.instance.clearGradeComponents();
                  await _loadComponents();
                  await WidgetService.refreshWidget();
                }
              },
              child: Text('Clear', style: TextStyle(color: cs.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Grade Ring
                      Center(
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 16,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                                ),
                              ),
                              // Animated ring
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: (grade / 100).clamp(0.0, 1.0)),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return SizedBox(
                                    width: 220,
                                    height: 220,
                                    child: CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 16,
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation(gradeColor),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  );
                                },
                              ),
                              // Center
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _ringAnimation,
                                    builder: (context, child) {
                                      return Text(
                                        '${(grade * _ringAnimation.value).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.bold,
                                          color: gradeColor,
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: gradeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _letterGrade,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: gradeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weight Budget Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Weight Budget',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  '${totalWeight.toStringAsFixed(1)}% / 100%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isOverWeight ? cs.error : cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (totalWeight / 100).clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: cs.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  isOverWeight ? cs.error : cs.primary,
                                ),
                              ),
                            ),
                            if (isOverWeight)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber, size: 14, color: cs.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Total weight exceeds 100%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_remainingWeight > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${_remainingWeight.toStringAsFixed(1)}% remaining',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Target Grade Prediction
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.primary.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grade Predictor',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _targetGradeController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Target %',
                                        hintText: 'e.g. 85',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getPrediction() ?? 'Enter target',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _getPrediction() != null ? cs.primary : cs.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Add Component Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Component',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Component name',
                                  hintText: 'e.g. Midterm',
                                  prefixIcon: const Icon(Icons.assignment_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _weightController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Weight %',
                                        prefixIcon: const Icon(Icons.balance),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _scoreController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Your score',
                                        prefixIcon: const Icon(Icons.check_circle_outline),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _totalController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Out of',
                                        prefixIcon: const Icon(Icons.format_list_numbered),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
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
                      ),
                      const SizedBox(height: 24),

                      // Components List Header
                      if (_components.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Text(
                                'Components',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_components.length} items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Components List
                if (_components.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(cs),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final c = _components[index];
                          final name = c['name'] as String? ?? 'Component';
                          final weight = (c['weight'] as num?)?.toDouble() ?? 0;
                          final score = (c['score'] as num?)?.toDouble() ?? 0;
                          final total = (c['totalPoints'] as num?)?.toDouble() ?? 100;
                          final percent = total > 0 ? ((score / total) * 100).toDouble() : 0.0;
                          final contribution = (percent / 100) * weight;
                          final id = c['id'] as int;
                          final compColor = _gradeColor(percent);

                          return Dismissible(
                            key: ValueKey('grade_comp_$id'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                            ),
                            onDismissed: (_) => _removeComponent(id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: compColor.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${percent.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: compColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${score.toStringAsFixed(1)}/$total • Weight: ${weight.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: compColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '+${contribution.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: compColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Score bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (percent / 100).clamp(0.0, 1.0),
                                      minHeight: 8,
                                      backgroundColor: cs.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation(compColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _components.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calculate_outlined, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'No components yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add grade components to calculate your grade',
              style: TextStyle(
                fontSize: 13,
                color: cs.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _scoreController.dispose();
    _totalController.dispose();
    _targetGradeController.dispose();
    _ringController.dispose();
    super.dispose();
  }
}
