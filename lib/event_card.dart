import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'database_helper.dart';
import 'models/event.dart';
import 'models/subtask.dart';
import 'services/countdown_service.dart';
import 'theme/app_themes.dart';

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
  List<Subtask> _subtasks = [];

  @override
  void initState() {
    super.initState();
    _loadSubtasks();
  }

  Future<void> _loadSubtasks() async {
    final id = widget.event.id;
    if (id == null || id <= 0) return;
    try {
      final list = await DatabaseHelper.instance.getSubtasksForEvent(id);
      if (mounted) setState(() => _subtasks = list);
    } catch (_) {}
  }

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

  Widget _buildSubtaskRow() {
    final done = _subtasks.where((s) => s.isCompleted).length;
    final total = _subtasks.length;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.checklist, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          '$done/$total',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 4,
              backgroundColor: cs.primary.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
        ),
      ],
    );
  }

  /// Build a mini circular progress indicator for the card
  Widget _buildCircularProgress(double progress, Color color) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 3,
            backgroundColor: color.withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation(Colors.transparent),
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round,
          ),
        ],
      ),
    );
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

    // Calculate progress for the circular indicator
    double progressValue = 0.0;
    if (!isCompleted && displayEvent.deadlineMillis != null && displayEvent.startTimeMillis != null) {
      final total = displayEvent.deadlineMillis! - displayEvent.startTimeMillis!;
      final elapsed = now.millisecondsSinceEpoch - displayEvent.startTimeMillis!;
      if (total > 0) {
        progressValue = (elapsed / total).clamp(0.0, 1.0);
      }
    } else {
      progressValue = isCompleted ? 1.0 : 0.65;
    }

    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isCompleted
                    ? null
                    : LinearGradient(
                        colors: [
                          cs.primary.withOpacity(0.03),
                          cs.secondary.withOpacity(0.03),
                        ],
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Event Icon with urgency-colored background (FIXED - was missing)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.grey.withOpacity(0.12)
                            : urgencyColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          displayEvent.iconData,
                          size: 24,
                          color: isCompleted ? Colors.grey : urgencyColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Circular progress indicator
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _buildCircularProgress(
                        progressValue,
                        isCompleted ? Colors.grey : cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title with priority badge (FIXED - priority now visible)
                          Row(
                            children: [
                              Expanded(
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
                              if (widget.event.priority > 2) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.event.priorityColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.event.priorityLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: widget.event.priorityColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (widget.event.subjectTag != null && widget.event.subjectTag!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [cs.primary.withOpacity(0.12), cs.secondary.withOpacity(0.12)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.event.subjectTag!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (subtitleParts.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitleParts.join(' • '),
                              style: TextStyle(
                                fontSize: 12,
                                color: isCompleted
                                    ? Colors.grey
                                    : cs.outline,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Urgency dot + countdown text (FIXED - visual urgency indicator)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: urgencyColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCompleted ? 'Completed' : result.text,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isCompleted
                                      ? Colors.grey
                                      : cs.primary,
                                ),
                              ),
                            ],
                          ),
                          if (_subtasks.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSubtaskRow(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Action buttons
                    if (widget.event.isRecurring)
                      Container(
                        width: 28,
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.sync,
                          size: 16,
                          color: cs.primary,
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
                                color: cs.primary, size: 24),
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
                          width: 36, height: 48, alignment: Alignment.center,
                          child: Icon(Icons.share,
                            color: cs.primary.withOpacity(0.6), size: 18),
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
                          width: 36, height: 48, alignment: Alignment.center,
                          child: Icon(Icons.delete_outline,
                            color: cs.error.withOpacity(0.6), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
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
                color: cs.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withOpacity(0.3),
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
                            style: TextStyle(fontSize: 11, color: cs.outline))
                        : null,
                    trailing: Text(
                      childResult.text,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: cs.primary),
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
