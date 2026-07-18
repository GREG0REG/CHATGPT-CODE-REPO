/// Tracks daily study targets and streaks.
class DailyGoal {
  final int? id;
  final int dateMillis; // start of day (00:00)
  final int targetMinutes;
  final int targetPomodoros;
  final int achievedMinutes;
  final int achievedPomodoros;
  final int streakCount;

  const DailyGoal({
    this.id,
    required this.dateMillis,
    this.targetMinutes = 120,
    this.targetPomodoros = 4,
    this.achievedMinutes = 0,
    this.achievedPomodoros = 0,
    this.streakCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateMillis': dateMillis,
      'targetMinutes': targetMinutes,
      'targetPomodoros': targetPomodoros,
      'achievedMinutes': achievedMinutes,
      'achievedPomodoros': achievedPomodoros,
      'streakCount': streakCount,
    };
  }

  factory DailyGoal.fromMap(Map<String, dynamic> map) {
    return DailyGoal(
      id: map['id'] as int?,
      dateMillis: map['dateMillis'] as int,
      targetMinutes: map['targetMinutes'] as int? ?? 120,
      targetPomodoros: map['targetPomodoros'] as int? ?? 4,
      achievedMinutes: map['achievedMinutes'] as int? ?? 0,
      achievedPomodoros: map['achievedPomodoros'] as int? ?? 0,
      streakCount: map['streakCount'] as int? ?? 0,
    );
  }

  DailyGoal copyWith({
    int? id,
    int? dateMillis,
    int? targetMinutes,
    int? targetPomodoros,
    int? achievedMinutes,
    int? achievedPomodoros,
    int? streakCount,
  }) {
    return DailyGoal(
      id: id ?? this.id,
      dateMillis: dateMillis ?? this.dateMillis,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      targetPomodoros: targetPomodoros ?? this.targetPomodoros,
      achievedMinutes: achievedMinutes ?? this.achievedMinutes,
      achievedPomodoros: achievedPomodoros ?? this.achievedPomodoros,
      streakCount: streakCount ?? this.streakCount,
    );
  }

  double get progressRatio {
    if (targetMinutes <= 0) return 0;
    final ratio = achievedMinutes / targetMinutes;
    return ratio.clamp(0.0, 1.0);
  }

  bool get isCompleted => achievedMinutes >= targetMinutes;
}
