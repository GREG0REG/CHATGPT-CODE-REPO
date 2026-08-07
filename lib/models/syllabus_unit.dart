class SyllabusUnit {
  final int? id;
  final int subjectId;
  final String name;
  final int orderIndex;
  final int? weightage;
  final int createdAtMillis;

  SyllabusUnit({
    this.id,
    required this.subjectId,
    required this.name,
    this.orderIndex = 0,
    this.weightage,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'subjectId': subjectId,
        'name': name,
        'orderIndex': orderIndex,
        'weightage': weightage,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusUnit.fromMap(Map<String, dynamic> map) => SyllabusUnit(
        id: map['id'] as int?,
        subjectId: map['subjectId'] as int,
        name: map['name'] as String,
        orderIndex: map['orderIndex'] as int? ?? 0,
        weightage: map['weightage'] as int?,
        createdAtMillis: map['createdAtMillis'] as int,
      );
}
