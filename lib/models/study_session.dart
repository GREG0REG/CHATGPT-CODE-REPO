// FILE: lib/models/study_session.dart
// COMPLETE REPLACEMENT — NEET Edition v16
// Added: neetSubject, mcqsAttempted, mcqsCorrect, difficultyLevel, revisionRound
// NEET subjects: Physics (180 marks), Chemistry (180 marks), Biology (360 marks)

/// Difficulty level for NEET study sessions.
enum DifficultyLevel {
  easy,
  medium,
  hard,
}

/// NEET subject categories.
enum NeetSubject {
  physics,
  chemistry,
  biology,
  general,
}

/// Revision round tracking for NEET prep.
/// Round 1 = First reading, Round 2 = Revision, Round 3 = Final revision
enum RevisionRound {
  firstReading,    // Initial concept learning
  revision,        // Second pass
  finalRevision,   // Third pass before exam
  mockTest,        // During mock test practice
  doubtClearing,   // Focused doubt solving
}

/// A logged study session from the Pomodoro/timer.
class StudySession {
  final int? id;
  final int? eventId;          // optional link to an event
  final String? subjectTag;    // e.g. "Math", "Physics" (legacy)
  final int durationMinutes;   // actual focused minutes
  final int completedAtMillis; // timestamp
  final String sessionType;    // 'pomodoro', 'deep_work', 'exam_crunch', 'custom', 'neet_revision', 'neet_deep', 'neet_sprint', 'neet_mock', 'neet_doubt'
  final String? notes;         // session notes
  final int distractionCount;  // distractions logged during session
  final int intensityRating;   // 1-5 focus quality rating
  final String? topicTag;      // specific topic within subject

  // ── NEW: NEET-specific fields ──
  final NeetSubject? neetSubject;      // Physics / Chemistry / Biology / General
  final int mcqsAttempted;             // MCQs solved in this session
  final int mcqsCorrect;               // Correct MCQs
  final DifficultyLevel difficultyLevel; // Easy / Medium / Hard
  final RevisionRound revisionRound;   // Which revision cycle
  final int? mockTestScore;            // Score if this was a mock test session (out of 720)
  final int? mockTestRank;             // Rank in mock test (optional)


    // ── Timer-linked fields ──
  final int? topicId;           // linked syllabus topic
  final int? planItemId;        // linked study plan item
  final int? startTimeMillis;   // session start timestamp
  final int? endTimeMillis;     // session end timestamp
  final int? productivity;      // 1-10 productivity score


  const StudySession({
    this.id,
    this.eventId,
    this.subjectTag,
    required this.durationMinutes,
    required this.completedAtMillis,
    this.sessionType = 'pomodoro',
    this.notes,
    this.distractionCount = 0,
    this.intensityRating = 0,
    this.topicTag,
    // NEET fields
    this.neetSubject,
    this.mcqsAttempted = 0,
    this.mcqsCorrect = 0,
    this.difficultyLevel = DifficultyLevel.medium,
    this.revisionRound = RevisionRound.firstReading,
    this.mockTestScore,
    this.mockTestRank,
  });

  /// Calculate MCQ accuracy percentage (0-100)
  double get mcqAccuracyPercent {
    if (mcqsAttempted == 0) return 0.0;
    return (mcqsCorrect / mcqsAttempted * 100).clamp(0.0, 100.0);
  }

  /// Get NEET subject marks weight
  int get neetSubjectMarks {
    switch (neetSubject) {
      case NeetSubject.physics: return 180;
      case NeetSubject.chemistry: return 180;
      case NeetSubject.biology: return 360;
      case NeetSubject.general:
      case null:
        return 0;
    }
  }

  /// Check if this is a NEET-specific session type
  bool get isNeetSession {
    return sessionType.startsWith('neet_') || neetSubject != null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'subjectTag': subjectTag,
      'durationMinutes': durationMinutes,
      'completedAtMillis': completedAtMillis,
      'sessionType': sessionType,
      'notes': notes,
      'distractionCount': distractionCount,
      'intensityRating': intensityRating,
      'topicTag': topicTag,
      // NEET fields
      'neetSubject': neetSubject?.index,
      'mcqsAttempted': mcqsAttempted,
      'mcqsCorrect': mcqsCorrect,
      'difficultyLevel': difficultyLevel.index,
      'revisionRound': revisionRound.index,
      'mockTestScore': mockTestScore,
      'mockTestRank': mockTestRank,
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      eventId: map['eventId'] as int?,
      subjectTag: map['subjectTag'] as String?,
      durationMinutes: map['durationMinutes'] as int,
      completedAtMillis: map['completedAtMillis'] as int,
      sessionType: map['sessionType'] as String? ?? 'pomodoro',
      notes: map['notes'] as String?,
      distractionCount: map['distractionCount'] as int? ?? 0,
      intensityRating: map['intensityRating'] as int? ?? 0,
      topicTag: map['topicTag'] as String?,
      // NEET fields with safe defaults
      neetSubject: map['neetSubject'] != null
          ? NeetSubject.values[(map['neetSubject'] as int).clamp(0, NeetSubject.values.length - 1)]
          : null,
      mcqsAttempted: map['mcqsAttempted'] as int? ?? 0,
      mcqsCorrect: map['mcqsCorrect'] as int? ?? 0,
      difficultyLevel: map['difficultyLevel'] != null
          ? DifficultyLevel.values[(map['difficultyLevel'] as int).clamp(0, DifficultyLevel.values.length - 1)]
          : DifficultyLevel.medium,
      revisionRound: map['revisionRound'] != null
          ? RevisionRound.values[(map['revisionRound'] as int).clamp(0, RevisionRound.values.length - 1)]
          : RevisionRound.firstReading,
      mockTestScore: map['mockTestScore'] as int?,
      mockTestRank: map['mockTestRank'] as int?,
    );
  }

  StudySession copyWith({
    int? id,
    int? eventId,
    String? subjectTag,
    int? durationMinutes,
    int? completedAtMillis,
    String? sessionType,
    String? notes,
    int? distractionCount,
    int? intensityRating,
    String? topicTag,
    bool clearNotes = false,
    // NEET fields
    NeetSubject? neetSubject,
    bool clearNeetSubject = false,
    int? mcqsAttempted,
    int? mcqsCorrect,
    DifficultyLevel? difficultyLevel,
    RevisionRound? revisionRound,
    int? mockTestScore,
    bool clearMockTestScore = false,
    int? mockTestRank,
    bool clearMockTestRank = false,
  }) {
    return StudySession(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      subjectTag: subjectTag ?? this.subjectTag,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completedAtMillis: completedAtMillis ?? this.completedAtMillis,
      sessionType: sessionType ?? this.sessionType,
      notes: clearNotes ? null : (notes ?? this.notes),
      distractionCount: distractionCount ?? this.distractionCount,
      intensityRating: intensityRating ?? this.intensityRating,
      topicTag: topicTag ?? this.topicTag,
      // NEET fields
      neetSubject: clearNeetSubject ? null : (neetSubject ?? this.neetSubject),
      mcqsAttempted: mcqsAttempted ?? this.mcqsAttempted,
      mcqsCorrect: mcqsCorrect ?? this.mcqsCorrect,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      revisionRound: revisionRound ?? this.revisionRound,
      mockTestScore: clearMockTestScore ? null : (mockTestScore ?? this.mockTestScore),
      mockTestRank: clearMockTestRank ? null : (mockTestRank ?? this.mockTestRank),
    );
  }

  @override
  String toString() {
    return 'StudySession(id: $id, subject: $neetSubject, duration: ${durationMinutes}min, '
        'mcqs: $mcqsCorrect/$mcqsAttempted, accuracy: ${mcqAccuracyPercent.toStringAsFixed(1)}%)';
  }
}
