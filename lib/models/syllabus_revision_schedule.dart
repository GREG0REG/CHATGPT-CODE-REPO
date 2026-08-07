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
}
