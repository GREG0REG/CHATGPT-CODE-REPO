// FILE: lib/db/analytics/study_analytics.dart
// Session stats, hourly breakdown, efficiency, streaks

import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

mixin StudyAnalytics on DatabaseHelper {
  // ============================================================
  // STATS METHODS (for stats_screen)
  // ============================================================
  Future<Map<int, int>> getSessionsByHour() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        CAST((completedAtMillis / 3600000) % 24 as INTEGER) as hour,
        SUM(durationMinutes) as minutes
      FROM study_sessions
      GROUP BY hour
      ORDER BY hour
    """);

    final Map<int, int> hourlyMinutes = {};
    for (int h = 0; h < 24; h++) {
      hourlyMinutes[h] = 0;
    }

    for (final row in result) {
      final hour = (row['hour'] as int?) ?? 0;
      final minutes = (row['minutes'] as int?) ?? 0;
      hourlyMinutes[hour] = minutes;
    }
    return hourlyMinutes;
  }

  Future<double> getAverageSessionDuration() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT AVG(durationMinutes) as avgDuration
      FROM study_sessions
    """);
    final avg = result.first['avgDuration'];
    if (avg == null) return 0.0;
    return (avg as num).toDouble();
  }

  Future<int> getLongestSession() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT MAX(durationMinutes) as maxDuration
      FROM study_sessions
    """);
    return (result.first['maxDuration'] as int?) ?? 0;
  }

  Future<int> getTodaySessionCount() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count
      FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ?
    """, [startOfDay, endOfDay]);
    return (result.first['count'] as int?) ?? 0;
  }

  Future<Map<String, int>> getSessionTypeBreakdown() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT sessionType, COUNT(*) as count
      FROM study_sessions
      GROUP BY sessionType
    """);
    final Map<String, int> breakdown = {};
    for (final row in result) {
      final type = (row['sessionType'] as String?) ?? 'unknown';
      final count = (row['count'] as int?) ?? 0;
      breakdown[type] = count;
    }
    return breakdown;
  }

  Future<int> getWeeklyMinutes(int weekStartMillis) async {
    final db = await database;
    final weekEndMillis = weekStartMillis + const Duration(days: 7).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COALESCE(SUM(durationMinutes), 0) as total
      FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ?
    """, [weekStartMillis, weekEndMillis]);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getMonthlyMinutes(int year, int month) async {
    final db = await database;
    final startOfMonth = DateTime(year, month, 1).millisecondsSinceEpoch;
    final endOfMonth = month == 12
        ? DateTime(year + 1, 1, 1).millisecondsSinceEpoch
        : DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final result = await db.rawQuery("""
      SELECT COALESCE(SUM(durationMinutes), 0) as total
      FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ?
    """, [startOfMonth, endOfMonth]);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getStudyEfficiencyScore() async {
    final db = await database;
    final goalResult = await db.rawQuery("""
      SELECT 
        COALESCE(SUM(targetMinutes), 0) as totalTarget,
        COALESCE(SUM(achievedMinutes), 0) as totalAchieved
      FROM daily_goals
    """);
    final totalTarget = (goalResult.first['totalTarget'] as int?) ?? 0;
    final totalAchieved = (goalResult.first['totalAchieved'] as int?) ?? 0;
    final sessionResult = await db.rawQuery("""
      SELECT COUNT(*) as sessionCount
      FROM study_sessions
    """);
    final sessionCount = (sessionResult.first['sessionCount'] as int?) ?? 0;
    final streak = await getLatestStreak();

    double baseScore = 0;
    if (totalTarget > 0) {
      baseScore = (totalAchieved / totalTarget * 60).clamp(0.0, 60.0);
    } else if (totalAchieved > 0) {
      baseScore = 30.0;
    }

    double volumeScore = 0;
    if (sessionCount >= 50) volumeScore = 20;
    else if (sessionCount >= 20) volumeScore = 15;
    else if (sessionCount >= 10) volumeScore = 10;
    else if (sessionCount >= 5) volumeScore = 5;

    double streakScore = 0;
    if (streak >= 14) streakScore = 20;
    else if (streak >= 7) streakScore = 15;
    else if (streak >= 3) streakScore = 10;
    else if (streak >= 1) streakScore = 5;

    final totalScore = (baseScore + volumeScore + streakScore).round().clamp(0, 100);
    return totalScore;
  }
}
