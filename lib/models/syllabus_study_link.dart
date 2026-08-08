class SyllabusStudyLink {
  final int? id;
  final int topicId;
  final int studySessionId;
  final int createdAtMillis;

  SyllabusStudyLink({
    this.id,
    required this.topicId,
    required this.studySessionId,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'topicId': topicId,
        'studySessionId': studySessionId,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusStudyLink.fromMap(Map<String, dynamic> map) => SyllabusStudyLink(
        id: map['id'] as int?,
        topicId: map['topicId'] as int,
        studySessionId: map['studySessionId'] as int,
        createdAtMillis: map['createdAtMillis'] as int,
      );
}
