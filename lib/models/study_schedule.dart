/// An auto-generated study suggestion linked to an event or subject.
class StudySchedule {
  final int? id;
  final int? eventId;
  final String? subjectTag;
  final int suggestedDateMillis;
  final int suggestedDurationMinutes;
  final bool isCompleted;
  final bool isAccepted; // user said "yes" to this suggestion

  const StudySchedule({
    this.id,
    this.eventId,
    this.subjectTag,
    required this.suggestedDateMillis,
    this.suggestedDurationMinutes = 25,
    this.isCompleted = false,
    this.isAccepted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'subjectTag': subjectTag,
      'suggestedDateMillis': suggestedDateMillis,
      'suggestedDurationMinutes': suggestedDurationMinutes,
      'isCompleted': isCompleted ? 1 : 0,
      'isAccepted': isAccepted ? 1 : 0,
    };
  }

  factory StudySchedule.fromMap(Map<String, dynamic> map) {
    return StudySchedule(
      id: map['id'] as int?,
      eventId: map['eventId'] as int?,
      subjectTag: map['subjectTag'] as String?,
      suggestedDateMillis: map['suggestedDateMillis'] as int,
      suggestedDurationMinutes: map['suggestedDurationMinutes'] as int? ?? 25,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      isAccepted: (map['isAccepted'] as int? ?? 0) == 1,
    );
  }

  StudySchedule copyWith({
    int? id,
    int? eventId,
    String? subjectTag,
    int? suggestedDateMillis,
    int? suggestedDurationMinutes,
    bool? isCompleted,
    bool? isAccepted,
  }) {
    return StudySchedule(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      subjectTag: subjectTag ?? this.subjectTag,
      suggestedDateMillis: suggestedDateMillis ?? this.suggestedDateMillis,
      suggestedDurationMinutes: suggestedDurationMinutes ?? this.suggestedDurationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      isAccepted: isAccepted ?? this.isAccepted,
    );
  }
}
