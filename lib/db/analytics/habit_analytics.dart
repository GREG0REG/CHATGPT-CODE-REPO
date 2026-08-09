// FILE: lib/db/analytics/habit_analytics.dart
// Habit streaks and weekly statistics

import 'package:sqflite/sqflite.dart';
import '../../../database_helper.dart';

mixin HabitAnalytics on DatabaseHelper {
  Future<int> getHabitCompletionCountForWeek(int habitId, int weekStartMillis) async {
    final db = await database;
    final weekEndMillis = weekStartMillis + const Duration(days: 7).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count FROM habit_logs
      WHERE habitId = ? AND dateMillis >= ? AND dateMillis < ? AND completed = 1
    """, [habitId, weekStartMillis, weekEndMillis]);
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getHabitStreak(int habitId) async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final rows = await db.query(
      'habit_logs',
      where: 'habitId = ? AND completed = 1',
      whereArgs: [habitId],
      orderBy: 'dateMillis DESC',
    );

    if (rows.isEmpty) return 0;

    int streak = 0;
    int expectedDateMillis = todayStart;

    for (final row in rows) {
      final dateMillis = row['dateMillis'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
      final dayStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

      if (dayStart == expectedDateMillis) {
        streak++;
        expectedDateMillis -= const Duration(days: 1).inMilliseconds;
      } else if (dayStart < expectedDateMillis) {
        break;
      }
    }

    return streak;
  }

  Future<Map<String, dynamic>> getHabitWeeklyStats(int habitId, int weekStartMillis) async {
    final db = await database;
    final weekEndMillis = weekStartMillis + const Duration(days: 7).inMilliseconds;

    final completedResult = await db.rawQuery("""
      SELECT COUNT(*) as completed FROM habit_logs
      WHERE habitId = ? AND dateMillis >= ? AND dateMillis < ? AND completed = 1
    """, [habitId, weekStartMillis, weekEndMillis]);

    final totalResult = await db.rawQuery("""
      SELECT COUNT(*) as total FROM habit_logs
      WHERE habitId = ? AND dateMillis >= ? AND dateMillis < ?
    """, [habitId, weekStartMillis, weekEndMillis]);

    final habit = await getHabitById(habitId);
    final targetPerWeek = (habit?['targetPerWeek'] as int?) ?? 7;

    return {
      'completed': (completedResult.first['completed'] as int?) ?? 0,
      'total': (totalResult.first['total'] as int?) ?? 0,
      'targetPerWeek': targetPerWeek,
      'percentage': targetPerWeek > 0
          ? (((completedResult.first['completed'] as int?) ?? 0) / targetPerWeek * 100).round()
          : 0,
    };
  }
}
