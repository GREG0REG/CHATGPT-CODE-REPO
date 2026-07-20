// CHATGPT-CODE-REPO-TEST/lib/widgets/exam_countdown_widget.dart
// COMPLETE FILE - Standalone exam countdown banner widget

import 'package:flutter/material.dart';

class ExamCountdownWidget extends StatefulWidget {
  const ExamCountdownWidget({super.key});

  @override
  State<ExamCountdownWidget> createState() => _ExamCountdownWidgetState();
}

class _ExamCountdownWidgetState extends State<ExamCountdownWidget> {
  final List<Map<String, dynamic>> _exams = [
    {'name': 'Finals Week', 'date': DateTime(2026, 12, 15)},
    {'name': 'Midterm Exam', 'date': DateTime(2026, 10, 20)},
  ];

  String _timeRemaining(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.isNegative) return 'Completed!';
    if (diff.inDays > 0) return '${diff.inDays} days';
    if (diff.inHours > 0) return '${diff.inHours} hours';
    return '${diff.inMinutes} min';
  }

  Color _urgencyColor(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.isNegative) return Colors.grey;
    if (diff.inDays > 14) return Colors.green;
    if (diff.inDays > 7) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.2), cs.secondary.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_on, color: cs.primary),
              const SizedBox(width: 8),
              const Text(
                'Upcoming Exams',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ..._exams.map((exam) {
            final name = exam['name'] as String;
            final date = exam['date'] as DateTime;
            final daysLeft = date.difference(DateTime.now()).inDays;
            final color = _urgencyColor(date);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${daysLeft > 0 ? daysLeft : 0}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: color,
                            ),
                          ),
                          Text(
                            'days',
                            style: TextStyle(
                              fontSize: 10,
                              color: color.withOpacity(0.7),
                            ),
                          ),
                        ],
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${date.month}/${date.day}/${date.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.outline,
                          ),
                        ),
                        Text(
                          _timeRemaining(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (daysLeft < 7 && daysLeft >= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          Text(
            'Add exams in Events tab with subject tags',
            style: TextStyle(
              fontSize: 11,
              color: cs.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
