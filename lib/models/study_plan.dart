class StudyPlan {
  final int? id;
  final String name;
  final int? eventId;
  final int? subjectId;
  final int startDateMillis;
  final int endDateMillis;
  final int dailyStudyMinutes;
  final int isActive;
  final int createdAtMillis;

  StudyPlan({
    this.id,
    required this.name,
    this.eventId,
    this.subjectId,
    required this.startDateMillis,
    required this.endDateMillis,
    this.dailyStudyMinutes = 120,
    this.isActive = 1,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'eventId': eventId,
        'subjectId': subjectId,
        'startDateMillis': startDateMillis,
        'endDateMillis': endDateMillis,
        'dailyStudyMinutes': dailyStudyMinutes,
        'isActive': isActive,
        'createdAtMillis': createdAtMillis,
      };

  factory StudyPlan.fromMap(Map<String, dynamic> map) => StudyPlan(
        id: map['id'] as int?,
        name: map['name'] as String,
        eventId: map['eventId'] as int?,
        subjectId: map['subjectId'] as int?,
        startDateMillis: map['startDateMillis'] as int,
        endDateMillis: map['endDateMillis'] as int,
        dailyStudyMinutes: map['dailyStudyMinutes'] as int? ?? 120,
        isActive: map['isActive'] as int? ?? 1,
        createdAtMillis: map['createdAtMillis'] as int,
      );

  bool get active => isActive == 1;
}
