// FILE: lib/db/tables/study_table.dart
// GROUP B — study_sessions, subtasks, study_schedules, daily_goals, study_subjects

import 'package:sqflite/sqflite.dart';
import 'package:event_countdown/models/study_session.dart';
import 'package:event_countdown/models/subtask.dart';
import 'package:event_countdown/models/study_schedule.dart';
import 'package:event_countdown/models/daily_goal.dart';
import 'package:event_countdown/models/study_subject.dart';
import '../database_helper.dart';

mixin StudyTable on DatabaseHelper {
  // ============================================================
  // STUDY SESSION CRUD
  // ============================================================
  Future<int> insertStudySession(StudySession session) async {
    final db = await database;
    return db.insert('study_sessions', session.toMap()..remove('id'));
  }

  Future<List<StudySession>> getStudySessions({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('study_sessions', orderBy: 'completedAtMillis DESC', limit: limit);
    return rows.map((r) => StudySession.fromMap(r)).toList();
  }

  Future<List<StudySession>> getStudySessionsForSubject(String subject) async {
    final db = await database;
    final rows = await db.query(
      'study_sessions',
      where: 'subjectTag = ?',
      whereArgs: [subject],
      orderBy: 'completedAtMillis DESC',
    );
    return rows.map((r) => StudySession.fromMap(r)).toList();
  }

  Future<List<StudySession>> getStudySessionsForDateRange(int startMillis, int endMillis) async {
    final db = await database;
    final rows = await db.query(
      'study_sessions',
      where: 'completedAtMillis >= ? AND completedAtMillis < ?',
      whereArgs: [startMillis, endMillis],
      orderBy: 'completedAtMillis DESC',
    );
    return rows.map((r) => StudySession.fromMap(r)).toList();
  }

  Future<StudySession?> getStudySession(int id) async {
    final db = await database;
    final rows = await db.query('study_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudySession.fromMap(rows.first);
  }

  Future<int> getTodayStudyMinutes() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COALESCE(SUM(durationMinutes), 0) as total
      FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ?
    """, [startOfDay, endOfDay]);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> deleteStudySession(int id) async {
    final db = await database;
    return db.delete('study_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSessionNote(int id, String note) async {
    final db = await database;
    await db.update(
      'study_sessions',
      {'notes': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertStudySessionFromMap(Map<String, dynamic> session) async {
    final db = await database;
    final data = {
      'eventId': session['eventId'],
      'subjectTag': session['subjectTag'],
      'durationMinutes': session['durationMinutes'],
      'completedAtMillis': session['completedAtMillis'] ?? DateTime.now().millisecondsSinceEpoch,
      'sessionType': session['sessionType'] ?? 'focused',
      'notes': session['notes'],
      'distractionCount': session['distractionCount'] ?? 0,
      'intensityRating': session['intensityRating'] ?? 0,
      'topicTag': session['topicTag'],
      'neetSubject': session['neetSubject'],
      'mcqsAttempted': session['mcqsAttempted'] ?? 0,
      'mcqsCorrect': session['mcqsCorrect'] ?? 0,
      'difficultyLevel': session['difficultyLevel'] ?? 1,
      'revisionRound': session['revisionRound'] ?? 0,
      'mockTestScore': session['mockTestScore'],
      'mockTestRank': session['mockTestRank'],
      'productivity': session['productivity'] ?? 7,
    };
    return db.insert('study_sessions', data);
  }

  // ============================================================
  // STUDY SESSION STATS FOR STUDY PLANNER
  // ============================================================
  Future<Map<String, dynamic>> getStudySessionStats(int? planId) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (planId != null) {
      whereClause = 'WHERE s.topicId IN (SELECT topicId FROM study_plan_items WHERE planId = ? AND topicId IS NOT NULL)';
      whereArgs = [planId];
    }
    
    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as totalSessions,
        COALESCE(SUM(durationMinutes), 0) as totalMinutes,
        AVG(productivity) as avgProductivity
      FROM study_sessions s
      $whereClause
    """, whereArgs);
    
    return {
      'totalSessions': (result.first['totalSessions'] as int?) ?? 0,
      'totalMinutes': (result.first['totalMinutes'] as int?) ?? 0,
      'avgProductivity': (result.first['avgProductivity'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<Map<String, dynamic>> getWeeklyStudyStats(int? planId) async {
    final db = await database;
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch - 
                      (now.weekday - 1) * const Duration(days: 1).inMilliseconds;
    final weekEnd = weekStart + const Duration(days: 7).inMilliseconds;
    
    String whereClause = 'WHERE s.completedAtMillis >= ? AND s.completedAtMillis < ?';
    List<dynamic> whereArgs = [weekStart, weekEnd];
    
    if (planId != null) {
      whereClause += ' AND s.topicId IN (SELECT topicId FROM study_plan_items WHERE planId = ? AND topicId IS NOT NULL)';
      whereArgs.add(planId);
    }
    
    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as sessionsThisWeek,
        COALESCE(SUM(durationMinutes), 0) as minutesThisWeek
      FROM study_sessions s
      $whereClause
    """, whereArgs);
    
    return {
      'sessionsThisWeek': (result.first['sessionsThisWeek'] as int?) ?? 0,
      'minutesThisWeek': (result.first['minutesThisWeek'] as int?) ?? 0,
    };
  }

  // ============================================================
  // SUBTASK CRUD
  // ============================================================
  Future<int> insertSubtask(Subtask subtask) async {
    final db = await database;
    return db.insert('subtasks', subtask.toMap()..remove('id'));
  }

  Future<int> updateSubtask(Subtask subtask) async {
    final db = await database;
    return db.update('subtasks', subtask.toMap(), where: 'id = ?', whereArgs: [subtask.id]);
  }

  Future<int> deleteSubtask(int id) async {
    final db = await database;
    return db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Subtask>> getSubtasksForEvent(int eventId) async {
    final db = await database;
    final rows = await db.query(
      'subtasks',
      where: 'eventId = ?',
      whereArgs: [eventId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((r) => Subtask.fromMap(r)).toList();
  }

  Future<void> toggleSubtaskComplete(int id, bool completed) async {
    final db = await database;
    await db.update(
      'subtasks',
      {'isCompleted': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getSubtaskCompletionCount(int eventId) async {
    final db = await database;
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM subtasks WHERE eventId = ?',
      [eventId],
    );
    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM subtasks WHERE eventId = ? AND isCompleted = 1',
      [eventId],
    );
    return {
      'total': (totalResult.first['count'] as int?) ?? 0,
      'completed': (completedResult.first['count'] as int?) ?? 0,
    };
  }

  // ============================================================
  // STUDY SCHEDULE CRUD
  // ============================================================
  Future<int> insertStudySchedule(StudySchedule schedule) async {
    final db = await database;
    return db.insert('study_schedules', schedule.toMap()..remove('id'));
  }

  Future<int> updateStudySchedule(StudySchedule schedule) async {
    final db = await database;
    return db.update('study_schedules', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);
  }

  Future<int> deleteStudySchedule(int id) async {
    final db = await database;
    return db.delete('study_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<StudySchedule>> getStudySchedules({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('study_schedules', orderBy: 'suggestedDateMillis ASC', limit: limit);
    return rows.map((r) => StudySchedule.fromMap(r)).toList();
  }

  Future<List<StudySchedule>> getStudySchedulesForDate(int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final rows = await db.query(
      'study_schedules',
      where: 'suggestedDateMillis >= ? AND suggestedDateMillis < ?',
      whereArgs: [dateMillis, endOfDay],
      orderBy: 'suggestedDateMillis ASC',
    );
    return rows.map((r) => StudySchedule.fromMap(r)).toList();
  }

  Future<List<StudySchedule>> getPendingStudySchedules() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'study_schedules',
      where: 'isCompleted = 0 AND suggestedDateMillis >= ?',
      whereArgs: [now],
      orderBy: 'suggestedDateMillis ASC',
    );
    return rows.map((r) => StudySchedule.fromMap(r)).toList();
  }

  // ============================================================
  // DAILY GOAL CRUD
  // ============================================================
  Future<int> insertOrUpdateDailyGoal(DailyGoal goal) async {
    final db = await database;
    final existing = await getDailyGoalForDate(goal.dateMillis);
    if (existing != null) {
      return db.update(
        'daily_goals',
        goal.toMap()..remove('id'),
        where: 'dateMillis = ?',
        whereArgs: [goal.dateMillis],
      );
    }
    return db.insert('daily_goals', goal.toMap()..remove('id'));
  }

  Future<DailyGoal?> getDailyGoalForDate(int dateMillis) async {
    final db = await database;
    final rows = await db.query(
      'daily_goals',
      where: 'dateMillis = ?',
      whereArgs: [dateMillis],
    );
    if (rows.isEmpty) return null;
    return DailyGoal.fromMap(rows.first);
  }

  Future<DailyGoal> getTodayDailyGoal() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final existing = await getDailyGoalForDate(startOfDay);
    if (existing != null) return existing;
    return DailyGoal(dateMillis: startOfDay);
  }

  Future<void> addAchievedMinutes(int dateMillis, int minutes) async {
    final db = await database;
    final goal = await getDailyGoalForDate(dateMillis);
    if (goal != null) {
      await db.update(
        'daily_goals',
        {'achievedMinutes': goal.achievedMinutes + minutes},
        where: 'dateMillis = ?',
        whereArgs: [dateMillis],
      );
    } else {
      await insertOrUpdateDailyGoal(DailyGoal(
        dateMillis: dateMillis,
        achievedMinutes: minutes,
      ));
    }
  }

  Future<void> addAchievedPomodoro(int dateMillis) async {
    final db = await database;
    final goal = await getDailyGoalForDate(dateMillis);
    if (goal != null) {
      await db.update(
        'daily_goals',
        {'achievedPomodoros': goal.achievedPomodoros + 1},
        where: 'dateMillis = ?',
        whereArgs: [dateMillis],
      );
    } else {
      await insertOrUpdateDailyGoal(DailyGoal(
        dateMillis: dateMillis,
        achievedPomodoros: 1,
      ));
    }
  }

  Future<int> getLatestStreak() async {
    final db = await database;
    final rows = await db.query(
      'daily_goals',
      orderBy: 'dateMillis DESC',
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return DailyGoal.fromMap(rows.first).streakCount;
  }

  // ============================================================
  // STUDY SUBJECT CRUD
  // ============================================================
  Future<int> insertStudySubject(StudySubject subject) async {
    final db = await database;
    return db.insert('study_subjects', subject.toMap()..remove('id'));
  }

  Future<int> updateStudySubject(StudySubject subject) async {
    final db = await database;
    return db.update('study_subjects', subject.toMap(), where: 'id = ?', whereArgs: [subject.id]);
  }

  Future<int> deleteStudySubject(int id) async {
    final db = await database;
    return db.delete('study_subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<StudySubject>> getAllStudySubjects() async {
    final db = await database;
    final rows = await db.query('study_subjects', orderBy: 'name ASC');
    return rows.map((r) => StudySubject.fromMap(r)).toList();
  }

  Future<StudySubject?> getStudySubject(int id) async {
    final db = await database;
    final rows = await db.query('study_subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudySubject.fromMap(rows.first);
  }

  Future<StudySubject?> getStudySubjectByName(String name) async {
    final db = await database;
    final rows = await db.query('study_subjects', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    return StudySubject.fromMap(rows.first);
  }

  Future<void> addSubjectFocusMinutes(int id, int minutes) async {
    final db = await database;
    await db.rawUpdate("""
      UPDATE study_subjects
      SET totalFocusMinutes = totalFocusMinutes + ?
      WHERE id = ?
    """, [minutes, id]);
  }
}
