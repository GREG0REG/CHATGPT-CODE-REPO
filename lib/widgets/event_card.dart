import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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

  // ============================================
  // SESSION 6: Share specific event
  // ============================================
  Future<void> _shareEvent(BuildContext context) async {
    final now = DateTime.now();
    final result = CountdownService.buildCountdownText(
      event,
      now,
      smartFormatEnabled: smartFormatEnabled,
    );
    final text = '${event.title}\n${result.text}';
    await Share.share(text, subject: event.title);
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

    final urgencyColor = event.getUrgencyColor(now);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(
                tag: 'event_avatar_${event.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.event,
                          color: urgencyColor,
                          size: 22,
                        ),
                        // ============================================
                        // SESSION 5: Recurring icon
                        // ============================================
                        if (event.isRecurring)
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: Icon(
                              Icons.sync,
                              size: 14,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'event_title_${event.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      result.text,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // SESSION 6: Share button
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => _shareEvent(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 40,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.share,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 40,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
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
