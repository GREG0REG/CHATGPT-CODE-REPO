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
  // URGENCY COLOR (FIXED - uses the same target as countdown text)
  // ============================================
  Color getUrgencyColor(DateTime now) {
    if (isCompleted) return Colors.grey;

    final nowMillis = now.millisecondsSinceEpoch;
    // FIX: Use the same target that countdown text uses
    final target = _countdownTargetMillis;
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

  /// The millis used for countdown display (start time if before start, else deadline/date)
  int get _countdownTargetMillis {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    // If we have a start time and we're before it, count down to start
    if (startTimeMillis != null && nowMillis < startTimeMillis!) {
      return startTimeMillis!;
    }
    // Otherwise count down to deadline or date
    return deadlineMillis ?? dateMillis;
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

    final nowMillis = now.millisecondsSinceEpoch;
    // FIX: Use start time if before start, else deadline/date
    int targetMillis;
    if (startTimeMillis != null && nowMillis < startTimeMillis!) {
      targetMillis = startTimeMillis!;
    } else {
      targetMillis = deadlineMillis ?? dateMillis;
    }

    final diff = Duration(milliseconds: targetMillis - nowMillis);

    if (diff.isNegative) return 'Completed';

    // Check if counting down to start vs deadline
    final isBeforeStart = startTimeMillis != null && nowMillis < startTimeMillis!;
    final suffix = isBeforeStart ? ' until start' : ' left';

    if (diff.inHours >= 24) {
      final days = diff.inDays;
      return '$days day${days == 1 ? '' : 's'}$suffix';
    } else if (diff.inMinutes >= 60) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'}$suffix';
    } else {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'}$suffix';
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

  // ============================================
  // VALIDATION (FIX for Issue 55)
  // ============================================
  /// Validates that a raw map contains valid Event data with detailed errors.
  static void _validateMap(Map<String, dynamic> map) {
    final errors = <String>[];

    // Required fields
    if (map['title'] == null) {
      errors.add('missing required field "title"');
    } else if (map['title'] is! String) {
      errors.add('"title" must be a String, got ${map['title'].runtimeType}');
    } else if ((map['title'] as String).trim().isEmpty) {
      errors.add('"title" cannot be empty');
    }

    if (map['dateMillis'] == null) {
      errors.add('missing required field "dateMillis"');
    } else if (map['dateMillis'] is! int) {
      errors.add('"dateMillis" must be an int (milliseconds since epoch), got ${map['dateMillis'].runtimeType}');
    }

    // Optional fields — validate type if present
    if (map['id'] != null && map['id'] is! int) {
      errors.add('"id" must be an int or null, got ${map['id'].runtimeType}');
    }
    if (map['startTimeMillis'] != null && map['startTimeMillis'] is! int) {
      errors.add('"startTimeMillis" must be an int or null, got ${map['startTimeMillis'].runtimeType}');
    }
    if (map['deadlineMillis'] != null && map['deadlineMillis'] is! int) {
      errors.add('"deadlineMillis" must be an int or null, got ${map['deadlineMillis'].runtimeType}');
    }
    if (map['notes'] != null && map['notes'] is! String) {
      errors.add('"notes" must be a String or null, got ${map['notes'].runtimeType}');
    }
    if (map['recurrence'] != null && map['recurrence'] is! int) {
      errors.add('"recurrence" must be an int or null, got ${map['recurrence'].runtimeType}');
    }
    if (map['recurrenceInterval'] != null && map['recurrenceInterval'] is! int) {
      errors.add('"recurrenceInterval" must be an int or null, got ${map['recurrenceInterval'].runtimeType}');
    }
    if (map['yearlyUseSpecificDates'] != null && map['yearlyUseSpecificDates'] is! int) {
      errors.add('"yearlyUseSpecificDates" must be an int or null, got ${map['yearlyUseSpecificDates'].runtimeType}');
    }
    if (map['yearlySpecificDatesJson'] != null && map['yearlySpecificDatesJson'] is! String) {
      errors.add('"yearlySpecificDatesJson" must be a String or null, got ${map['yearlySpecificDatesJson'].runtimeType}');
    }
    if (map['excludedDatesJson'] != null && map['excludedDatesJson'] is! String) {
      errors.add('"excludedDatesJson" must be a String or null, got ${map['excludedDatesJson'].runtimeType}');
    }
    if (map['iconName'] != null && map['iconName'] is! String) {
      errors.add('"iconName" must be a String or null, got ${map['iconName'].runtimeType}');
    }
    if (map['priority'] != null && map['priority'] is! int) {
      errors.add('"priority" must be an int or null, got ${map['priority'].runtimeType}');
    }
    if (map['subjectTag'] != null && map['subjectTag'] is! String) {
      errors.add('"subjectTag" must be a String or null, got ${map['subjectTag'].runtimeType}');
    }
    if (map['isCompleted'] != null && map['isCompleted'] is! int) {
      errors.add('"isCompleted" must be an int or null, got ${map['isCompleted'].runtimeType}');
    }

    if (errors.isNotEmpty) {
      throw FormatException(errors.join('; '));
    }
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
    _validateMap(map);
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

  factory Event.fromJson(Map<String, dynamic> json) {
    try {
      return Event.fromMap(json);
    } catch (e) {
      throw FormatException('Failed to parse Event from JSON: $e\nReceived: $json');
    }
  }
}
