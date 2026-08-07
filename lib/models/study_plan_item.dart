class StudyPlanItem {
  final int? id;
  final int planId;
  final int? topicId;
  final int scheduledDateMillis;
  final int allocatedMinutes;
  final int isCompleted;
  final String? notes;
  final int createdAtMillis;

  StudyPlanItem({
    this.id,
    required this.planId,
    this.topicId,
    required this.scheduledDateMillis,
    this.allocatedMinutes = 60,
    this.isCompleted = 0,
    this.notes,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'planId': planId,
        'topicId': topicId,
        'scheduledDateMillis': scheduledDateMillis,
        'allocatedMinutes': allocatedMinutes,
        'isCompleted': isCompleted,
        'notes': notes,
        'createdAtMillis': createdAtMillis,
      };

  factory StudyPlanItem.fromMap(Map<String, dynamic> map) => StudyPlanItem(
        id: map['id'] as int?,
        planId: map['planId'] as int,
        topicId: map['topicId'] as int?,
        scheduledDateMillis: map['scheduledDateMillis'] as int,
        allocatedMinutes: map['allocatedMinutes'] as int? ?? 60,
        isCompleted: map['isCompleted'] as int? ?? 0,
        notes: map['notes'] as String?,
        createdAtMillis: map['createdAtMillis'] as int,
      );

  bool get completed => isCompleted == 1;
}
