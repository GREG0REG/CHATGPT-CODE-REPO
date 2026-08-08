class SyllabusRevisionSchedule {
  final int? id;
  final int topicId;
  final int revisionNumber; // 1,2,3,...
  final int scheduledDateMillis;
  final int isCompleted;
  final int? performanceScore; // 1-10 self-rated understanding
  final int? actualRevisionDateMillis; // when user actually revised
  final String? notes;
  final int createdAtMillis;

  SyllabusRevisionSchedule({
    this.id,
    required this.topicId,
    required this.revisionNumber,
    required this.scheduledDateMillis,
    this.isCompleted = 0,
    this.performanceScore,
    this.actualRevisionDateMillis,
    this.notes,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'topicId': topicId,
        'revisionNumber': revisionNumber,
        'scheduledDateMillis': scheduledDateMillis,
        'isCompleted': isCompleted,
        'performanceScore': performanceScore,
        'actualRevisionDateMillis': actualRevisionDateMillis,
        'notes': notes,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusRevisionSchedule.fromMap(Map<String, dynamic> map) =>
      SyllabusRevisionSchedule(
        id: map['id'] as int?,
        topicId: map['topicId'] as int,
        revisionNumber: map['revisionNumber'] as int,
        scheduledDateMillis: map['scheduledDateMillis'] as int,
        isCompleted: map['isCompleted'] as int? ?? 0,
        performanceScore: map['performanceScore'] as int?,
        actualRevisionDateMillis: map['actualRevisionDateMillis'] as int?,
        notes: map['notes'] as String?,
        createdAtMillis: map['createdAtMillis'] as int,
      );

  bool get completed => isCompleted == 1;

  SyllabusRevisionSchedule copyWith({
    int? id,
    int? topicId,
    int? revisionNumber,
    int? scheduledDateMillis,
    int? isCompleted,
    int? performanceScore,
    int? actualRevisionDateMillis,
    String? notes,
    int? createdAtMillis,
  }) {
    return SyllabusRevisionSchedule(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      scheduledDateMillis: scheduledDateMillis ?? this.scheduledDateMillis,
      isCompleted: isCompleted ?? this.isCompleted,
      performanceScore: performanceScore ?? this.performanceScore,
      actualRevisionDateMillis: actualRevisionDateMillis ?? this.actualRevisionDateMillis,
      notes: notes ?? this.notes,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }
}
