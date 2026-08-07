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

  // ─── copyWith method ───
  SyllabusSubtopic copyWith({
    int? id,
    int? topicId,
    String? name,
    int? orderIndex,
    String? status,
    String? notes,
    int? createdAtMillis,
  }) {
    return SyllabusSubtopic(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }

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
