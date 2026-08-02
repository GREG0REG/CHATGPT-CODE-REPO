import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final VoidCallback? onStartStudyTimer;

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
    this.onStartStudyTimer,
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

  bool _isExplicitlySet(int? timestampMillis, int baseDateMillis) {
    if (timestampMillis == null) return false;
    if (timestampMillis == baseDateMillis) return false;
    final ts = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final base = DateTime.fromMillisecondsSinceEpoch(baseDateMillis);
    if (ts.year == base.year && ts.month == base.month && ts.day == base.day) {
      return ts.hour != 0 || ts.minute != 0;
    }
    return true;
  }

  double _calculateUrgencyProgress(DateTime now, Event event) {
    if (event.isCompleted) return 1.0;
    final eventDate = DateTime.fromMillisecondsSinceEpoch(event.finalMillis);
    final diff = eventDate.difference(now);
    final daysUntil = diff.inDays;
    if (diff.isNegative || diff.inHours <= 0) return 1.0;
    if (daysUntil >= 30) return 0.05;
    else if (daysUntil >= 7) return (1.0 - (daysUntil / 30.0)).clamp(0.05, 0.95);
    else return (1.0 - (daysUntil / 7.0)).clamp(0.1, 1.0);
  }

  String _getUrgencyLabel(DateTime now, Event event) {
    if (event.isCompleted) return 'Done';
    final eventDate = DateTime.fromMillisecondsSinceEpoch(event.finalMillis);
    final diff = eventDate.difference(now);
    final daysUntil = diff.inDays;
    if (diff.isNegative || diff.inHours <= 0) return 'Now';
    if (daysUntil == 0) return 'Today';
    if (daysUntil == 1) return 'Tomorrow';
    if (daysUntil < 7) return '$daysUntil days';
    if (daysUntil < 30) return '${(daysUntil / 7).floor()} weeks';
    return '${(daysUntil / 30).floor()} months';
  }

  Future<void> _shareEvent(BuildContext context) async {
    final now = DateTime.now();
    final result = CountdownService.buildCountdownText(
      widget.event, now, smartFormatEnabled: widget.smartFormatEnabled,
    );
    await Share.share('${widget.event.title}\n${result.text}', subject: widget.event.title);
  }

  void _handleStartStudyTimer() {
    HapticFeedback.mediumImpact();
    final duration = widget.event.studyDuration;
    int minutes;
    switch (duration) {
      case 'short': minutes = 45; break;
      case 'long': minutes = 180; break;
      case 'medium':
      default: minutes = 90; break;
    }
    if (widget.onStartStudyTimer != null) {
      widget.onStartStudyTimer!();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started ${widget.event.studyDurationEnum.label} — $minutes min timer'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STRICT VISIBILITY HELPERS — Only show when explicitly set
  // ═══════════════════════════════════════════════════════════════

  /// Returns true if the user explicitly selected a NEET exam type (not default/none)
  bool get _hasNeetExamType {
    final type = widget.event.neetExamType;
    return type != null && type.isNotEmpty && type != 'none';
  }

  /// Returns true if the user explicitly set a difficulty level
  bool get _hasDifficulty {
    final diff = widget.event.difficulty;
    return diff != null && diff.isNotEmpty;
  }

  /// Returns true if the user explicitly set a study duration
  bool get _hasStudyDuration {
    final dur = widget.event.studyDuration;
    return dur != null && dur.isNotEmpty;
  }

  /// Returns true if the user explicitly set a revision round (not default)
  bool get _hasRevisionRound {
    final round = widget.event.revisionRound;
    return round != null && round.isNotEmpty && round != 'round1';
  }

  /// Returns true if the user explicitly set a subject tag
  bool get _hasSubjectTag {
    final tag = widget.event.subjectTag;
    return tag != null && tag.isNotEmpty;
  }

  /// Returns true if this event has ANY NEET-specific metadata to display
  bool get _hasAnyNeetData {
    return _hasNeetExamType ||
        _hasDifficulty ||
        widget.event.isPyqSession ||
        _hasRevisionRound ||
        _hasStudyDuration ||
        _hasSubjectTag ||
        widget.event.studyModeTags.isNotEmpty ||
        (widget.event.neetExamType == 'mockTest' && widget.event.targetScore != null);
  }

  // ═══════════════════════════════════════════════════════════════
  // NEET BADGE BUILDERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNeetExamTypeBadge(ColorScheme cs) {
    if (!_hasNeetExamType) return const SizedBox.shrink();

    final type = widget.event.neetExamTypeEnum;
    Color bgColor;
    Color textColor;
    switch (type) {
      case NeetExamType.mockTest:
        bgColor = const Color(0xFF1565C0);
        textColor = Colors.white;
        break;
      case NeetExamType.revisionSession:
        bgColor = const Color(0xFF2E7D32);
        textColor = Colors.white;
        break;
      case NeetExamType.finalPrep:
        bgColor = const Color(0xFFEF6C00);
        textColor = Colors.white;
        break;
      case NeetExamType.pyqPractice:
        bgColor = const Color(0xFF7B1FA2);
        textColor = Colors.white;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(ColorScheme cs) {
    if (!_hasDifficulty) return const SizedBox.shrink();

    final diff = widget.event.difficultyEnum;
    Color dotColor;
    switch (diff) {
      case StudyDifficulty.easy:
        dotColor = Colors.green;
        break;
      case StudyDifficulty.hard:
        dotColor = Colors.red;
        break;
      case StudyDifficulty.medium:
      default:
        dotColor = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dotColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dotColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            diff.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dotColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPyqBadge(ColorScheme cs) {
    if (!widget.event.isPyqSession) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 12, color: const Color(0xFF7B1FA2)),
          const SizedBox(width: 3),
          Text(
            'PYQ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7B1FA2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionRoundBadge(ColorScheme cs) {
    if (!_hasRevisionRound) return const SizedBox.shrink();

    final round = widget.event.revisionRoundEnum;
    String label;
    Color bgColor;
    switch (round) {
      case RevisionRound.round1:
        label = 'R1';
        bgColor = const Color(0xFF1565C0);
        break;
      case RevisionRound.round2:
        label = 'R2';
        bgColor = const Color(0xFF2E7D32);
        break;
      case RevisionRound.round3:
        label = 'R3';
        bgColor = const Color(0xFFEF6C00);
        break;
      case RevisionRound.mockTestPhase:
        label = 'Mock';
        bgColor = const Color(0xFF7B1FA2);
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: bgColor.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: bgColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStudyDurationBadge(ColorScheme cs) {
    if (!_hasStudyDuration) return const SizedBox.shrink();

    final duration = widget.event.studyDurationEnum;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: duration.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: duration.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(duration.icon, size: 12, color: duration.color),
          const SizedBox(width: 3),
          Text(
            duration.label.split(' ').first,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: duration.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectIndicator(ColorScheme cs) {
    if (!_hasSubjectTag) return const SizedBox.shrink();

    final tag = widget.event.subjectTag!;
    Color dotColor;
    final lower = tag.toLowerCase();
    if (lower.contains('physics')) {
      dotColor = const Color(0xFF1565C0);
    } else if (lower.contains('chemistry')) {
      dotColor = const Color(0xFF2E7D32);
    } else if (lower.contains('biology')) {
      dotColor = const Color(0xFFEF6C00);
    } else {
      dotColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dotColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dotColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            tag,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dotColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetScoreProgress(ColorScheme cs) {
    if (widget.event.neetExamType != 'mockTest' || widget.event.targetScore == null) {
      return const SizedBox.shrink();
    }

    final target = widget.event.targetScore!;
    final total = widget.event.neetTotalMarks ?? 720;
    final progress = (target / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$target/$total',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyModeTags(ColorScheme cs) {
    final tags = widget.event.studyModeTags;
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions(ColorScheme cs, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          if (_hasStudyDuration)
            Expanded(
              child: FilledButton.icon(
                onPressed: isCompleted ? null : _handleStartStudyTimer,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(
                  'Start ${widget.event.studyDurationEnum.label.split(' ').first}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          if (_hasStudyDuration)
            const SizedBox(width: 8),
          if (widget.onComplete != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () => widget.onComplete!(!isCompleted),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    color: isCompleted ? Colors.green : cs.onSurfaceVariant.withOpacity(0.5),
                    size: 22,
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
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.share_outlined,
                  color: cs.onSurfaceVariant.withOpacity(0.5),
                  size: 18,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.edit_outlined,
                  color: cs.onSurfaceVariant.withOpacity(0.5),
                  size: 18,
                ),
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
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_outline,
                  color: cs.error.withOpacity(0.6),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeetBadgeRow(ColorScheme cs) {
    final badges = <Widget>[];

    final examType = _buildNeetExamTypeBadge(cs);
    if (examType is! SizedBox) badges.add(examType);

    final difficulty = _buildDifficultyBadge(cs);
    if (difficulty is! SizedBox) badges.add(difficulty);

    final pyq = _buildPyqBadge(cs);
    if (pyq is! SizedBox) badges.add(pyq);

    final revision = _buildRevisionRoundBadge(cs);
    if (revision is! SizedBox) badges.add(revision);

    final duration = _buildStudyDurationBadge(cs);
    if (duration is! SizedBox) badges.add(duration);

    final subject = _buildSubjectIndicator(cs);
    if (subject is! SizedBox) badges.add(subject);

    if (badges.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: badges.map((b) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: b,
        )).toList(),
      ),
    );
  }

  Widget _buildUrgencyBar(double progress, Color color, String label) {
    return Tooltip(
      message: 'Time remaining: $label',
      child: Container(
        width: 5,
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 5,
            height: 72 * progress,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
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
    subtitleParts.add('Date: ${_formatDateOnly(widget.event.dateMillis)}');
    if (_isExplicitlySet(widget.event.startTimeMillis, widget.event.dateMillis)) {
      subtitleParts.add('Starts: ${_formatDateTime(widget.event.startTimeMillis!)}');
    }
    if (_isExplicitlySet(widget.event.deadlineMillis, widget.event.dateMillis)) {
      subtitleParts.add('Deadline: ${_formatDateTime(widget.event.deadlineMillis!)}');
    }

    final urgencyColor = isCompleted ? Colors.grey : displayEvent.getUrgencyColor(now);
    final isRecurringParent = widget.event.isRecurring && widget.event.id != null && widget.event.id! > 0;
    final hasChildren = widget.childOccurrences != null && widget.childOccurrences!.isNotEmpty;

    final urgencyProgress = _calculateUrgencyProgress(now, displayEvent);
    final urgencyLabel = _getUrgencyLabel(now, displayEvent);

    final cs = Theme.of(context).colorScheme;

    Color borderColor = urgencyColor;
    if (widget.event.difficulty == 'hard' && urgencyColor == Colors.red) {
      borderColor = const Color(0xFFB71C1C);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: borderColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
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
                          cs.primary.withOpacity(0.02),
                          cs.secondary.withOpacity(0.02),
                        ],
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── NEET BADGE ROW (only if any NEET data exists) ──
                    if (_hasAnyNeetData) ...[
                      _buildNeetBadgeRow(cs),
                      const SizedBox(height: 10),
                    ],

                    // ── MAIN ROW ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildUrgencyBar(urgencyProgress, isCompleted ? Colors.grey : cs.primary, urgencyLabel),
                        const SizedBox(width: 12),

                        Stack(
                          alignment: Alignment.center,
                          children: [
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
                            if (!isCompleted && widget.event.priority > 0)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: widget.event.priorityColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                  if (widget.event.priority > 0) ...[
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
                              if (subtitleParts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitleParts.join(' • '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCompleted ? Colors.grey : cs.outline,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
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
                                      color: isCompleted ? Colors.grey : cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        _buildTargetScoreProgress(cs),

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
                      ],
                    ),

                    // ── STUDY MODE TAGS ──
                    if (widget.event.studyModeTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildStudyModeTags(cs),
                    ],

                    // ── QUICK ACTION BUTTONS ──
                    const SizedBox(height: 8),
                    _buildQuickActions(cs, isCompleted),
                  ],
                ),
              ),
            ),
          ),
        ),

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
                  if (_isExplicitlySet(child.startTimeMillis, child.dateMillis)) {
                    childSubtitle.add('Starts: ${_formatDateTime(child.startTimeMillis!)}');
                  } else {
                    childSubtitle.add('Date: $childDate');
                  }
                  if (_isExplicitlySet(child.deadlineMillis, child.dateMillis)) {
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
