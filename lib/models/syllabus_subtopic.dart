class SyllabusSubtopic {
  final int? id;
  final int topicId;
  final String name;
  final int orderIndex;
  final String status;
  final String? notes;
  final int createdAtMillis;

  SyllabusSubtopic({
    this.id,
    required this.topicId,
    required this.name,
    this.orderIndex = 0,
    this.status = 'notStarted',
    this.notes,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'topicId': topicId,
        'name': name,
        'orderIndex': orderIndex,
        'status': status,
        'notes': notes,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusSubtopic.fromMap(Map<String, dynamic> map) => SyllabusSubtopic(
        id: map['id'] as int?,
        topicId: map['topicId'] as int,
        name: map['name'] as String,
        orderIndex: map['orderIndex'] as int? ?? 0,
        status: map['status'] as String? ?? 'notStarted',
        notes: map['notes'] as String?,
        createdAtMillis: map['createdAtMillis'] as int,
      );
}
