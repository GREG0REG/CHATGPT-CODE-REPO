// FILE: lib/WIDGET/gpa_calculator_widget.dart
// COMPLETE REPLACEMENT — copy and paste entire file

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/widget_service.dart';

class GPACalculatorWidget extends StatefulWidget {
  const GPACalculatorWidget({super.key});

  @override
  State<GPACalculatorWidget> createState() => _GPACalculatorWidgetState();
}

class _GPACalculatorWidgetState extends State<GPACalculatorWidget>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _components = [];
  bool _loading = true;

  late final AnimationController _gaugeController;
  late final Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnimation = CurvedAnimation(
      parent: _gaugeController,
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
    _gaugeController.forward(from: 0);
  }

  Future<void> _addComponent(String name, int credits, String grade) async {
    await DatabaseHelper.instance.insertGradeComponent({
      'name': name,
      'credits': credits,
      'grade': grade,
    });
    HapticFeedback.lightImpact();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  Future<void> _removeComponent(int id) async {
    await DatabaseHelper.instance.deleteGradeComponent(id);
    HapticFeedback.mediumImpact();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  Future<void> _updateComponent(int id, String name, int credits, String grade) async {
    await DatabaseHelper.instance.updateGradeComponent(id, {
      'name': name,
      'credits': credits,
      'grade': grade,
    });
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  double _gradeToPoints(String grade) {
    switch (grade) {
      case 'A+': return 4.0;
      case 'A': return 4.0;
      case 'A-': return 3.7;
      case 'B+': return 3.3;
      case 'B': return 3.0;
      case 'B-': return 2.7;
      case 'C+': return 2.3;
      case 'C': return 2.0;
      case 'C-': return 1.7;
      case 'D+': return 1.3;
      case 'D': return 1.0;
      case 'F': return 0.0;
      default: return 0.0;
    }
  }

  double get _gpa {
    double totalPoints = 0;
    int totalCredits = 0;
    for (final c in _components) {
      final credits = (c['credits'] as num?)?.toInt() ?? 3;
      final grade = c['grade'] as String? ?? 'B';
      totalPoints += _gradeToPoints(grade) * credits;
      totalCredits += credits;
    }
    if (totalCredits == 0) return 0.0;
    return totalPoints / totalCredits;
  }

  int get _totalCredits {
    return _components.fold<int>(0, (sum, c) => sum + ((c['credits'] as num?)?.toInt() ?? 3));
  }

  Color _gradeColor(double gpa) {
    if (gpa >= 3.7) return const Color(0xFF4CAF50);
    if (gpa >= 3.3) return const Color(0xFF8BC34A);
    if (gpa >= 2.7) return const Color(0xFFFFC107);
    if (gpa >= 2.0) return const Color(0xFFFF9800);
    if (gpa >= 1.0) return const Color(0xFFFF5722);
    return const Color(0xFFF44336);
  }

  String get _honorStatus {
    final g = _gpa;
    if (g >= 3.8) return "Summa Cum Laude";
    if (g >= 3.6) return "Magna Cum Laude";
    if (g >= 3.4) return "Cum Laude";
    if (g >= 3.0) return "Dean's List";
    if (g >= 2.0) return "Good Standing";
    return "At Risk";
  }

  Color get _honorColor {
    final g = _gpa;
    if (g >= 3.4) return const Color(0xFF4CAF50);
    if (g >= 3.0) return const Color(0xFF8BC34A);
    if (g >= 2.0) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  void _showAddCourseSheet() {
    final nameController = TextEditingController();
    int selectedCredits = 3;
    String selectedGrade = 'B';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Add Course',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Course Name',
                      hintText: 'e.g. Calculus II',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credits',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx).colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [1, 2, 3, 4, 5].map((c) {
                                final isSelected = selectedCredits == c;
                                return ChoiceChip(
                                  label: Text('$c'),
                                  selected: isSelected,
                                  onSelected: (_) => setSheetState(() => selectedCredits = c),
                                  selectedColor: Theme.of(ctx).colorScheme.primaryContainer,
                                  backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(ctx).colorScheme.onPrimaryContainer
                                        : Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  ),
                                );
                              }).toList(),
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
                              'Grade',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx).colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedGrade,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              items: ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'F']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) => setSheetState(() => selectedGrade = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        _addComponent(name, selectedCredits, selectedGrade);
                      },
                      child: const Text('Add Course'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCourseSheet(Map<String, dynamic> component) {
    final nameController = TextEditingController(text: component['name'] as String? ?? '');
    int selectedCredits = (component['credits'] as num?)?.toInt() ?? 3;
    String selectedGrade = component['grade'] as String? ?? 'B';
    final id = component['id'] as int;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Edit Course',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Course Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credits',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx).colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [1, 2, 3, 4, 5].map((c) {
                                final isSelected = selectedCredits == c;
                                return ChoiceChip(
                                  label: Text('$c'),
                                  selected: isSelected,
                                  onSelected: (_) => setSheetState(() => selectedCredits = c),
                                  selectedColor: Theme.of(ctx).colorScheme.primaryContainer,
                                  backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(ctx).colorScheme.onPrimaryContainer
                                        : Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  ),
                                );
                              }).toList(),
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
                              'Grade',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx).colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedGrade,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              items: ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'F']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) => setSheetState(() => selectedGrade = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        _updateComponent(id, name, selectedCredits, selectedGrade);
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gpa = _gpa;
    final gpaColor = _gradeColor(gpa);
    final honorStatus = _honorStatus;
    final honorColor = _honorColor;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.school, color: cs.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'GPA Calculator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (_components.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showAddCourseSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_components.isEmpty)
              _buildEmptyState(cs)
            else ...[
              // GPA Gauge
              Center(
                child: AnimatedBuilder(
                  animation: _gaugeAnimation,
                  builder: (context, child) {
                    final animatedGpa = gpa * _gaugeAnimation.value;
                    return SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background ring
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 12,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                            ),
                          ),
                          // Animated gauge
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: (gpa / 4.0).clamp(0.0, 1.0)),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 12,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation(gpaColor),
                                  strokeCap: StrokeCap.round,
                                );
                              },
                            ),
                          ),
                          // Center content
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                animatedGpa.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: gpaColor,
                                ),
                              ),
                              Text(
                                '/ 4.0',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.outline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Honor Status Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: honorColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: honorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        gpa >= 3.0 ? Icons.emoji_events : Icons.warning_amber,
                        color: honorColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        honorStatus,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: honorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Summary stats
              Center(
                child: Text(
                  '$_totalCredits credits • ${_components.length} courses',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.outline,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Course List
              ..._components.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                final name = c['name'] as String? ?? 'Course ${i + 1}';
                final credits = (c['credits'] as num?)?.toInt() ?? 3;
                final grade = c['grade'] as String? ?? 'B';
                final points = _gradeToPoints(grade);
                final id = c['id'] as int;
                final gradeColor = _gradeColor(points);

                return Dismissible(
                  key: ValueKey('gpa_course_$id'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 8),
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
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    child: InkWell(
                      onTap: () => _showEditCourseSheet(c),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          // Grade circle
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: gradeColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                grade,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: gradeColor,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$credits credits • ${points.toStringAsFixed(1)} pts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Contribution bar
                          SizedBox(
                            width: 60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(points * credits).toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: gradeColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (points / 4.0).clamp(0.0, 1.0),
                                    minHeight: 4,
                                    backgroundColor: cs.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(gradeColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              // Add button at bottom
              Center(
                child: FilledButton.icon(
                  onPressed: _showAddCourseSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Course'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_outlined, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'No courses yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your courses to calculate GPA',
              style: TextStyle(
                fontSize: 13,
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showAddCourseSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add First Course'),
            ),
          ],
        ),
      ),
    );
  }
}
