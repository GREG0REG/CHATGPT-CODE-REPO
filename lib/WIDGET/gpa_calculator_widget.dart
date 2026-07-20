// CHATGPT-CODE-REPO-TEST/lib/widgets/gpa_calculator_widget.dart
// COMPLETE FILE - Standalone GPA calculator widget

import 'package:flutter/material.dart';

class GPACalculatorWidget extends StatefulWidget {
  const GPACalculatorWidget({super.key});

  @override
  State<GPACalculatorWidget> createState() => _GPACalculatorWidgetState();
}

class _GPACalculatorWidgetState extends State<GPACalculatorWidget> {
  final List<_CourseGrade> _courses = [];

  @override
  void initState() {
    super.initState();
    _addCourse(); // Start with one empty course
  }

  void _addCourse() {
    setState(() {
      _courses.add(_CourseGrade(
        name: 'Course ${_courses.length + 1}',
        credits: 3,
        grade: 'B',
      ));
    });
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
    double totalCredits = 0;
    for (final c in _courses) {
      totalPoints += _gradeToPoints(c.grade) * c.credits;
      totalCredits += c.credits;
    }
    if (totalCredits == 0) return 0.0;
    return totalPoints / totalCredits;
  }

  Color get _gpaColor {
    final g = _gpa;
    if (g >= 3.5) return Colors.green;
    if (g >= 2.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'GPA Calculator',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // GPA Display
            if (_courses.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _gpaColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gpaColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('GPA: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _gpa.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _gpaColor,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Course list
            ..._courses.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Course name',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        controller: TextEditingController(text: c.name),
                        onChanged: (v) => setState(() => _courses[i] = _courses[i].copyWith(name: v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: DropdownButtonFormField<int>(
                        value: c.credits,
                        isDense: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        items: [1, 2, 3, 4, 5].map((credits) => 
                          DropdownMenuItem(value: credits, child: Text('$credits'))
                        ).toList(),
                        onChanged: (v) => setState(() => _courses[i] = _courses[i].copyWith(credits: v!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: DropdownButtonFormField<String>(
                        value: c.grade,
                        isDense: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        items: ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'F']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _courses[i] = _courses[i].copyWith(grade: v!)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => setState(() => _courses.removeAt(i)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: _addCourse,
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseGrade {
  String name;
  int credits;
  String grade;

  _CourseGrade({
    required this.name,
    this.credits = 3,
    this.grade = 'B',
  });

  _CourseGrade copyWith({
    String? name,
    int? credits,
    String? grade,
  }) {
    return _CourseGrade(
      name: name ?? this.name,
      credits: credits ?? this.credits,
      grade: grade ?? this.grade,
    );
  }
}
