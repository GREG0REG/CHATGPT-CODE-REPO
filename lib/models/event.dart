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
// NEET EXAM TYPE
// ============================================
enum NeetExamType {
  none,
  mockTest,
  revisionSession,
  finalPrep,
  pyqPractice,
}

extension NeetExamTypeExt on NeetExamType {
  String get label {
    switch (this) {
      case NeetExamType.none: return 'Not specified';
      case NeetExamType.mockTest: return 'Mock Test';
      case NeetExamType.revisionSession: return 'Revision Session';
      case NeetExamType.finalPrep: return 'Final Prep';
      case NeetExamType.pyqPractice: return 'PYQ Practice';
    }
  }

  String get dbValue {
    switch (this) {
      case NeetExamType.none: return 'none';
      case NeetExamType.mockTest: return 'mockTest';
      case NeetExamType.revisionSession: return 'revisionSession';
      case NeetExamType.finalPrep: return 'finalPrep';
      case NeetExamType.pyqPractice: return 'pyqPractice';
    }
  }

  static NeetExamType fromString(String? value) {
    switch (value) {
      case 'mockTest': return NeetExamType.mockTest;
      case 'revisionSession': return NeetExamType.revisionSession;
      case 'finalPrep': return NeetExamType.finalPrep;
      case 'pyqPractice': return NeetExamType.pyqPractice;
      default: return NeetExamType.none;
    }
  }
}

// ============================================
// REVISION ROUND
// ============================================
enum RevisionRound {
  round1,
  round2,
  round3,
  mockTestPhase,
}

extension RevisionRoundExt on RevisionRound {
  String get label {
    switch (this) {
      case RevisionRound.round1: return 'Round 1: First Reading';
      case RevisionRound.round2: return 'Round 2: Revision';
      case RevisionRound.round3: return 'Round 3: Final Revision';
      case RevisionRound.mockTestPhase: return 'Mock Test Phase';
    }
  }

  String get dbValue {
    switch (this) {
      case RevisionRound.round1: return 'round1';
      case RevisionRound.round2: return 'round2';
      case RevisionRound.round3: return 'round3';
      case RevisionRound.mockTestPhase: return 'mockTestPhase';
    }
  }

  static RevisionRound fromString(String? value) {
    switch (value) {
      case 'round1': return RevisionRound.round1;
      case 'round2': return RevisionRound.round2;
      case 'round3': return RevisionRound.round3;
      case 'mockTestPhase': return RevisionRound.mockTestPhase;
      default: return RevisionRound.round1;
    }
  }
}

// ============================================
// STUDY DIFFICULTY
// ============================================
enum StudyDifficulty {
  easy,
  medium,
  hard,
}

extension StudyDifficultyExt on StudyDifficulty {
  String get label {
    switch (this) {
      case StudyDifficulty.easy: return 'Easy';
      case StudyDifficulty.medium: return 'Medium';
      case StudyDifficulty.hard: return 'Hard';
    }
  }

  String get dbValue {
    switch (this) {
      case StudyDifficulty.easy: return 'easy';
      case StudyDifficulty.medium: return 'medium';
      case StudyDifficulty.hard: return 'hard';
    }
  }

  static StudyDifficulty fromString(String? value) {
    switch (value) {
      case 'easy': return StudyDifficulty.easy;
      case 'hard': return StudyDifficulty.hard;
      default: return StudyDifficulty.medium;
    }
  }
}

// ============================================
// STUDY DURATION
// ============================================
enum StudyDuration {
  short,    // < 1 hour
  medium,   // 1-3 hours
  long,     // 3+ hours
}

extension StudyDurationExt on StudyDuration {
  String get label {
    switch (this) {
      case StudyDuration.short: return 'Short Session';
      case StudyDuration.medium: return 'Medium Session';
      case StudyDuration.long: return 'Long Session';
    }
  }

  String get subtitle {
    switch (this) {
      case StudyDuration.short: return '< 1 hour';
      case StudyDuration.medium: return '1 – 3 hours';
      case StudyDuration.long: return '3+ hours';
    }
  }

  IconData get icon {
    switch (this) {
      case StudyDuration.short: return Icons.timer_outlined;
      case StudyDuration.medium: return Icons.timelapse_outlined;
      case StudyDuration.long: return Icons.hourglass_bottom_outlined;
    }
  }

  Color get color {
    switch (this) {
      case StudyDuration.short: return Colors.teal;
      case StudyDuration.medium: return Colors.indigo;
      case StudyDuration.long: return Colors.deepPurple;
    }
  }

  String get dbValue {
    switch (this) {
      case StudyDuration.short: return 'short';
      case StudyDuration.medium: return 'medium';
      case StudyDuration.long: return 'long';
    }
  }

  static StudyDuration fromString(String? value) {
    switch (value) {
      case 'short': return StudyDuration.short;
      case 'long': return StudyDuration.long;
      default: return StudyDuration.medium;
    }
  }
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
    // NEET-specific icons
    'stethoscope': Icons.medical_services,
    'microscope': Icons.biotech,
    'dna': Icons.favorite,
    'atom': Icons.circle,
    'beaker': Icons.science,
    'hospital': Icons.local_hospital,
    'pill': Icons.medication,
    'brain': Icons.psychology,
    'heart': Icons.favorite,
    'bone': Icons.accessibility,
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

  // --- Student Study Pack fields ---
  final String? iconName;
  final int priority; // 0=none, 1=low, 2=normal, 3=high, 4=urgent
  final String? subjectTag;
  final bool isCompleted;

  // --- NEET-specific fields ---
  final bool isNeetExam;           // Is this a NEET exam/mock test event?
  final int? neetTotalMarks;       // Total marks for this test (usually 720)
  final int? neetTargetScore;      // Target score (e.g., 680+ for govt college)
  final String? neetSubjectFocus;  // Which subject to focus: 'Physics', 'Chemistry', 'Biology', 'All'

  // --- NEW: UI NEET fields (stored for persistence) ---
  final int? targetScore;          // Target score for mock tests (UI field)
  final String? neetExamType;      // 'none', 'mockTest', 'revisionSession', 'finalPrep', 'pyqPractice'
  final String? revisionRound;   // 'round1', 'round2', 'round3', 'mockTestPhase'
  final bool isPyqSession;       // Is this a PYQ practice session

  // --- NEW: Working study features ---
  final String? difficulty;        // 'easy', 'medium', 'hard'
  final String? studyDuration;     // 'short', 'medium', 'long'
  final String? studyModeTagsJson; // JSON array of selected study mode tags
  final int? customSectionId; // Links to custom_notification_sections table
  
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
    // NEET fields
    this.isNeetExam = false,
    this.neetTotalMarks,
    this.neetTargetScore,
    this.neetSubjectFocus,
    // NEW UI NEET fields
    this.targetScore,
    this.neetExamType,
    this.revisionRound,
    this.isPyqSession = false,
    // NEW working study features
    this.difficulty,
    this.studyDuration,
    this.studyModeTagsJson,
    this.customSectionId,
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
  // URGENCY COLOR
  // ============================================
  Color getUrgencyColor(DateTime now) {
    if (isCompleted) return Colors.grey;

    final nowMillis = now.millisecondsSinceEpoch;
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

  /// The millis used for countdown display
  int get _countdownTargetMillis {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    if (startTimeMillis != null && nowMillis < startTimeMillis!) {
      return startTimeMillis!;
    }
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

  IconData get iconData => EventIcons.getIcon(iconName) ?? Icons.event;

  /// Convenience: returns the countdown text string for this event at [now].
  String getCountdownText(DateTime now, {required bool smartFormatEnabled}) {
    if (isCompleted) return 'Completed';

    final nowMillis = now.millisecondsSinceEpoch;
    int targetMillis;
    if (startTimeMillis != null && nowMillis < startTimeMillis!) {
      targetMillis = startTimeMillis!;
    } else {
      targetMillis = deadlineMillis ?? dateMillis;
    }

    final diff = Duration(milliseconds: targetMillis - nowMillis);

    if (diff.isNegative) return 'Completed';

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
  // NEET HELPERS
  // ============================================

  /// Get NEET score progress if target is set
  double? get neetProgressPercent {
    if (neetTargetScore == null || neetTotalMarks == null) return null;
    if (neetTotalMarks! <= 0) return null;
    return (neetTargetScore! / neetTotalMarks! * 100).clamp(0.0, 100.0);
  }

  /// Check if this is a high-priority NEET event
  bool get isHighPriorityNeet {
    return isNeetExam && (priority >= 3);
  }

  /// Parsed NEET exam type enum
  NeetExamType get neetExamTypeEnum => NeetExamTypeExt.fromString(neetExamType);

  /// Parsed revision round enum
  RevisionRound get revisionRoundEnum => RevisionRoundExt.fromString(revisionRound);

  /// Parsed difficulty enum
  StudyDifficulty get difficultyEnum => StudyDifficultyExt.fromString(difficulty);

  /// Parsed study duration enum
  StudyDuration get studyDurationEnum => StudyDurationExt.fromString(studyDuration);

  /// Parsed study mode tags
  List<String> get studyModeTags {
    if (studyModeTagsJson == null || studyModeTagsJson!.isEmpty) return [];
    try {
      final list = jsonDecode(studyModeTagsJson!) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
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
    // NEET fields
    bool? isNeetExam,
    int? neetTotalMarks,
    bool clearNeetTotalMarks = false,
    int? neetTargetScore,
    bool clearNeetTargetScore = false,
    String? neetSubjectFocus,
    bool clearNeetSubjectFocus = false,
    // NEW UI NEET fields
    int? targetScore,
    bool clearTargetScore = false,
    String? neetExamType,
    bool clearNeetExamType = false,
    String? revisionRound,
    bool clearRevisionRound = false,
    bool? isPyqSession,
    // NEW working study features
    String? difficulty,
    bool clearDifficulty = false,
    String? studyDuration,
    bool clearStudyDuration = false,
    String? studyModeTagsJson,
    bool clearStudyModeTags = false,
    int? customSectionId,
    bool clearCustomSectionId = false,
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
      // NEET fields
      isNeetExam: isNeetExam ?? this.isNeetExam,
      neetTotalMarks: clearNeetTotalMarks ? null : (neetTotalMarks ?? this.neetTotalMarks),
      neetTargetScore: clearNeetTargetScore ? null : (neetTargetScore ?? this.neetTargetScore),
      neetSubjectFocus: clearNeetSubjectFocus ? null : (neetSubjectFocus ?? this.neetSubjectFocus),
      // NEW UI NEET fields
      targetScore: clearTargetScore ? null : (targetScore ?? this.targetScore),
      neetExamType: clearNeetExamType ? null : (neetExamType ?? this.neetExamType),
      revisionRound: clearRevisionRound ? null : (revisionRound ?? this.revisionRound),
      isPyqSession: isPyqSession ?? this.isPyqSession,
      // NEW working study features
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      studyDuration: clearStudyDuration ? null : (studyDuration ?? this.studyDuration),
      studyModeTagsJson: clearStudyModeTags ? null : (studyModeTagsJson ?? this.studyModeTagsJson),
      customSectionId: clearCustomSectionId ? null : (customSectionId ?? this.customSectionId),
    );
  }

  // ============================================
  // VALIDATION (FIXED for Issue 55)
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
    // FIX: Accept both int and bool for isCompleted (JSON compatibility)
    if (map['isCompleted'] != null && map['isCompleted'] is! int && map['isCompleted'] is! bool) {
      errors.add('"isCompleted" must be an int, bool, or null, got ${map['isCompleted'].runtimeType}');
    }
    // NEET fields validation
    if (map['isNeetExam'] != null && map['isNeetExam'] is! int && map['isNeetExam'] is! bool) {
      errors.add('"isNeetExam" must be an int, bool, or null, got ${map['isNeetExam'].runtimeType}');
    }
    if (map['neetTotalMarks'] != null && map['neetTotalMarks'] is! int) {
      errors.add('"neetTotalMarks" must be an int or null, got ${map['neetTotalMarks'].runtimeType}');
    }
    if (map['neetTargetScore'] != null && map['neetTargetScore'] is! int) {
      errors.add('"neetTargetScore" must be an int or null, got ${map['neetTargetScore'].runtimeType}');
    }
    if (map['neetSubjectFocus'] != null && map['neetSubjectFocus'] is! String) {
      errors.add('"neetSubjectFocus" must be a String or null, got ${map['neetSubjectFocus'].runtimeType}');
    }
    // NEW UI NEET fields validation
    if (map['targetScore'] != null && map['targetScore'] is! int) {
      errors.add('"targetScore" must be an int or null, got ${map['targetScore'].runtimeType}');
    }
    if (map['neetExamType'] != null && map['neetExamType'] is! String) {
      errors.add('"neetExamType" must be a String or null, got ${map['neetExamType'].runtimeType}');
    }
    if (map['revisionRound'] != null && map['revisionRound'] is! String) {
      errors.add('"revisionRound" must be a String or null, got ${map['revisionRound'].runtimeType}');
    }
    if (map['isPyqSession'] != null && map['isPyqSession'] is! int && map['isPyqSession'] is! bool) {
      errors.add('"isPyqSession" must be an int, bool, or null, got ${map['isPyqSession'].runtimeType}');
    }
    // NEW working study features validation
    if (map['difficulty'] != null && map['difficulty'] is! String) {
      errors.add('"difficulty" must be a String or null, got ${map['difficulty'].runtimeType}');
    }
    if (map['studyDuration'] != null && map['studyDuration'] is! String) {
      errors.add('"studyDuration" must be a String or null, got ${map['studyDuration'].runtimeType}');
    }
    if (map['studyModeTagsJson'] != null && map['studyModeTagsJson'] is! String) {
      errors.add('"studyModeTagsJson" must be a String or null, got ${map['studyModeTagsJson'].runtimeType}');
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
      // NEET fields
      'isNeetExam': isNeetExam ? 1 : 0,
      'neetTotalMarks': neetTotalMarks,
      'neetTargetScore': neetTargetScore,
      'neetSubjectFocus': neetSubjectFocus,
      // NEW UI NEET fields
      'targetScore': targetScore,
      'neetExamType': neetExamType,
      'revisionRound': revisionRound,
      'isPyqSession': isPyqSession ? 1 : 0,
      // NEW working study features
      'difficulty': difficulty,
      'studyDuration': studyDuration,
      'studyModeTagsJson': studyModeTagsJson,
      'customSectionId': customSectionId,
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
      isCompleted: _parseBool(map['isCompleted']),
      // NEET fields
      isNeetExam: _parseBool(map['isNeetExam']),
      neetTotalMarks: map['neetTotalMarks'] as int?,
      neetTargetScore: map['neetTargetScore'] as int?,
      neetSubjectFocus: map['neetSubjectFocus'] as String?,
      // NEW UI NEET fields
      targetScore: map['targetScore'] as int?,
      neetExamType: map['neetExamType'] as String?,
      revisionRound: map['revisionRound'] as String?,
      isPyqSession: _parseBool(map['isPyqSession']),
      // NEW working study features
      difficulty: map['difficulty'] as String?,
      studyDuration: map['studyDuration'] as String?,
      studyModeTagsJson: map['studyModeTagsJson'] as String?,
      customSectionId: map['customSectionId'] as int?,
    );
  }

  /// Safely parse int/bool to bool
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    return false;
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
