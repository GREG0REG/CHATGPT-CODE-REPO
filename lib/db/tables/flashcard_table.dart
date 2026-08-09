// FILE: lib/db/tables/flashcard_table.dart
// GROUP C — flashcards, flashcard_review_history, daily_card_goals

import 'package:sqflite/sqflite.dart';
import 'package:event_countdown/models/flashcard.dart';
import 'package:event_countdown/models/flashcard_review_history.dart';
import 'package:event_countdown/models/daily_card_goal.dart';
import '../database_helper.dart';

mixin FlashcardTable on DatabaseHelper {
  // ============================================================
  // FLASHCARD CRUD
  // ============================================================
  Future<int> insertFlashcard(Flashcard card) async {
    final db = await database;
    return db.insert('flashcards', card.toMap()..remove('id'));
  }

  Future<int> updateFlashcard(Flashcard card) async {
    final db = await database;
    return db.update('flashcards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<int> deleteFlashcard(int id) async {
    final db = await database;
    return db.delete('flashcards', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Flashcard>> getFlashcards({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('flashcards', limit: limit);
    return rows.map((r) => Flashcard.fromMap(r)).toList();
  }

  Future<List<Flashcard>> getFlashcardsBySubject(String subject) async {
    final db = await database;
    final rows = await db.query(
      'flashcards',
      where: 'subjectTag = ?',
      whereArgs: [subject],
    );
    return rows.map((r) => Flashcard.fromMap(r)).toList();
  }

  Future<List<Flashcard>> getFlashcardsDueForReview(int beforeMillis) async {
    final db = await database;
    final rows = await db.query(
      'flashcards',
      where: 'nextReviewMillis IS NULL OR nextReviewMillis <= ?',
      whereArgs: [beforeMillis],
      orderBy: 'nextReviewMillis ASC',
    );
    return rows.map((r) => Flashcard.fromMap(r)).toList();
  }

  Future<void> updateFlashcardReview(int id, int boxLevel, int nextReviewMillis) async {
    final db = await database;
    await db.update(
      'flashcards',
      {
        'boxLevel': boxLevel.clamp(1, 5),
        'lastReviewedMillis': DateTime.now().millisecondsSinceEpoch,
        'nextReviewMillis': nextReviewMillis,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // FLASHCARD REVIEW HISTORY CRUD
  // ============================================================
  Future<int> insertFlashcardReviewHistory(FlashcardReviewHistory history) async {
    final db = await database;
    return db.insert('flashcard_review_history', history.toMap()..remove('id'));
  }

  Future<List<FlashcardReviewHistory>> getFlashcardReviewHistoryForCard(int cardId, {int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'flashcard_review_history',
      where: 'cardId = ?',
      whereArgs: [cardId],
      orderBy: 'reviewedAtMillis DESC',
      limit: limit,
    );
    return rows.map((r) => FlashcardReviewHistory.fromMap(r)).toList();
  }

  Future<List<FlashcardReviewHistory>> getFlashcardReviewHistoryForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'flashcard_review_history',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'reviewedAtMillis ASC',
    );
    return rows.map((r) => FlashcardReviewHistory.fromMap(r)).toList();
  }

  Future<void> deleteFlashcardReviewHistory(int id) async {
    final db = await database;
    await db.delete('flashcard_review_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getFlashcardReviewStats(int cardId) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as totalReviews,
        AVG(CASE WHEN difficulty = 'easy' THEN 1.0 
                 WHEN difficulty = 'good' THEN 0.75
                 WHEN difficulty = 'hard' THEN 0.5
                 WHEN difficulty = 'again' THEN 0.0 END) as avgAccuracy,
        AVG(timeSpentSeconds) as avgTimeSeconds
      FROM flashcard_review_history
      WHERE cardId = ?
    """, [cardId]);
    return result.first;
  }

  // ============================================================
  // DAILY CARD GOAL CRUD
  // ============================================================
  Future<int> insertOrUpdateDailyCardGoal(DailyCardGoal goal) async {
    final db = await database;
    final existing = await getDailyCardGoalForDate(goal.dateMillis);
    if (existing != null) {
      return db.update(
        'daily_card_goals',
        goal.toMap()..remove('id'),
        where: 'dateMillis = ?',
        whereArgs: [goal.dateMillis],
      );
    }
    return db.insert('daily_card_goals', goal.toMap()..remove('id'));
  }

  Future<DailyCardGoal?> getDailyCardGoalForDate(int dateMillis) async {
    final db = await database;
    final rows = await db.query(
      'daily_card_goals',
      where: 'dateMillis = ?',
      whereArgs: [dateMillis],
    );
    if (rows.isEmpty) return null;
    return DailyCardGoal.fromMap(rows.first);
  }

  Future<DailyCardGoal> getTodayDailyCardGoal() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final existing = await getDailyCardGoalForDate(startOfDay);
    if (existing != null) return existing;
    return DailyCardGoal(dateMillis: startOfDay);
  }

  Future<void> addAchievedCardReview(int dateMillis) async {
    final db = await database;
    final goal = await getDailyCardGoalForDate(dateMillis);
    if (goal != null) {
      await db.update(
        'daily_card_goals',
        {'achievedReviews': goal.achievedReviews + 1},
        where: 'dateMillis = ?',
        whereArgs: [dateMillis],
      );
    } else {
      await insertOrUpdateDailyCardGoal(DailyCardGoal(
        dateMillis: dateMillis,
        achievedReviews: 1,
      ));
    }
  }

  Future<void> addAchievedNewCard(int dateMillis) async {
    final db = await database;
    final goal = await getDailyCardGoalForDate(dateMillis);
    if (goal != null) {
      await db.update(
        'daily_card_goals',
        {'achievedNewCards': goal.achievedNewCards + 1},
        where: 'dateMillis = ?',
        whereArgs: [dateMillis],
      );
    } else {
      await insertOrUpdateDailyCardGoal(DailyCardGoal(
        dateMillis: dateMillis,
        achievedNewCards: 1,
      ));
    }
  }

  Future<int> getCardStreak() async {
    final db = await database;
    final rows = await db.query(
      'daily_card_goals',
      orderBy: 'dateMillis DESC',
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return DailyCardGoal.fromMap(rows.first).streakCount;
  }
}
