// CHATGPT-CODE-REPO-TEST/lib/models/flashcard.dart
// ENHANCED VERSION - With Audio, Images, Tags, Review History, Favorites

import 'dart:convert';
import 'package:flutter/material.dart';

/// A Q&A card for active recall with enhanced features.
/// boxLevel 1-5 implements a lightweight spaced-repetition ladder.
/// Supports: images, audio, tags, review history, favorites, difficulty tracking.
class Flashcard {
  final int? id;
  final String subjectTag;
  final String frontText;
  final String backText;
  final int boxLevel; // 1..5
  final int? lastReviewedMillis;
  final int? nextReviewMillis;
  
  // NEW: Enhanced fields
  final String? imagePath;           // Local image path for visual cards
  final String? audioFrontPath;      // TTS/audio for front side
  final String? audioBackPath;       // TTS/audio for back side
  final String tagsJson;             // JSON array of tags ["Hard","Exam","Quick Review"]
  final int totalReviews;           // Total times reviewed
  final int consecutiveCorrect;      // Streak of correct answers
  final int createdAtMillis;        // When card was created
  final bool isFavorite;             // Starred card
  final double difficultyRating;     // 0.0-5.0 calculated difficulty
  final String? reviewHistoryJson;   // JSON array of review records

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
    required this.createdAtMillis,
    this.isFavorite = false,
    this.difficultyRating = 2.5,
    this.reviewHistoryJson,
  });

  List<String> get tags {
    try {
      final list = jsonDecode(tagsJson) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> get reviewHistory {
    try {
      if (reviewHistoryJson == null || reviewHistoryJson!.isEmpty) return [];
      final list = jsonDecode(reviewHistoryJson!) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  String get masteryLabel {
    if (boxLevel >= 5) return 'Mastered';
    if (boxLevel >= 4) return 'Expert';
    if (boxLevel >= 3) return 'Proficient';
    if (boxLevel >= 2) return 'Learning';
    return 'New';
  }

  Color get masteryColor {
    if (boxLevel >= 5) return Colors.green;
    if (boxLevel >= 4) return Colors.lightGreen;
    if (boxLevel >= 3) return Colors.orange;
    if (boxLevel >= 2) return Colors.deepOrange;
    return Colors.red;
  }

  double get masteryPercent => boxLevel / 5.0;

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
      'createdAtMillis': createdAtMillis,
      'isFavorite': isFavorite ? 1 : 0,
      'difficultyRating': difficultyRating,
      'reviewHistoryJson': reviewHistoryJson,
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
      createdAtMillis: map['createdAtMillis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      difficultyRating: (map['difficultyRating'] as num?)?.toDouble() ?? 2.5,
      reviewHistoryJson: map['reviewHistoryJson'] as String?,
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
    bool clearImagePath = false,
    String? audioFrontPath,
    bool clearAudioFrontPath = false,
    String? audioBackPath,
    bool clearAudioBackPath = false,
    String? tagsJson,
    int? totalReviews,
    int? consecutiveCorrect,
    int? createdAtMillis,
    bool? isFavorite,
    double? difficultyRating,
    String? reviewHistoryJson,
    bool clearReviewHistory = false,
  }) {
    return Flashcard(
      id: id ?? this.id,
      subjectTag: subjectTag ?? this.subjectTag,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      boxLevel: boxLevel ?? this.boxLevel,
      lastReviewedMillis: lastReviewedMillis ?? this.lastReviewedMillis,
      nextReviewMillis: nextReviewMillis ?? this.nextReviewMillis,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      audioFrontPath: clearAudioFrontPath ? null : (audioFrontPath ?? this.audioFrontPath),
      audioBackPath: clearAudioBackPath ? null : (audioBackPath ?? this.audioBackPath),
      tagsJson: tagsJson ?? this.tagsJson,
      totalReviews: totalReviews ?? this.totalReviews,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      isFavorite: isFavorite ?? this.isFavorite,
      difficultyRating: difficultyRating ?? this.difficultyRating,
      reviewHistoryJson: clearReviewHistory ? null : (reviewHistoryJson ?? this.reviewHistoryJson),
    );
  }

  /// Add a review record to history
  Flashcard withReviewRecord(String difficulty, int timeSpentSeconds) {
    final history = reviewHistory;
    final newRecord = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'difficulty': difficulty,
      'timeSpentSeconds': timeSpentSeconds,
      'boxLevelAfter': boxLevel,
    };
    history.add(newRecord);
    
    // Keep only last 50 records to prevent bloat
    final trimmed = history.length > 50 ? history.sublist(history.length - 50) : history;
    
    return copyWith(
      reviewHistoryJson: jsonEncode(trimmed),
      totalReviews: totalReviews + 1,
    );
  }
}
