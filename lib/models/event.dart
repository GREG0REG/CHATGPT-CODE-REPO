import 'dart:convert';
import 'package:flutter/material.dart';

// ============================================
// RECURRENCE TYPES
// ============================================
enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

// ============================================
// YEARLY SPECIFIC DATE (for JSON serialization)
// ============================================
class YearlySpecificDate {
  final int month; // 1-12
  final int day; // 1-31
  final int? customStartTimeMillis;
  final int? customDeadlineMillis;

  const YearlySpecificDate({
    required this.month,
    required this.day,
    this.customStartTimeMillis,
    this.customDeadlineMillis,
  });

  Map<String, dynamic> toJson() => {
        'm': month,
        'd': day,
        if (customStartTimeMillis != null) 's': customStartTimeMillis,
        if (customDeadlineMillis != null) 'e': customDeadlineMillis,
      };

  factory YearlySpecificDate.fromJson(Map<String, dynamic> json) =>
      YearlySpecificDate(
        month: json['m'] as int,
        day: json['d'] as int,
        customStartTimeMillis: json['s'] as int?,
        customDeadlineMillis: json['e'] as int?,
      );

  DateTime toDateTime(int year) => DateTime(year, month, day);

  @override
  String toString() => '$month/$day';
}

// ============================================
// MAIN EVENT MODEL
// ============================================
class Event {
  final int? id;
  final String title;
  final int dateMillis;
  final int? startTimeMillis;
  final int? deadlineMillis;
  final String? notes;

  // --- Recurrence fields (NEW) ---
  final RecurrenceType recurrence;
  final int recurrenceInterval; // 1-50, default 1
  final bool yearlyUseSpecificDates; // only for yearly
  final String? yearlySpecificDatesJson; // JSON list of YearlySpecificDate
  final String? excludedDatesJson; // JSON list of excluded timestamps

  const Event({
    this.id,
    required this.title,
    required this.dateMillis,
    this.startTimeMillis,
    this.deadlineMillis,
    this.notes,
    this.recurrence = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.yearlyUseSpecificDates = false,
    this.yearlySpecificDatesJson,
    this.excludedDatesJson,
  });

  // --- Computed properties ---

  bool get isRecurring => recurrence != RecurrenceType.none;

  List<YearlySpecificDate> get yearlySpecificDates {
    if (yearlySpecificDatesJson == null || yearlySpecificDatesJson!.isEmpty)
      return [];
    try {
      final list = jsonDecode(yearlySpecificDatesJson!) as List;
      return list
          .map((e) => YearlySpecificDate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<int> get excludedDates {
    if (excludedDatesJson == null || excludedDatesJson!.isEmpty) return [];
    try {
      final list = jsonDecode(excludedDatesJson!) as List;
      return list.cast<int>();
    } catch (_) {
      return [];
    }
  }

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
  // URGENCY COLOR (unchanged)
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

  /// Convenience: returns the countdown text string for this event at [now].
  String getCountdownText(DateTime now, {required bool smartFormatEnabled}) {
    final diff = Duration(
      milliseconds: finalMillis - now.millisecondsSinceEpoch,
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
  // COPY & SERIALIZATION
  // ============================================
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
    bool? yearlyUseSpecificDates,
    String? yearlySpecificDatesJson,
    bool clearYearlySpecificDates = false,
    String? excludedDatesJson,
    bool clearExcludedDates = false,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      dateMillis: dateMillis ?? this.dateMillis,
      startTimeMillis: clearStartTime
          ? null
          : (startTimeMillis ?? this.startTimeMillis),
      deadlineMillis: clearDeadline
          ? null
          : (deadlineMillis ?? this.deadlineMillis),
      notes: notes ?? this.notes,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      yearlyUseSpecificDates:
          yearlyUseSpecificDates ?? this.yearlyUseSpecificDates,
      yearlySpecificDatesJson: clearYearlySpecificDates
          ? null
          : (yearlySpecificDatesJson ?? this.yearlySpecificDatesJson),
      excludedDatesJson: clearExcludedDates
          ? null
          : (excludedDatesJson ?? this.excludedDatesJson),
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
      'recurrence': recurrence.index,
      'recurrenceInterval': recurrenceInterval,
      'yearlyUseSpecificDates': yearlyUseSpecificDates ? 1 : 0,
      'yearlySpecificDatesJson': yearlySpecificDatesJson,
      'excludedDatesJson': excludedDatesJson,
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
      recurrence: RecurrenceType.values[
          (map['recurrence'] as int?)?.clamp(0, RecurrenceType.values.length - 1) ??
              0],
      recurrenceInterval:
          (map['recurrenceInterval'] as int?)?.clamp(1, 50) ?? 1,
      yearlyUseSpecificDates: (map['yearlyUseSpecificDates'] as int?) == 1,
      yearlySpecificDatesJson: map['yearlySpecificDatesJson'] as String?,
      excludedDatesJson: map['excludedDatesJson'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Event.fromJson(Map<String, dynamic> json) => Event.fromMap(json);
}
