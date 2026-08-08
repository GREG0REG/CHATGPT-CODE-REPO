class StudyPlan {
  final int? id;
  final String name;
  final int? eventId;
  final int? subjectId;
  final int startDateMillis;
  final int endDateMillis;
  final int dailyStudyMinutes;
  final int isActive;
  final int priority; // 1 = high, 2 = medium, 3 = low
  final String? strategy; // 'balanced', 'hardFirst', 'easyFirst', 'marksWeighted'
  final int bufferDays;
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
    this.priority = 2,
    this.strategy = 'balanced',
    this.bufferDays = 7,
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
        'priority': priority,
        'strategy': strategy,
        'bufferDays': bufferDays,
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
        priority: map['priority'] as int? ?? 2,
        strategy: map['strategy'] as String? ?? 'balanced',
        bufferDays: map['bufferDays'] as int? ?? 7,
        createdAtMillis: map['createdAtMillis'] as int,
      );

  bool get active => isActive == 1;

  StudyPlan copyWith({
    int? id,
    String? name,
    int? eventId,
    int? subjectId,
    int? startDateMillis,
    int? endDateMillis,
    int? dailyStudyMinutes,
    int? isActive,
    int? priority,
    String? strategy,
    int? bufferDays,
    int? createdAtMillis,
  }) => StudyPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    eventId: eventId ?? this.eventId,
    subjectId: subjectId ?? this.subjectId,
    startDateMillis: startDateMillis ?? this.startDateMillis,
    endDateMillis: endDateMillis ?? this.endDateMillis,
    dailyStudyMinutes: dailyStudyMinutes ?? this.dailyStudyMinutes,
    isActive: isActive ?? this.isActive,
    priority: priority ?? this.priority,
    strategy: strategy ?? this.strategy,
    bufferDays: bufferDays ?? this.bufferDays,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );
}
