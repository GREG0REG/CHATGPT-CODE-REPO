/// A checklist item tied to an event.
class Subtask {
  final int? id;
  final int eventId;
  final String title;
  final bool isCompleted;
  final int orderIndex;

  const Subtask({
    this.id,
    required this.eventId,
    required this.title,
    this.isCompleted = false,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'orderIndex': orderIndex,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as int?,
      eventId: map['eventId'] as int,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      orderIndex: map['orderIndex'] as int? ?? 0,
    );
  }

  Subtask copyWith({
    int? id,
    int? eventId,
    String? title,
    bool? isCompleted,
    int? orderIndex,
  }) {
    return Subtask(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
