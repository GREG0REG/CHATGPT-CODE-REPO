// CHATGPT-CODE-REPO-TEST/lib/models/flashcard.dart
// ENHANCED - With image support, tags, audio, stats, and review history

import 'dart:convert';
import 'package:flutter/material.dart';

/// A simple Q&A card for active recall with enhanced features.
/// boxLevel 1-5 implements a lightweight spaced-repetition ladder.
class Flashcard {
  final int? id;
  final String subjectTag;
  final String frontText;
  final String backText;
  final int boxLevel; // 1..5
  final int? lastReviewedMillis;
  final int? nextReviewMillis;
  
  // NEW ENHANCED FIELDS
  final String? imagePath;           // Local image path for visual cards
  final String? audioFrontPath;      // TTS/audio for front text
  final String? audioBackPath;       // TTS/audio for back text
  final String tagsJson;             // JSON array of tags ["Hard", "Exam", "Quick Review"]
  final int totalReviews;            // Total times reviewed
  final int consecutiveCorrect;      // Streak of correct answers
  final int totalStudySeconds;       // Total time spent on this card
  final String? lastDifficulty;      // "again", "hard", "good", "easy"
  final int createdAtMillis;

  const Flashcard({
    this.id,
    required this.subjectTag,
    required this.frontText,
    required this.backText,
    this.boxLevel = 1,
    this.lastReviewedMillis,
    this.nextReviewMillis,
    this.imagePath,
    this.audioFrontPath,
    this.audioBackPath,
    this.tagsJson = '[]',
    this.totalReviews = 0,
    this.consecutiveCorrect = 0,
    this.totalStudySeconds = 0,
    this.lastDifficulty,
    required this.createdAtMillis,
  });

  List<String> get tags {
    try {
      final list = jsonDecode(tagsJson) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get hasAudio => audioFrontPath != null || audioBackPath != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectTag': subjectTag,
      'frontText': frontText,
      'backText': backText,
      'boxLevel': boxLevel.clamp(1, 5),
      'lastReviewedMillis': lastReviewedMillis,
      'nextReviewMillis': nextReviewMillis,
      'imagePath': imagePath,
      'audioFrontPath': audioFrontPath,
      'audioBackPath': audioBackPath,
      'tagsJson': tagsJson,
      'totalReviews': totalReviews,
      'consecutiveCorrect': consecutiveCorrect,
      'totalStudySeconds': totalStudySeconds,
      'lastDifficulty': lastDifficulty,
      'createdAtMillis': createdAtMillis,
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
      imagePath: map['imagePath'] as String?,
      audioFrontPath: map['audioFrontPath'] as String?,
      audioBackPath: map['audioBackPath'] as String?,
      tagsJson: map['tagsJson'] as String? ?? '[]',
      totalReviews: map['totalReviews'] as int? ?? 0,
      consecutiveCorrect: map['consecutiveCorrect'] as int? ?? 0,
      totalStudySeconds: map['totalStudySeconds'] as int? ?? 0,
      lastDifficulty: map['lastDifficulty'] as String?,
      createdAtMillis: map['createdAtMillis'] as int,
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
    String? imagePath,
    String? audioFrontPath,
    String? audioBackPath,
    String? tagsJson,
    int? totalReviews,
    int? consecutiveCorrect,
    int? totalStudySeconds,
    String? lastDifficulty,
    int? createdAtMillis,
  }) {
    return Flashcard(
      id: id ?? this.id,
      subjectTag: subjectTag ?? this.subjectTag,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      boxLevel: boxLevel ?? this.boxLevel,
      lastReviewedMillis: lastReviewedMillis ?? this.lastReviewedMillis,
      nextReviewMillis: nextReviewMillis ?? this.nextReviewMillis,
      imagePath: imagePath ?? this.imagePath,
      audioFrontPath: audioFrontPath ?? this.audioFrontPath,
      audioBackPath: audioBackPath ?? this.audioBackPath,
      tagsJson: tagsJson ?? this.tagsJson,
      totalReviews: totalReviews ?? this.totalReviews,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      totalStudySeconds: totalStudySeconds ?? this.totalStudySeconds,
      lastDifficulty: lastDifficulty ?? this.lastDifficulty,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }
}

/// Review history entry for detailed card statistics
class CardReviewHistory {
  final int? id;
  final int cardId;
  final String difficulty; // "again", "hard", "good", "easy"
  final int oldBoxLevel;
  final int newBoxLevel;
  final int reviewDurationSeconds; // How long the user spent on this review
  final int reviewedAtMillis;
  final bool wasCorrect; // true for good/easy, false for again/hard

  const CardReviewHistory({
    this.id,
    required this.cardId,
    required this.difficulty,
    required this.oldBoxLevel,
    required this.newBoxLevel,
    required this.reviewDurationSeconds,
    required this.reviewedAtMillis,
    required this.wasCorrect,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cardId': cardId,
      'difficulty': difficulty,
      'oldBoxLevel': oldBoxLevel,
      'newBoxLevel': newBoxLevel,
      'reviewDurationSeconds': reviewDurationSeconds,
      'reviewedAtMillis': reviewedAtMillis,
      'wasCorrect': wasCorrect ? 1 : 0,
    };
  }

  factory CardReviewHistory.fromMap(Map<String, dynamic> map) {
    return CardReviewHistory(
      id: map['id'] as int?,
      cardId: map['cardId'] as int,
      difficulty: map['difficulty'] as String,
      oldBoxLevel: map['oldBoxLevel'] as int,
      newBoxLevel: map['newBoxLevel'] as int,
      reviewDurationSeconds: map['reviewDurationSeconds'] as int,
      reviewedAtMillis: map['reviewedAtMillis'] as int,
      wasCorrect: (map['wasCorrect'] as int? ?? 0) == 1,
    );
  }
}
