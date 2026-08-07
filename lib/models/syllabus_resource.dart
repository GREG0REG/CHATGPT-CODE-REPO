class SyllabusResource {
  final int? id;
  final int? topicId;
  final int? subtopicId;
  final String resourceType; // 'file', 'link', etc.
  final String title;
  final String? filePath;
  final String? url;
  final int createdAtMillis;

  SyllabusResource({
    this.id,
    this.topicId,
    this.subtopicId,
    required this.resourceType,
    required this.title,
    this.filePath,
    this.url,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'topicId': topicId,
        'subtopicId': subtopicId,
        'resourceType': resourceType,
        'title': title,
        'filePath': filePath,
        'url': url,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusResource.fromMap(Map<String, dynamic> map) => SyllabusResource(
        id: map['id'] as int?,
        topicId: map['topicId'] as int?,
        subtopicId: map['subtopicId'] as int?,
        resourceType: map['resourceType'] as String,
        title: map['title'] as String,
        filePath: map['filePath'] as String?,
        url: map['url'] as String?,
        createdAtMillis: map['createdAtMillis'] as int,
      );
}
