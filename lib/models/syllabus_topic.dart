enum TopicStatus { notStarted, inProgress, completed, needsRevision }

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

  TopicStatus get statusEnum =>
      TopicStatus.values.firstWhere((e) => e.name == status, orElse: () => TopicStatus.notStarted);
}
