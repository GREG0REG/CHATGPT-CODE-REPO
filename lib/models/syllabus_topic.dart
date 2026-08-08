enum TopicStatus { notStarted, inProgress, completed, needsRevision }
enum StudyDifficulty { easy, medium, hard }

class SyllabusTopic {
  final int? id;
  final int unitId;
  final String name;
  final int orderIndex;
  final String status;
  final String? difficulty;
  final int? estimatedMinutes;
  final int createdAtMillis;

  SyllabusTopic({
    this.id,
    required this.unitId,
    required this.name,
    this.orderIndex = 0,
    this.status = 'notStarted',
    this.difficulty,
    this.estimatedMinutes,
    required this.createdAtMillis,
  });

  SyllabusTopic copyWith({
    int? id,
    int? unitId,
    String? name,
    int? orderIndex,
    String? status,
    String? difficulty,
    int? estimatedMinutes,
    int? createdAtMillis,
  }) => SyllabusTopic(
    id: id ?? this.id,
    unitId: unitId ?? this.unitId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    status: status ?? this.status,
    difficulty: difficulty ?? this.difficulty,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );

  TopicStatus get statusEnum => TopicStatus.values.firstWhere(
    (e) => e.name == status,
    orElse: () => TopicStatus.notStarted,
  );

  StudyDifficulty? get difficultyEnum => difficulty != null 
    ? StudyDifficulty.values.firstWhere((e) => e.name == difficulty, orElse: () => StudyDifficulty.medium)
    : null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'unitId': unitId,
    'name': name,
    'orderIndex': orderIndex,
    'status': status,
    'difficulty': difficulty,
    'estimatedMinutes': estimatedMinutes,
    'createdAtMillis': createdAtMillis,
  };

  factory SyllabusTopic.fromMap(Map<String, dynamic> map) => SyllabusTopic(
    id: map['id'] as int?,
    unitId: map['unitId'] as int,
    name: map['name'] as String,
    orderIndex: map['orderIndex'] as int? ?? 0,
    status: map['status'] as String? ?? 'notStarted',
    difficulty: map['difficulty'] as String?,
    estimatedMinutes: map['estimatedMinutes'] as int?,
    createdAtMillis: map['createdAtMillis'] as int,
  );
}
