import 'package:flutter/material.dart';

/// A single countdown event.
///
/// Only ONE of [startTimeMillis] / [deadlineMillis] is required to be set;
/// an event may have a start time only, a deadline only, or both.
class Event {
  final int? id;
  final String title;
  final int dateMillis; // midnight of the event's date (local)
  final int? startTimeMillis; // full timestamp, or null if not set
  final int? deadlineMillis; // full timestamp, or null if not set
  final String? notes;
  final RecurrenceType recurrence; // SESSION 5

  Event({
    this.id,
    required this.title,
    required this.dateMillis,
    this.startTimeMillis,
    this.deadlineMillis,
    this.notes,
    this.recurrence = RecurrenceType.none,
  });

  /// The timestamp used for sorting / "which event is next" purposes.
  int get primarySortMillis {
    if (startTimeMillis != null) return startTimeMillis!;
    if (deadlineMillis != null) return deadlineMillis!;
    return dateMillis;
  }

  /// The final relevant timestamp for this event.
  int get finalMillis {
    if (deadlineMillis != null) return deadlineMillis!;
    if (startTimeMillis != null) return startTimeMillis!;
    return dateMillis;
  }

  // ============================================
  // SESSION 2: URGENCY COLOR
  // ============================================
  Color getUrgencyColor(DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    final target = deadlineMillis ?? startTimeMillis ?? dateMillis;
    final diff = Duration(milliseconds: target - nowMillis);

    if (diff.isNegative || diff.inDays < 0) {
      return Colors.grey;
    } else if (diff.inDays > 7) {
      return Colors.green;
    } else if (diff.inDays >= 3) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String getCountdownText(DateTime now, {required bool smartFormatEnabled}) {
    final diff = Duration(
      milliseconds: (deadlineMillis ?? startTimeMillis ?? dateMillis) - now.millisecondsSinceEpoch,
    );

    if (diff.isNegative) return 'Completed';

    if (diff.inHours >= 24) {
      final days = diff.inDays;
      return '$days day${days == 1 ? '' : 's'} left';
    } else if (diff.inMinutes >= 60) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} left';
    } else {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} left';
    }
  }

  // ============================================
  // SESSION 5: Recurrence helpers
  // ============================================
  bool get isRecurring => recurrence != RecurrenceType.none;

  /// Generates the next occurrence of this event based on its recurrence.
  /// Returns null if not recurring.
  Event? generateNextOccurrence() {
    if (!isRecurring) return null;

    final base = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    final nextDate = _nextDate(base, recurrence);

    int? nextStart;
    if (startTimeMillis != null) {
      final start = DateTime.fromMillisecondsSinceEpoch(startTimeMillis!);
      final diff = start.difference(base);
      nextStart = nextDate.add(diff).millisecondsSinceEpoch;
    }

    int? nextDeadline;
    if (deadlineMillis != null) {
      final deadline = DateTime.fromMillisecondsSinceEpoch(deadlineMillis!);
      final diff = deadline.difference(base);
      nextDeadline = nextDate.add(diff).millisecondsSinceEpoch;
    }

    return Event(
      title: title,
      dateMillis: nextDate.millisecondsSinceEpoch,
      startTimeMillis: nextStart,
      deadlineMillis: nextDeadline,
      notes: notes,
      recurrence: recurrence,
    );
  }

  static DateTime _nextDate(DateTime current, RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return current.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return current.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        var next = DateTime(current.year, current.month + 1, current.day);
        if (next.day != current.day) {
          next = DateTime(current.year, current.month + 2, 0);
        }
        return next;
      case RecurrenceType.yearly:
        var next = DateTime(current.year + 1, current.month, current.day);
        if (next.month != current.month) {
          next = DateTime(current.year + 1, current.month + 1, 0);
        }
        return next;
      case RecurrenceType.none:
        return current;
    }
  }

  Event copyWith({
    int? id,
    String? title,
    int? dateMillis,
    int? startTimeMillis,
    bool clearStartTime = false,
    int? deadlineMillis,
    bool clearDeadline = false,
    String? notes,
    RecurrenceType? recurrence,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      dateMillis: dateMillis ?? this.dateMillis,
      startTimeMillis:
          clearStartTime ? null : (startTimeMillis ?? this.startTimeMillis),
      deadlineMillis:
          clearDeadline ? null : (deadlineMillis ?? this.deadlineMillis),
      notes: notes ?? this.notes,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateMillis': dateMillis,
      'startTimeMillis': startTimeMillis,
      'deadlineMillis': deadlineMillis,
      'notes': notes,
      'recurrence': recurrence.name,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as int?,
      title: map['title'] as String,
      dateMillis: map['dateMillis'] as int,
      startTimeMillis: map['startTimeMillis'] as int?,
      deadlineMillis: map['deadlineMillis'] as int?,
      notes: map['notes'] as String?,
      recurrence: RecurrenceType.values.byName(
        (map['recurrence'] as String?) ?? 'none',
      ),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Event.fromJson(Map<String, dynamic> json) => Event.fromMap(json);
}

enum RecurrenceType { none, daily, weekly, monthly, yearly }
