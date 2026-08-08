class SyllabusRevisionSchedule {
  final int? id;
  final int topicId;
  final int revisionNumber; // 1,2,3,...
  final int scheduledDateMillis;
  final int isCompleted;
  final int createdAtMillis;

  SyllabusRevisionSchedule({
    this.id,
    required this.topicId,
    required this.revisionNumber,
    required this.scheduledDateMillis,
    this.isCompleted = 0,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'topicId': topicId,
        'revisionNumber': revisionNumber,
        'scheduledDateMillis': scheduledDateMillis,
        'isCompleted': isCompleted,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusRevisionSchedule.fromMap(Map<String, dynamic> map) =>
      SyllabusRevisionSchedule(
        id: map['id'] as int?,
        topicId: map['topicId'] as int,
        revisionNumber: map['revisionNumber'] as int,
        scheduledDateMillis: map['scheduledDateMillis'] as int,
        isCompleted: map['isCompleted'] as int? ?? 0,
        createdAtMillis: map['createdAtMillis'] as int,
      );

  bool get completed => isCompleted == 1;

  SyllabusRevisionSchedule copyWith({
    int? id,
    int? topicId,
    int? revisionNumber,
    int? scheduledDateMillis,
    int? isCompleted,
    int? createdAtMillis,
  }) {
    return SyllabusRevisionSchedule(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      scheduledDateMillis: scheduledDateMillis ?? this.scheduledDateMillis,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }
}
