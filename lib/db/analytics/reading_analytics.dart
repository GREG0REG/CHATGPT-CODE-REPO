// FILE: lib/db/analytics/reading_analytics.dart
// Reading progress, streaks, speed, consistency

import 'package:sqflite/sqflite.dart';
import '../../../database_helper.dart';

mixin ReadingAnalytics on DatabaseHelper {
  Future<Map<String, dynamic>> getReadingProgress(int bookId) async {
    final book = await getReadingBookById(bookId);
    if (book == null) {
      return {
        'percentage': 0,
        'pagesLeft': 0,
        'daysLeft': 0,
        'pagesPerDayNeeded': 0,
        'onTrack': false,
      };
    }

    final totalPages = (book['totalPages'] as int?) ?? 1;
    final currentPage = (book['currentPage'] as int?) ?? 0;
    final dailyGoal = (book['dailyPageGoal'] as int?) ?? 20;
    final targetEndMillis = book['targetEndDateMillis'] as int?;

    final percentage = totalPages > 0 ? (currentPage / totalPages * 100).round() : 0;
    final pagesLeft = totalPages - currentPage;

    int daysLeft = 0;
    double pagesPerDayNeeded = 0;
    bool onTrack = true;

    if (targetEndMillis != null && pagesLeft > 0) {
      final now = DateTime.now();
      final targetDate = DateTime.fromMillisecondsSinceEpoch(targetEndMillis);
      daysLeft = targetDate.difference(now).inDays;
      if (daysLeft > 0) {
        pagesPerDayNeeded = pagesLeft / daysLeft;
        onTrack = pagesPerDayNeeded <= dailyGoal;
      } else {
        onTrack = false;
      }
    }

    return {
      'percentage': percentage,
      'pagesLeft': pagesLeft,
      'daysLeft': daysLeft,
      'pagesPerDayNeeded': pagesPerDayNeeded.ceil(),
      'dailyPageGoal': dailyGoal,
      'onTrack': onTrack,
      'totalMinutesRead': book['totalMinutesRead'] ?? 0,
      'minutesReadToday': book['minutesReadToday'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> getOverallReadingStats() async {
    final db = await database;
    final books = await getAllReadingBooks();

    int totalBooks = books.length;
    int completedBooks = 0;
    int totalPagesRead = 0;
    int totalMinutesRead = 0;

    for (final book in books) {
      if ((book['isCompleted'] as int?) == 1) completedBooks++;
      totalPagesRead += (book['currentPage'] as int?) ?? 0;
      totalMinutesRead += (book['totalMinutesRead'] as int?) ?? 0;
    }

    return {
      'totalBooks': totalBooks,
      'completedBooks': completedBooks,
      'inProgressBooks': totalBooks - completedBooks,
      'totalPagesRead': totalPagesRead,
      'totalMinutesRead': totalMinutesRead,
      'completionRate': totalBooks > 0 ? (completedBooks / totalBooks * 100).round() : 0,
    };
  }

  Future<int> getReadingStreak(int bookId) async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final rows = await db.rawQuery("""
      SELECT DISTINCT 
        CAST(sessionDateMillis / 86400000 as INTEGER) as dayBucket
      FROM reading_sessions
      WHERE bookId = ?
      ORDER BY dayBucket DESC
    """, [bookId]);

    if (rows.isEmpty) return 0;

    int streak = 0;
    int expectedDayBucket = todayStart ~/ 86400000;

    for (final row in rows) {
      final dayBucket = (row['dayBucket'] as int?) ?? 0;
      if (dayBucket == expectedDayBucket) {
        streak++;
        expectedDayBucket--;
      } else if (dayBucket < expectedDayBucket) {
        break;
      }
    }

    return streak;
  }

  Future<List<Map<String, dynamic>>> getPagesPerDayHistory(int bookId, int days) async {
    final db = await database;
    final now = DateTime.now();
    final endMillis = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds;
    final startMillis = endMillis - Duration(days: days).inMilliseconds;

    final rows = await db.query(
      'reading_sessions',
      where: 'bookId = ? AND sessionDateMillis >= ? AND sessionDateMillis < ?',
      whereArgs: [bookId, startMillis, endMillis],
      orderBy: 'sessionDateMillis ASC',
    );

    final Map<String, int> dayMap = {};
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: days - 1 - i));
      final key = '${date.month}/${date.day}';
      dayMap[key] = 0;
    }

    for (final row in rows) {
      final millis = row['sessionDateMillis'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(millis);
      final key = '${date.month}/${date.day}';
      dayMap[key] = (dayMap[key] ?? 0) + ((row['pagesRead'] as int?) ?? 0);
    }

    return dayMap.entries.map((e) => {'date': e.key, 'pages': e.value}).toList();
  }

  Future<double> getAveragePagesPerMinute(int bookId) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        SUM(pagesRead) as totalPages,
        SUM(minutesRead) as totalMinutes
      FROM reading_sessions
      WHERE bookId = ?
    """, [bookId]);

    final totalPages = (result.first['totalPages'] as int?) ?? 0;
    final totalMinutes = (result.first['totalMinutes'] as int?) ?? 0;

    if (totalMinutes <= 0) return 0.0;
    return totalPages / totalMinutes;
  }

  Future<Map<String, dynamic>> getReadingSessionTotals(int bookId) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as sessionCount,
        SUM(pagesRead) as totalPages,
        SUM(minutesRead) as totalMinutes,
        AVG(pagesPerMinute) as avgSpeed
      FROM reading_sessions
      WHERE bookId = ?
    """, [bookId]);

    return {
      'sessionCount': (result.first['sessionCount'] as int?) ?? 0,
      'totalPages': (result.first['totalPages'] as int?) ?? 0,
      'totalMinutes': (result.first['totalMinutes'] as int?) ?? 0,
      'avgSpeed': (result.first['avgSpeed'] as double?) ?? 0.0,
    };
  }

  Future<Map<String, dynamic>?> getBestReadingDay(int bookId) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        CAST(sessionDateMillis / 86400000 as INTEGER) as dayBucket,
        SUM(pagesRead) as dayPages
      FROM reading_sessions
      WHERE bookId = ?
      GROUP BY dayBucket
      ORDER BY dayPages DESC
      LIMIT 1
    """, [bookId]);

    if (result.isEmpty) return null;

    final dayBucket = (result.first['dayBucket'] as int?) ?? 0;
    final dayMillis = dayBucket * 86400000;
    final date = DateTime.fromMillisecondsSinceEpoch(dayMillis);

    return {
      'date': '${date.month}/${date.day}/${date.year}',
      'pages': (result.first['dayPages'] as int?) ?? 0,
    };
  }

  Future<DateTime?> getEstimatedCompletionDate(int bookId) async {
    final book = await getReadingBookById(bookId);
    if (book == null) return null;

    final totalPages = (book['totalPages'] as int?) ?? 1;
    final currentPage = (book['currentPage'] as int?) ?? 0;
    final pagesLeft = totalPages - currentPage;
    if (pagesLeft <= 0) return DateTime.now();

    final avgSpeed = await getAveragePagesPerMinute(bookId);
    if (avgSpeed <= 0) return null;

    final pagesPerDay = avgSpeed * 30;
    final daysNeeded = (pagesLeft / pagesPerDay).ceil();

    return DateTime.now().add(Duration(days: daysNeeded));
  }

  Future<int> getReadingConsistencyScore(int bookId) async {
    final db = await database;
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;

    final rows = await db.rawQuery("""
      SELECT COUNT(DISTINCT CAST(sessionDateMillis / 86400000 as INTEGER)) as activeDays
      FROM reading_sessions
      WHERE bookId = ? AND sessionDateMillis >= ?
    """, [bookId, thirtyDaysAgo]);

    final activeDays = (rows.first['activeDays'] as int?) ?? 0;
    return (activeDays / 30 * 100).round().clamp(0, 100);
  }
}
