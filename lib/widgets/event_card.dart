import 'package:flutter/material.dart';

import '../models/event.dart';
import '../services/countdown_service.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final bool smartFormatEnabled;
import 'package:flutter/material.dart';

import '../models/event.dart';
import '../services/countdown_service.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final bool smartFormatEnabled;
  final bool use24HourFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const EventCard({
    super.key,
    required this.event,
    required this.smartFormatEnabled,
    required this.use24HourFormat,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final datePart = '${dt.month}/${dt.day}/${dt.year}';
    final hour = use24HourFormat
        ? dt.hour.toString().padLeft(2, '0')
        : (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = use24HourFormat ? '' : (dt.hour >= 12 ? ' PM' : ' AM');
    return '$datePart, $hour:$minute$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final result = CountdownService.buildCountdownText(
      event,
      now,
      smartFormatEnabled: smartFormatEnabled,
    );

    final subtitleParts = <String>[];
    if (event.startTimeMillis != null) {
      subtitleParts.add('Starts: ${_formatDateTime(event.startTimeMillis!)}');
    }
    if (event.deadlineMillis != null) {
      subtitleParts.add('Deadline: ${_formatDateTime(event.deadlineMillis!)}');
event_card.dart
t).colorScheme.error,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
