// FILE: lib/db/analytics/syllabus_analytics.dart
// Syllabus progress, pace analysis, weak topics, revision stats, MCQ tracking

import 'package:sqflite/sqflite.dart';
import 'package:event_countdown/models/syllabus_subject.dart';
import '../../database_helper.dart';   // ✅ CORRECT - goes up TWO levels to lib/

mixin SyllabusAnalytics on DatabaseHelper {
  // ============================================================
  // SYLLABUS ANALYTICS
  // ============================================================
  Future<Map<String, dynamic>> getSyllabusProgressForSubject(int subjectId) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COUNT(t.id) as total,
        SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed
      FROM syllabus_topics t
      JOIN syllabus_units u ON t.unitId = u.id
      WHERE u.subjectId = ?
    """, [subjectId]);
    return {
      'total': (result.first['total'] as int?) ?? 0,
      'completed': (result.first['completed'] as int?) ?? 0,
    };
  }

  Future<Map<String, dynamic>> getOverallSyllabusProgress() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
      FROM syllabus_topics
    """);
    return {
      'total': (result.first['total'] as int?) ?? 0,
      'completed': (result.first['completed'] as int?) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getWeakTopics() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysAgo = now - const Duration(days: 7).inMilliseconds;
    final rows = await db.rawQuery("""
      SELECT t.*, u.subjectId, s.name as subjectName
      FROM syllabus_topics t
      JOIN syllabus_units u ON t.unitId = u.id
      JOIN syllabus_subjects s ON u.subjectId = s.id
      WHERE (t.status = 'needsRevision' OR (t.status = 'inProgress' AND t.createdAtMillis < ?))
      ORDER BY t.createdAtMillis ASC
    """, [sevenDaysAgo]);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTopicsForToday() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    final revisionTopics = await db.rawQuery("""
      SELECT DISTINCT t.*, s.name as subjectName
      FROM syllabus_revision_schedules r
      JOIN syllabus_topics t ON r.topicId = t.id
      JOIN syllabus_units u ON t.unitId = u.id
      JOIN syllabus_subjects s ON u.subjectId = s.id
      WHERE r.scheduledDateMillis >= ? AND r.scheduledDateMillis < ? AND r.isCompleted = 0
      ORDER BY r.revisionNumber ASC
    """, [todayStart, todayEnd]);

    final inProgressTopics = await db.rawQuery("""
      SELECT t.*, s.name as subjectName
      FROM syllabus_topics t
      JOIN syllabus_units u ON t.unitId = u.id
      JOIN syllabus_subjects s ON u.subjectId = s.id
      WHERE t.status = 'inProgress'
      ORDER BY (SELECT MAX(createdAtMillis) FROM syllabus_study_links WHERE topicId = t.id) ASC
      LIMIT 5
    """);

    return [...revisionTopics, ...inProgressTopics];
  }

  Future<Map<String, dynamic>> getSyllabusPaceAnalysis(int subjectId) async {
    final db = await database;
    final subject = await getSyllabusSubject(subjectId);
    if (subject == null || subject.targetCompletionDateMillis == null) {
      return {'status': 'No target date set'};
    }
    final result = await db.rawQuery("""
      SELECT 
        COUNT(t.id) as total,
        SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed
      FROM syllabus_topics t
      JOIN syllabus_units u ON t.unitId = u.id
      WHERE u.subjectId = ?
    """, [subjectId]);
    
    final total = (result.first['total'] as int?) ?? 0;
    final completed = (result.first['completed'] as int?) ?? 0;
    if (total == 0) return {'status': 'No topics'};

    final targetDate = DateTime.fromMillisecondsSinceEpoch(subject.targetCompletionDateMillis!);
    final now = DateTime.now();
    final totalDays = targetDate.difference(DateTime.fromMillisecondsSinceEpoch(subject.createdAtMillis)).inDays;
    final daysPassed = now.difference(DateTime.fromMillisecondsSinceEpoch(subject.createdAtMillis)).inDays;
    final daysLeft = targetDate.difference(now).inDays;
    
    final expectedProgress = totalDays > 0 ? (daysPassed / totalDays).clamp(0.0, 1.0) : 0.0;
    final actualProgress = completed / total;

    String status;
    if (actualProgress >= expectedProgress) {
      status = 'On Track';
    } else if (actualProgress >= expectedProgress * 0.8) {
      status = 'Slightly Behind';
    } else {
      status = 'Behind';
    }
    return {
      'status': status,
      'percentage': actualProgress * 100,
      'targetDate': targetDate.toIso8601String(),
      'remainingTopics': total - completed,
      'daysLeft': daysLeft,
    };
  }

  // ============================================================
  // ENHANCED SYLLABUS ANALYTICS
  // ============================================================
  Future<Map<String, dynamic>> getTopicMcqStats(int topicId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_topics',
      where: 'id = ?',
      whereArgs: [topicId],
    );
    if (rows.isEmpty) return {'attempted': 0, 'correct': 0, 'accuracy': 0.0};
    final row = rows.first;
    final attempted = (row['mcqsAttempted'] as int?) ?? 0;
    final correct = (row['mcqsCorrect'] as int?) ?? 0;
    return {
      'attempted': attempted,
      'correct': correct,
      'accuracy': attempted > 0 ? (correct / attempted * 100).round() : 0.0,
    };
  }

  Future<void> updateTopicMcqStats(int topicId, int attempted, int correct) async {
    final db = await database;
    final existing = await db.query('syllabus_topics', where: 'id = ?', whereArgs: [topicId]);
    if (existing.isEmpty) return;
    final oldAttempted = (existing.first['mcqsAttempted'] as int?) ?? 0;
    final oldCorrect = (existing.first['mcqsCorrect'] as int?) ?? 0;
    await db.update(
      'syllabus_topics',
      {
        'mcqsAttempted': oldAttempted + attempted,
        'mcqsCorrect': oldCorrect + correct,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> updateTopicMockScore(int topicId, int score) async {
    final db = await database;
    final existing = await db.query('syllabus_topics', where: 'id = ?', whereArgs: [topicId]);
    if (existing.isEmpty) return;
    final oldBest = (existing.first['bestMockScore'] as int?);
    await db.update(
      'syllabus_topics',
      {
        'lastMockScore': score,
        'bestMockScore': oldBest == null || score > oldBest ? score : oldBest,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> addTopicStudyMinutes(int topicId, int minutes) async {
    final db = await database;
    await db.rawUpdate("""
      UPDATE syllabus_topics
      SET totalStudyMinutes = COALESCE(totalStudyMinutes, 0) + ?
      WHERE id = ?
    """, [minutes, topicId]);
  }

  Future<List<Map<String, dynamic>>> getTopicsWithDeadlines(int subjectId) async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT t.*, d.targetDateMillis as deadlineDate, d.priority, d.reminderDays
      FROM syllabus_topics t
      JOIN syllabus_units u ON t.unitId = u.id
      LEFT JOIN chapter_deadlines d ON t.id = d.topicId
      WHERE u.subjectId = ? AND d.targetDateMillis IS NOT NULL
      ORDER BY d.targetDateMillis ASC
    """, [subjectId]);
    return rows;
  }

  Future<Map<String, dynamic>> getSubjectDeadlineProgress(int subjectId) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COUNT(d.id) as totalDeadlines,
        SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN d.targetDateMillis < ? AND t.status != 'completed' THEN 1 ELSE 0 END) as overdue
      FROM chapter_deadlines d
      JOIN syllabus_topics t ON d.topicId = t.id
      JOIN syllabus_units u ON t.unitId = u.id
      WHERE u.subjectId = ?
    """, [DateTime.now().millisecondsSinceEpoch, subjectId]);
    return {
      'totalDeadlines': (result.first['totalDeadlines'] as int?) ?? 0,
      'completed': (result.first['completed'] as int?) ?? 0,
      'overdue': (result.first['overdue'] as int?) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getRevisionPerformanceStats() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT 
        r.revisionNumber,
        COUNT(*) as total,
        SUM(CASE WHEN r.isCompleted = 1 THEN 1 ELSE 0 END) as completed,
        AVG(r.performanceScore) as avgPerformance
      FROM syllabus_revision_schedules r
      GROUP BY r.revisionNumber
      ORDER BY r.revisionNumber
    """);
    return rows;
  }
}
