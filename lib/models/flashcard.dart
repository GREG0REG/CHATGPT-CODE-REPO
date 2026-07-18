/// A simple Q&A card for active recall.
/// boxLevel 1-5 implements a lightweight spaced-repetition ladder.
class Flashcard {
  final int? id;
  final String subjectTag;
  final String frontText;
  final String backText;
  final int boxLevel; // 1..5
  final int? lastReviewedMillis;
  final int? nextReviewMillis;

  const Flashcard({
    this.id,
    required this.subjectTag,
    required this.frontText,
    required this.backText,
    this.boxLevel = 1,
    this.lastReviewedMillis,
    this.nextReviewMillis,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectTag': subjectTag,
      'frontText': frontText,
      'backText': backText,
      'boxLevel': boxLevel.clamp(1, 5),
      'lastReviewedMillis': lastReviewedMillis,
      'nextReviewMillis': nextReviewMillis,
    };
  }

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] as int?,
      subjectTag: map['subjectTag'] as String,
      frontText: map['frontText'] as String,
      backText: map['backText'] as String,
      boxLevel: (map['boxLevel'] as int?)?.clamp(1, 5) ?? 1,
      lastReviewedMillis: map['lastReviewedMillis'] as int?,
      nextReviewMillis: map['nextReviewMillis'] as int?,
    );
  }

  Flashcard copyWith({
    int? id,
    String? subjectTag,
    String? frontText,
    String? backText,
    int? boxLevel,
    int? lastReviewedMillis,
    int? nextReviewMillis,
  }) {
    return Flashcard(
      id: id ?? this.id,
      subjectTag: subjectTag ?? this.subjectTag,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      boxLevel: boxLevel ?? this.boxLevel,
      lastReviewedMillis: lastReviewedMillis ?? this.lastReviewedMillis,
      nextReviewMillis: nextReviewMillis ?? this.nextReviewMillis,
    );
  }
}
