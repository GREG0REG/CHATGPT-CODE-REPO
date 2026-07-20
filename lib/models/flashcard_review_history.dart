// CHATGPT-CODE-REPO-TEST/lib/models/flashcard_review_history.dart
// NEW FILE - Tracks every review attempt for analytics

/// A single review attempt on a flashcard.
/// Stored in a separate table for efficient querying and analytics.
class FlashcardReviewHistory {
  final int? id;
  final int cardId;
  final int reviewedAtMillis;
  final String difficulty; // 'again', 'hard', 'good', 'easy'
  final int timeSpentSeconds; // How long user looked at card
  final int boxLevelBefore;
  final int boxLevelAfter;
  final String? sessionId; // Groups reviews from same study session

  const FlashcardReviewHistory({
    this.id,
    required this.cardId,
    required this.reviewedAtMillis,
    required this.difficulty,
    required this.timeSpentSeconds,
    required this.boxLevelBefore,
    required this.boxLevelAfter,
    this.sessionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cardId': cardId,
      'reviewedAtMillis': reviewedAtMillis,
      'difficulty': difficulty,
      'timeSpentSeconds': timeSpentSeconds,
      'boxLevelBefore': boxLevelBefore,
      'boxLevelAfter': boxLevelAfter,
      'sessionId': sessionId,
    };
  }

  factory FlashcardReviewHistory.fromMap(Map<String, dynamic> map) {
    return FlashcardReviewHistory(
      id: map['id'] as int?,
      cardId: map['cardId'] as int,
      reviewedAtMillis: map['reviewedAtMillis'] as int,
      difficulty: map['difficulty'] as String,
      timeSpentSeconds: map['timeSpentSeconds'] as int,
      boxLevelBefore: map['boxLevelBefore'] as int,
      boxLevelAfter: map['boxLevelAfter'] as int,
      sessionId: map['sessionId'] as String?,
    );
  }

  FlashcardReviewHistory copyWith({
    int? id,
    int? cardId,
    int? reviewedAtMillis,
    String? difficulty,
    int? timeSpentSeconds,
    int? boxLevelBefore,
    int? boxLevelAfter,
    String? sessionId,
  }) {
    return FlashcardReviewHistory(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      reviewedAtMillis: reviewedAtMillis ?? this.reviewedAtMillis,
      difficulty: difficulty ?? this.difficulty,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      boxLevelBefore: boxLevelBefore ?? this.boxLevelBefore,
      boxLevelAfter: boxLevelAfter ?? this.boxLevelAfter,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  /// Get accuracy score: easy=1.0, good=0.75, hard=0.5, again=0.0
  double get accuracyScore {
    switch (difficulty) {
      case 'easy': return 1.0;
      case 'good': return 0.75;
      case 'hard': return 0.5;
      case 'again': return 0.0;
      default: return 0.5;
    }
  }

  DateTime get reviewedAt => DateTime.fromMillisecondsSinceEpoch(reviewedAtMillis);
}
