/// Represents a study goal for a specific subject or overall.
/// Used for tracking progress in stats screen progress rings.
class StudyGoal {
  final int? id;
  final String subjectTag;      // 'Math', 'Physics', 'General', etc.
  final int targetMinutes;      // Weekly target in minutes (default 120 = 2hrs)
  final int targetPomodoros;    // Weekly pomodoro target (optional)
  final int createdAtMillis;
  final bool isActive;

  const StudyGoal({
    this.id,
    required this.subjectTag,
    this.targetMinutes = 120,
    this.targetPomodoros = 0,
    required this.createdAtMillis,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectTag': subjectTag,
      'targetMinutes': targetMinutes,
      'targetPomodoros': targetPomodoros,
      'createdAtMillis': createdAtMillis,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory StudyGoal.fromMap(Map<String, dynamic> map) {
    return StudyGoal(
      id: map['id'] as int?,
      subjectTag: map['subjectTag'] as String,
      targetMinutes: map['targetMinutes'] as int? ?? 120,
      targetPomodoros: map['targetPomodoros'] as int? ?? 0,
      createdAtMillis: map['createdAtMillis'] as int,
      isActive: (map['isActive'] as int?) == 1,
    );
  }

  StudyGoal copyWith({
    int? id,
    String? subjectTag,
    int? targetMinutes,
    int? targetPomodoros,
    int? createdAtMillis,
    bool? isActive,
  }) {
    return StudyGoal(
      id: id ?? this.id,
      subjectTag: subjectTag ?? this.subjectTag,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      targetPomodoros: targetPomodoros ?? this.targetPomodoros,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Calculate progress percentage (0.0 to 1.0+)
  double progressPercent(int achievedMinutes) {
    if (targetMinutes <= 0) return 0.0;
    return (achievedMinutes / targetMinutes).clamp(0.0, 1.0);
  }

  /// Check if goal is achieved
  bool isAchieved(int achievedMinutes) {
    return achievedMinutes >= targetMinutes;
  }

  @override
  String toString() {
    return 'StudyGoal(subject: $subjectTag, target: ${targetMinutes}min)';
  }
}
