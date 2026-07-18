import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'models/event.dart';
import 'services/countdown_service.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final bool smartFormatEnabled;
  final bool use24HourFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onComplete;
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
    this.onComplete,
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
    final isCompleted = widget.event.isCompleted;

    final isPastParent = widget.event.isRecurring &&
        !isCompleted &&
        widget.childOccurrences != null &&
        widget.childOccurrences!.isNotEmpty &&
        widget.event.finalMillis <= now.millisecondsSinceEpoch;

    final displayEvent = isPastParent ? widget.childOccurrences!.first : widget.event;

    final result = CountdownService.buildCountdownText(
      displayEvent, now, smartFormatEnabled: widget.smartFormatEnabled,
    );

    final subtitleParts = <String>[];
    if (widget.event.startTimeMillis != null) {
      subtitleParts.add('Starts: ${_formatDateTime(widget.event.startTimeMillis!)}');
    } else {
      subtitleParts.add('Date: ${_formatDateOnly(widget.event.dateMillis)}');
    }
    if (widget.event.deadlineMillis != null) {
      subtitleParts.add('Deadline: ${_formatDateTime(widget.event.deadlineMillis!)}');
    }

    final urgencyColor = isCompleted ? Colors.grey : displayEvent.getUrgencyColor(now);
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
                  SizedBox(
                    width: 32,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCompleted ? Colors.green : Theme.of(context).colorScheme.outline,
                        size: 22,
                      ),
                      onPressed: widget.onComplete != null
                          ? () => widget.onComplete!(!isCompleted)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Hero(
                    tag: 'event_avatar_${widget.event.id}',
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: urgencyColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              isCompleted ? Icons.check : widget.event.iconData,
                              color: urgencyColor,
                              size: 22,
                            ),
                          ),
                        ),
                        if (!isCompleted && widget.event.priority > 0)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: widget.event.priorityColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isCompleted ? Colors.grey : null,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (widget.event.subjectTag != null && widget.event.subjectTag!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.event.subjectTag!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitleParts.join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: isCompleted
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          isCompleted ? 'Completed' : result.text,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isCompleted
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.event.isRecurring)
                    Container(
                      width: 28,
                      height: 48,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.sync,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
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
