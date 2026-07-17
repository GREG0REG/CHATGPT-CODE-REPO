import 'package:flutter/material.dart';

/// A single countdown event.
class Event {
  final int? id;
  final String title;
  final int dateMillis;
  final int? startTimeMillis;
  final int? deadlineMillis;
  final String? notes;
  final RecurrenceType recurrence;
  final int recurrenceInterval; // 1-30 days, 1-12 weeks, etc.
  final String? specificDates; // comma-separated millis for yearly specific dates

  Event({
    this.id,
    required this.title,
    required this.dateMillis,
    this.startTimeMillis,
    this.deadlineMillis,
    this.notes,
    this.recurrence = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.specificDates,
  });

  int get primarySortMillis {
    if (startTimeMillis != null) return startTimeMillis!;
    if (deadlineMillis != null) return deadlineMillis!;
    return dateMillis;
  }

  int get finalMillis {
    if (deadlineMillis != null) return deadlineMillis!;
    if (startTimeMillis != null) return startTimeMillis!;
    return dateMillis;
  }

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

  bool get isRecurring => recurrence != RecurrenceType.none;

  bool get isYearlySpecificDates => recurrence == RecurrenceType.yearly && specificDates != null && specificDates!.isNotEmpty;

  /// Returns the next specific date from the list that is in the future.
  int? _nextSpecificDate(DateTime now) {
    if (specificDates == null || specificDates!.isEmpty) return null;
    final nowMillis = now.millisecondsSinceEpoch;
    final dates = specificDates!.split(',').map(int.parse).toList()..sort();
    for (final d in dates) {
      if (d > nowMillis) return d;
    }
    // All passed, return first date of next year
    return null;
  }

  /// Generates the next occurrence of this event.
  Event? generateNextOccurrence() {
    if (!isRecurring) return null;

    final base = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    DateTime nextDate;

    switch (recurrence) {
      case RecurrenceType.daily:
        nextDate = base.add(Duration(days: recurrenceInterval));
        break;
      case RecurrenceType.weekly:
        nextDate = base.add(Duration(days: recurrenceInterval * 7));
        break;
      case RecurrenceType.monthly:
        nextDate = DateTime(base.year, base.month + recurrenceInterval, base.day);
        // Handle month-end overflow
        if (nextDate.day != base.day) {
          nextDate = DateTime(base.year, base.month + recurrenceInterval + 1, 0);
        }
        break;
      case RecurrenceType.yearly:
        if (isYearlySpecificDates) {
          final nextSpecific = _nextSpecificDate(DateTime.now());
          if (nextSpecific != null) {
            nextDate = DateTime.fromMillisecondsSinceEpoch(nextSpecific);
          } else {
            // All specific dates passed for this year, move to next year
            final firstDate = DateTime.fromMillisecondsSinceEpoch(
              int.parse(specificDates!.split(',').first),
            );
            nextDate = DateTime(firstDate.year + 1, firstDate.month, firstDate.day);
          }
        } else {
          nextDate = DateTime(base.year + recurrenceInterval, base.month, base.day);
          if (nextDate.month != base.month) {
            nextDate = DateTime(base.year + recurrenceInterval, base.month + 1, 0);
          }
        }
        break;
      case RecurrenceType.none:
        return null;
    }

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
      recurrenceInterval: recurrenceInterval,
      specificDates: specificDates,
    );
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
    int? recurrenceInterval,
    String? specificDates,
    bool clearSpecificDates = false,
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
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      specificDates: clearSpecificDates ? null : (specificDates ?? this.specificDates),
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
      'recurrenceInterval': recurrenceInterval,
      'specificDates': specificDates,
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
      recurrenceInterval: map['recurrenceInterval'] as int? ?? 1,
      specificDates: map['specificDates'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Event.fromJson(Map<String, dynamic> json) => Event.fromMap(json);
}

enum RecurrenceType { none, daily, weekly, monthly, yearly }
