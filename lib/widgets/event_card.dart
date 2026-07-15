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
    }

    // SESSION 2: Urgency color badge
    final urgencyColor = event.getUrgencyColor(now);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        // SESSION 2: Hero animation tag
        leading: Hero(
          tag: 'event_avatar_${event.id}',
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: urgencyColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                Icons.event,
                color: urgencyColor,
                size: 20,
              ),
            ),
          ),
        ),
        title: Hero(
          tag: 'event_title_${event.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitleParts.isNotEmpty)
              Text(subtitleParts.join(' • '), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              result.text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          // SESSION 2: Minimum 48dp touch target
          iconSize: 24,
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
        ),
      ),
    );
  }
}
