// CHATGPT-CODE-REPO-TEST/lib/models/daily_card_goal.dart
// NEW FILE - Daily flashcard review goal tracking

/// Tracks daily flashcard review targets and progress.
class DailyCardGoal {
  final int? id;
  final int dateMillis; // start of day (00:00)
  final int targetReviews;
  final int achievedReviews;
  final int targetNewCards;
  final int achievedNewCards;
  final int streakCount;

  const DailyCardGoal({
    this.id,
    required this.dateMillis,
    this.targetReviews = 20,
    this.achievedReviews = 0,
    this.targetNewCards = 5,
    this.achievedNewCards = 0,
    this.streakCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateMillis': dateMillis,
      'targetReviews': targetReviews,
      'achievedReviews': achievedReviews,
      'targetNewCards': targetNewCards,
      'achievedNewCards': achievedNewCards,
      'streakCount': streakCount,
    };
  }

  factory DailyCardGoal.fromMap(Map<String, dynamic> map) {
    return DailyCardGoal(
      id: map['id'] as int?,
      dateMillis: map['dateMillis'] as int,
      targetReviews: map['targetReviews'] as int? ?? 20,
      achievedReviews: map['achievedReviews'] as int? ?? 0,
      targetNewCards: map['targetNewCards'] as int? ?? 5,
      achievedNewCards: map['achievedNewCards'] as int? ?? 0,
      streakCount: map['streakCount'] as int? ?? 0,
    );
  }

  DailyCardGoal copyWith({
    int? id,
    int? dateMillis,
    int? targetReviews,
    int? achievedReviews,
    int? targetNewCards,
    int? achievedNewCards,
    int? streakCount,
  }) {
    return DailyCardGoal(
      id: id ?? this.id,
      dateMillis: dateMillis ?? this.dateMillis,
      targetReviews: targetReviews ?? this.targetReviews,
      achievedReviews: achievedReviews ?? this.achievedReviews,
      targetNewCards: targetNewCards ?? this.targetNewCards,
      achievedNewCards: achievedNewCards ?? this.achievedNewCards,
      streakCount: streakCount ?? this.streakCount,
    );
  }

  double get reviewProgressRatio {
    if (targetReviews <= 0) return 0;
    final ratio = achievedReviews / targetReviews;
    return ratio.clamp(0.0, 1.0);
  }

  double get newCardProgressRatio {
    if (targetNewCards <= 0) return 0;
    final ratio = achievedNewCards / targetNewCards;
    return ratio.clamp(0.0, 1.0);
  }

  bool get isReviewGoalMet => achievedReviews >= targetReviews;
  bool get isNewCardGoalMet => achievedNewCards >= targetNewCards;
  bool get isFullyComplete => isReviewGoalMet && isNewCardGoalMet;
}
