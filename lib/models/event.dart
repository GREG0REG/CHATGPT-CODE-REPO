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
// EVENT ICONS FOR STUDENTS
// ============================================
class EventIcons {
  EventIcons._();

  static const Map<String, IconData> icons = {
    'event': Icons.event,
    'school': Icons.school,
    'book': Icons.book,
    'menu_book': Icons.menu_book,
    'calculate': Icons.calculate,
    'science': Icons.science,
    'biotech': Icons.biotech,
    'computer': Icons.computer,
    'code': Icons.code,
    'edit_note': Icons.edit_note,
    'assignment': Icons.assignment,
    'quiz': Icons.quiz,
    'emoji_events': Icons.emoji_events,
    'sports': Icons.sports,
    'music_note': Icons.music_note,
    'palette': Icons.palette,
    'translate': Icons.translate,
    'public': Icons.public,
    'psychology': Icons.psychology,
    'history_edu': Icons.history_edu,
    'self_improvement': Icons.self_improvement,
    'alarm': Icons.alarm,
    'timer': Icons.timer,
    'group': Icons.group,
    'presentation': Icons.present_to_all,
    'work': Icons.work,
  };

  static IconData? getIcon(String? name) => icons[name] ?? Icons.event;

  static String? getDefaultIconName() => 'event';
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

  // --- Recurrence fields ---
  final RecurrenceType recurrence;
  final int recurrenceInterval;
  final bool yearlyUseSpecificDates;
  final String? yearlySpecificDatesJson;
  final String? excludedDatesJson;

  // --- Student Study Pack fields (NEW) ---
  final String? iconName;
  final int priority; // 0=none, 1=low, 2=normal, 3=high, 4=urgent
  final String? subjectTag;
  final bool isCompleted;

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
    this.iconName,
    this.priority = 2, // default normal
    this.subjectTag,
    this.isCompleted = false,
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
    if (isCompleted) return Colors.grey;

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

  // ============================================
  // PRIORITY COLOR & LABEL
  // ============================================
  Color get priorityColor {
    switch (priority) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Normal';
      case 3:
        return 'High';
      case 4:
        return 'Urgent';
      default:
        return 'None';
    }
  }

  // FIX: Added ?? Icons.event so it never returns null
  IconData get iconData => EventIcons.getIcon(iconName) ?? Icons.event;

  /// Convenience: returns the countdown text string for this event at [now].
  String getCountdownText(DateTime now, {required bool smartFormatEnabled}) {
    if (isCompleted) return 'Completed';

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
    String? iconName,
    bool clearIconName = false,
    int? priority,
    String? subjectTag,
    bool clearSubjectTag = false,
    bool? isCompleted,
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
      iconName: clearIconName ? null : (iconName ?? this.iconName),
      priority: priority ?? this.priority,
      subjectTag: clearSubjectTag ? null : (subjectTag ?? this.subjectTag),
      isCompleted: isCompleted ?? this.isCompleted,
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
      'iconName': iconName,
      'priority': priority,
      'subjectTag': subjectTag,
      'isCompleted': isCompleted ? 1 : 0,
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
      iconName: map['iconName'] as String?,
      priority: (map['priority'] as int?)?.clamp(0, 4) ?? 2,
      subjectTag: map['subjectTag'] as String?,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Event.fromJson(Map<String, dynamic> json) => Event.fromMap(json);
}
