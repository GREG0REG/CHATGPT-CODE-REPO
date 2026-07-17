import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/event.dart';
import '../services/countdown_service.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final bool smartFormatEnabled;
  final bool use24HourFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final List<Event>? childOccurrences;
  final VoidCallback? onExpandToggle;
  final bool isExpanded;

  const EventCard({
    super.key,
    required this.event,
    required this.smartFormatEnabled,
    required this.use24HourFormat,
    required this.onTap,
    required this.onDelete,
    this.childOccurrences,
    this.onExpandToggle,
    this.isExpanded = false,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final datePart = '${dt.month}/${dt.day}/${dt.year}';
    final hour = widget.use24HourFormat
        ? dt.hour.toString().padLeft(2, '0')
        : (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = widget.use24HourFormat ? '' : (dt.hour >= 12 ? ' PM' : ' AM');
    return '$datePart, $hour:$minute$suffix';
  }

  String _formatDateOnly(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Future<void> _shareEvent(BuildContext context) async {
    final now = DateTime.now();
    final result = CountdownService.buildCountdownText(
      widget.event, now, smartFormatEnabled: widget.smartFormatEnabled,
    );
    await Share.share('${widget.event.title}\n${result.text}', subject: widget.event.title);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final result = CountdownService.buildCountdownText(
      widget.event, now, smartFormatEnabled: widget.smartFormatEnabled,
    );

    final subtitleParts = <String>[];
    // FIX: Always show date for ALL events
    if (widget.event.startTimeMillis != null) {
      subtitleParts.add('Starts: ${_formatDateTime(widget.event.startTimeMillis!)}');
    } else {
      subtitleParts.add('Date: ${_formatDateOnly(widget.event.dateMillis)}');
    }
    if (widget.event.deadlineMillis != null) {
      subtitleParts.add('Deadline: ${_formatDateTime(widget.event.deadlineMillis!)}');
    }

    final urgencyColor = widget.event.getUrgencyColor(now);
    final isRecurringParent = widget.event.isRecurring && widget.event.id != null && widget.event.id! > 0;
    final hasChildren = widget.childOccurrences != null && widget.childOccurrences!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'event_avatar_${widget.event.id}',
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
                            Icon(Icons.event, color: urgencyColor, size: 22),
                            if (widget.event.isRecurring)
                              const Positioned(
                                bottom: 0, right: 0,
                                child: Icon(Icons.sync, size: 14, color: Colors.blue),
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
                          tag: 'event_title_${widget.event.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              widget.event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitleParts.join(' • '),
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          result.text,
                          style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Expand button for recurring events
                  if (isRecurringParent && hasChildren)
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: widget.onExpandToggle,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 40, height: 48, alignment: Alignment.center,
                          child: AnimatedRotation(
                            turns: widget.isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.expand_more,
                              color: Theme.of(context).colorScheme.primary, size: 24),
                          ),
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => _shareEvent(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 40, height: 48, alignment: Alignment.center,
                        child: Icon(Icons.share,
                          color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 40, height: 48, alignment: Alignment.center,
                        child: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expanded child occurrences
        if (widget.isExpanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 12, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.childOccurrences!.map((child) {
                  final childResult = CountdownService.buildCountdownText(
                    child, now, smartFormatEnabled: widget.smartFormatEnabled,
                  );
                  final childDate = _formatDateOnly(child.dateMillis);
                  final childSubtitle = <String>[];
                  if (child.startTimeMillis != null) {
                    childSubtitle.add('Starts: ${_formatDateTime(child.startTimeMillis!)}');
                  } else {
                    childSubtitle.add('Date: $childDate');
                  }
                  if (child.deadlineMillis != null) {
                    childSubtitle.add('Deadline: ${_formatDateTime(child.deadlineMillis!)}');
                  }

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: child.getUrgencyColor(now), shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(childDate,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: childSubtitle.isNotEmpty
                        ? Text(childSubtitle.join(' • '),
                            style: TextStyle(fontSize: 11,
                              color: Theme.of(context).colorScheme.outline))
                        : null,
                    trailing: Text(
                      childResult.text,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
