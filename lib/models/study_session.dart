/// A logged study session from the Pomodoro timer.
class StudySession {
  final int? id;
  final int? eventId;          // optional link to an event
  final String? subjectTag;    // e.g. "Math", "Physics"
  final int durationMinutes;   // actual focused minutes
  final int completedAtMillis; // timestamp
  final String sessionType;    // 'pomodoro', 'deep_work', 'exam_crunch', 'custom'

  const StudySession({
    this.id,
    this.eventId,
    this.subjectTag,
    required this.durationMinutes,
    required this.completedAtMillis,
    this.sessionType = 'pomodoro',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'subjectTag': subjectTag,
      'durationMinutes': durationMinutes,
      'completedAtMillis': completedAtMillis,
      'sessionType': sessionType,
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
    );
  }

  StudySession copyWith({
    int? id,
    int? eventId,
    String? subjectTag,
    int? durationMinutes,
    int? completedAtMillis,
    String? sessionType,
  }) {
    return StudySession(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      subjectTag: subjectTag ?? this.subjectTag,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completedAtMillis: completedAtMillis ?? this.completedAtMillis,
      sessionType: sessionType ?? this.sessionType,
    );
  }
}
