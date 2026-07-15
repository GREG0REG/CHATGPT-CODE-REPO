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

  Event({
    this.id,
    required this.title,
    required this.dateMillis,
    this.startTimeMillis,
    this.deadlineMillis,
    this.notes,
  });

  /// The timestamp used for sorting / "which event is next" purposes.
  /// We use whichever of start/deadline comes first and is still in the
  /// future-relevant sense; if neither is set we fall back to the date.
  int get primarySortMillis {
    if (startTimeMillis != null) return startTimeMillis!;
    if (deadlineMillis != null) return deadlineMillis!;
    return dateMillis;
  }

  /// The final relevant timestamp for this event (the point after which
  /// the event is fully "done"). Used to decide when to move to the next
  /// upcoming event.
  int get finalMillis {
    if (deadlineMillis != null) return deadlineMillis!;
    if (startTimeMillis != null) return startTimeMillis!;
    return dateMillis;
  }

  // ============================================
  // SESSION 2: URGENCY COLOR
  // ============================================
  /// Returns a color based on how many days until the event's deadline
  /// (or start time if no deadline):
  ///   Green  > 7 days
  ///   Yellow 3-7 days
  ///   Red    < 3 days
  ///   Grey   if completed
  Color getUrgencyColor(DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    final target = deadlineMillis ?? startTimeMillis ?? dateMillis;
    final diff = Duration(milliseconds: target - nowMillis);

    if (diff.isNegative || diff.inDays < 0) {
      return Colors.grey; // Completed / passed
    } else if (diff.inDays > 7) {
      return Colors.green;
    } else if (diff.inDays >= 3) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Convenience: returns the countdown text string for this event at [now].
  String getCountdownText(DateTime now, {required bool smartFormatEnabled}) {
    // This is a thin wrapper around CountdownService that callers can use
    // directly on an Event instance.
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

  Event copyWith({
    int? id,
    String? title,
    int? dateMillis,
    int? startTimeMillis,
    bool clearStartTime = false,
    int? deadlineMillis,
    bool clearDeadline = false,
    String? notes,
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
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Event.fromJson(Map<String, dynamic> json) => Event.fromMap(json);
}
