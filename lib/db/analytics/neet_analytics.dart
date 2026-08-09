// FILE: lib/db/analytics/neet_analytics.dart
// NEET-specific analytics queries

import 'package:sqflite/sqflite.dart';
import 'package:event_countdown/models/study_session.dart';
import '../../database_helper.dart';   // ✅ CORRECT - goes up TWO levels to lib/


mixin NeetAnalytics on DatabaseHelper {
  String _neetSubjectName(int index) {
    const names = ['Physics', 'Chemistry', 'Biology', 'General'];
    return (index >= 0 && index < names.length) ? names[index] : 'Unknown';
  }

  Future<List<StudySession>> getStudySessionsForNeetSubject(int neetSubjectIndex) async {
    final db = await database;
    final rows = await db.query(
      'study_sessions',
      where: 'neetSubject = ?',
      whereArgs: [neetSubjectIndex],
      orderBy: 'completedAtMillis DESC',
    );
    return rows.map((r) => StudySession.fromMap(r)).toList();
  }

  Future<Map<String, int>> getTodayNeetSubjectMinutes() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    final result = await db.rawQuery("""
      SELECT neetSubject, COALESCE(SUM(durationMinutes), 0) as total
      FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ? AND neetSubject IS NOT NULL
      GROUP BY neetSubject
    """, [startOfDay, endOfDay]);

    final Map<String, int> breakdown = {};
    for (final row in result) {
      final subjectIdx = row['neetSubject'] as int?;
      if (subjectIdx != null) {
        breakdown[_neetSubjectName(subjectIdx)] = (row['total'] as int?) ?? 0;
      }
    }
    return breakdown;
  }

  Future<Map<String, double>> getNeetSubjectAccuracy() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT neetSubject,
        SUM(mcqsAttempted) as attempted,
        SUM(mcqsCorrect) as correct
      FROM study_sessions
      WHERE neetSubject IS NOT NULL AND mcqsAttempted > 0
      GROUP BY neetSubject
    """);

    final Map<String, double> accuracy = {};
    for (final row in result) {
      final subjectIdx = row['neetSubject'] as int?;
      final attempted = (row['attempted'] as int?) ?? 0;
      final correct = (row['correct'] as int?) ?? 0;
      if (subjectIdx != null && attempted > 0) {
        accuracy[_neetSubjectName(subjectIdx)] = (correct / attempted * 100);
      }
    }
    return accuracy;
  }

  Future<Map<String, int>> getTotalMcqStats() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COALESCE(SUM(mcqsAttempted), 0) as attempted,
        COALESCE(SUM(mcqsCorrect), 0) as correct
      FROM study_sessions
    """);

    return {
      'attempted': (result.first['attempted'] as int?) ?? 0,
      'correct': (result.first['correct'] as int?) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getMockTestScores() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT completedAtMillis, mockTestScore, mockTestRank, subjectTag, neetSubject
      FROM study_sessions
      WHERE mockTestScore IS NOT NULL
      ORDER BY completedAtMillis DESC
    """);
    return rows;
  }

  Future<int> getBestMockTestScore() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT MAX(mockTestScore) as best
      FROM study_sessions
      WHERE mockTestScore IS NOT NULL
    """);
    return (result.first['best'] as int?) ?? 0;
  }
}
