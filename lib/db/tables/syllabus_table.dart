// FILE: lib/db/tables/syllabus_table.dart
// GROUP E — syllabus_subjects, syllabus_units, syllabus_topics, syllabus_subtopics,
// syllabus_resources, syllabus_study_links, syllabus_revision_schedules,
// study_plans, study_plan_items, mock_test_history, chapter_deadlines

import 'package:sqflite/sqflite.dart';
import 'package:event_countdown/models/syllabus_subject.dart';
import 'package:event_countdown/models/syllabus_unit.dart';
import 'package:event_countdown/models/syllabus_topic.dart';
import 'package:event_countdown/models/syllabus_subtopic.dart';
import 'package:event_countdown/models/syllabus_resource.dart';
import 'package:event_countdown/models/syllabus_study_link.dart';
import 'package:event_countdown/models/syllabus_revision_schedule.dart';
import 'package:event_countdown/models/study_plan.dart';
import 'package:event_countdown/models/study_plan_item.dart';
import '../database_helper.dart';

mixin SyllabusTable on DatabaseHelper {
  // ============================================================
  // SYLLABUS SUBJECTS CRUD
  // ============================================================
  Future<int> insertSyllabusSubject(SyllabusSubject subject) async {
    final db = await database;
    return db.insert('syllabus_subjects', subject.toMap()..remove('id'));
  }

  Future<int> updateSyllabusSubject(SyllabusSubject subject) async {
    final db = await database;
    return db.update('syllabus_subjects', subject.toMap(), where: 'id = ?', whereArgs: [subject.id]);
  }

  Future<int> deleteSyllabusSubject(int id) async {
    final db = await database;
    final units = await getSyllabusUnitsForSubject(id);
    for (final unit in units) {
      await deleteSyllabusUnit(unit.id!);
    }
    return db.delete('syllabus_subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusSubject>> getAllSyllabusSubjects() async {
    final db = await database;
    final rows = await db.query('syllabus_subjects', orderBy: 'name ASC');
    return rows.map((r) => SyllabusSubject.fromMap(r)).toList();
  }

  Future<SyllabusSubject?> getSyllabusSubject(int id) async {
    final db = await database;
    final rows = await db.query('syllabus_subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SyllabusSubject.fromMap(rows.first);
  }

  // ============================================================
  // SYLLABUS UNITS CRUD
  // ============================================================
  Future<int> insertSyllabusUnit(SyllabusUnit unit) async {
    final db = await database;
    return db.insert('syllabus_units', unit.toMap()..remove('id'));
  }

  Future<int> updateSyllabusUnit(SyllabusUnit unit) async {
    final db = await database;
    return db.update('syllabus_units', unit.toMap(), where: 'id = ?', whereArgs: [unit.id]);
  }

  Future<int> deleteSyllabusUnit(int id) async {
    final db = await database;
    final topics = await getSyllabusTopicsForUnit(id);
    for (final topic in topics) {
      await deleteSyllabusTopic(topic.id!);
    }
    return db.delete('syllabus_units', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusUnit>> getSyllabusUnitsForSubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_units',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((r) => SyllabusUnit.fromMap(r)).toList();
  }

  Future<SyllabusUnit?> getSyllabusUnit(int id) async {
    final db = await database;
    final rows = await db.query('syllabus_units', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SyllabusUnit.fromMap(rows.first);
  }

  // ============================================================
  // SYLLABUS TOPICS CRUD
  // ============================================================
  Future<int> insertSyllabusTopic(SyllabusTopic topic) async {
    final db = await database;
    return db.insert('syllabus_topics', topic.toMap()..remove('id'));
  }

  Future<int> updateSyllabusTopic(SyllabusTopic topic) async {
    final db = await database;
    return db.update('syllabus_topics', topic.toMap(), where: 'id = ?', whereArgs: [topic.id]);
  }

  Future<int> deleteSyllabusTopic(int id) async {
    final db = await database;
    await db.delete('syllabus_subtopics', where: 'topicId = ?', whereArgs: [id]);
    await db.delete('syllabus_resources', where: 'topicId = ?', whereArgs: [id]);
    await db.delete('syllabus_study_links', where: 'topicId = ?', whereArgs: [id]);
    await db.delete('syllabus_revision_schedules', where: 'topicId = ?', whereArgs: [id]);
    await db.rawUpdate('UPDATE study_plan_items SET topicId = NULL WHERE topicId = ?', [id]);
    return db.delete('syllabus_topics', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusTopic>> getSyllabusTopicsForUnit(int unitId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_topics',
      where: 'unitId = ?',
      whereArgs: [unitId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((r) => SyllabusTopic.fromMap(r)).toList();
  }

  Future<SyllabusTopic?> getSyllabusTopic(int id) async {
    final db = await database;
    final rows = await db.query('syllabus_topics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SyllabusTopic.fromMap(rows.first);
  }

  // ============================================================
  // SYLLABUS SUBTOPICS CRUD
  // ============================================================
  Future<int> insertSyllabusSubtopic(SyllabusSubtopic subtopic) async {
    final db = await database;
    return db.insert('syllabus_subtopics', subtopic.toMap()..remove('id'));
  }

  Future<int> updateSyllabusSubtopic(SyllabusSubtopic subtopic) async {
    final db = await database;
    return db.update('syllabus_subtopics', subtopic.toMap(), where: 'id = ?', whereArgs: [subtopic.id]);
  }

  Future<int> deleteSyllabusSubtopic(int id) async {
    final db = await database;
    await db.delete('syllabus_resources', where: 'subtopicId = ?', whereArgs: [id]);
    return db.delete('syllabus_subtopics', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusSubtopic>> getSyllabusSubtopicsForTopic(int topicId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_subtopics',
      where: 'topicId = ?',
      whereArgs: [topicId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((r) => SyllabusSubtopic.fromMap(r)).toList();
  }

  Future<SyllabusSubtopic?> getSyllabusSubtopic(int id) async {
    final db = await database;
    final rows = await db.query('syllabus_subtopics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SyllabusSubtopic.fromMap(rows.first);
  }

  // ============================================================
  // SYLLABUS RESOURCES CRUD
  // ============================================================
  Future<int> insertSyllabusResource(SyllabusResource resource) async {
    final db = await database;
    return db.insert('syllabus_resources', resource.toMap()..remove('id'));
  }

  Future<int> updateSyllabusResource(SyllabusResource resource) async {
    final db = await database;
    return db.update('syllabus_resources', resource.toMap(), where: 'id = ?', whereArgs: [resource.id]);
  }

  Future<int> deleteSyllabusResource(int id) async {
    final db = await database;
    return db.delete('syllabus_resources', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusResource>> getSyllabusResourcesForTopic(int topicId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_resources',
      where: 'topicId = ?',
      whereArgs: [topicId],
      orderBy: 'createdAtMillis ASC',
    );
    return rows.map((r) => SyllabusResource.fromMap(r)).toList();
  }

  Future<List<SyllabusResource>> getSyllabusResourcesForSubtopic(int subtopicId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_resources',
      where: 'subtopicId = ?',
      whereArgs: [subtopicId],
      orderBy: 'createdAtMillis ASC',
    );
    return rows.map((r) => SyllabusResource.fromMap(r)).toList();
  }

  // ============================================================
  // SYLLABUS STUDY LINKS CRUD
  // ============================================================
  Future<int> insertSyllabusStudyLink(SyllabusStudyLink link) async {
    final db = await database;
    return db.insert('syllabus_study_links', link.toMap()..remove('id'));
  }

  Future<int> deleteSyllabusStudyLink(int id) async {
    final db = await database;
    return db.delete('syllabus_study_links', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusStudyLink>> getSyllabusStudyLinksForTopic(int topicId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_study_links',
      where: 'topicId = ?',
      whereArgs: [topicId],
      orderBy: 'createdAtMillis DESC',
    );
    return rows.map((r) => SyllabusStudyLink.fromMap(r)).toList();
  }

  Future<int> getStudyTimeForTopic(int topicId) async {
    final links = await getSyllabusStudyLinksForTopic(topicId);
    int totalMinutes = 0;
    for (final link in links) {
      final session = await getStudySession(link.studySessionId);
      if (session != null) {
        totalMinutes += session.durationMinutes;
      }
    }
    return totalMinutes;
  }

  // ============================================================
  // SYLLABUS REVISION SCHEDULES CRUD
  // ============================================================
  Future<int> insertSyllabusRevisionSchedule(SyllabusRevisionSchedule revision) async {
    final db = await database;
    return db.insert('syllabus_revision_schedules', revision.toMap()..remove('id'));
  }

  Future<int> updateSyllabusRevisionSchedule(SyllabusRevisionSchedule revision) async {
    final db = await database;
    return db.update('syllabus_revision_schedules', revision.toMap(), where: 'id = ?', whereArgs: [revision.id]);
  }

  Future<int> deleteSyllabusRevisionSchedule(int id) async {
    final db = await database;
    return db.delete('syllabus_revision_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusRevisionSchedule>> getSyllabusRevisionsForTopic(int topicId) async {
    final db = await database;
    final rows = await db.query(
      'syllabus_revision_schedules',
      where: 'topicId = ?',
      whereArgs: [topicId],
      orderBy: 'revisionNumber ASC',
    );
    return rows.map((r) => SyllabusRevisionSchedule.fromMap(r)).toList();
  }

  Future<List<SyllabusRevisionSchedule>> getAllRevisionSchedules() async {
    final db = await database;
    final maps = await db.query('syllabus_revision_schedules', orderBy: 'scheduledDateMillis ASC');
    return maps.map((m) => SyllabusRevisionSchedule.fromMap(m)).toList();
  }

  Future<void> generateRevisionSchedules(int topicId) async {
    final existing = await getSyllabusRevisionsForTopic(topicId);
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final base = now.millisecondsSinceEpoch;
    final intervals = [1, 3, 7, 14, 30];
    for (int i = 0; i < intervals.length; i++) {
      final date = now.add(Duration(days: intervals[i]));
      final schedule = SyllabusRevisionSchedule(
        topicId: topicId,
        revisionNumber: i + 1,
        scheduledDateMillis: date.millisecondsSinceEpoch,
        isCompleted: 0,
        createdAtMillis: base,
      );
      await insertSyllabusRevisionSchedule(schedule);
    }
  }

  // ============================================================
  // REVISION DASHBOARD QUERIES
  // ============================================================
  Future<List<Map<String, dynamic>>> getOverdueRevisions() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return db.rawQuery("""
      SELECT r.*, t.name as topicName, t.difficulty, u.name as unitName,
             s.name as subjectName, s.colorHex
      FROM syllabus_revision_schedules r
      JOIN syllabus_topics t ON r.topicId = t.id
      JOIN syllabus_units u ON t.unitId = u.id
      JOIN syllabus_subjects s ON u.subjectId = s.id
      WHERE r.scheduledDateMillis < ? AND r.isCompleted = 0
      ORDER BY r.scheduledDateMillis ASC
    """, [todayStart]);
  }

  Future<List<Map<String, dynamic>>> getUpcomingRevisions(int daysAhead) async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endMillis = todayStart + Duration(days: daysAhead).inMilliseconds;
    return db.rawQuery("""
      SELECT r.*, t.name as topicName, t.difficulty, u.name as unitName,
             s.name as subjectName, s.colorHex
      FROM syllabus_revision_schedules r
      JOIN syllabus_topics t ON r.topicId = t.id
      JOIN syllabus_units u ON t.unitId = u.id
      JOIN syllabus_subjects s ON u.subjectId = s.id
      WHERE r.scheduledDateMillis >= ? AND r.scheduledDateMillis <= ? AND r.isCompleted = 0
      ORDER BY r.scheduledDateMillis ASC
    """, [todayStart, endMillis]);
  }

  Future<Map<String, dynamic>> getRevisionStats() async {
    final db = await database;
    final totalResult = await db.rawQuery("""
      SELECT COUNT(*) as total FROM syllabus_revision_schedules
    """);
    final completedResult = await db.rawQuery("""
      SELECT COUNT(*) as completed FROM syllabus_revision_schedules WHERE isCompleted = 1
    """);
    final performanceResult = await db.rawQuery("""
      SELECT AVG(performanceScore) as avgPerformance 
      FROM syllabus_revision_schedules 
      WHERE performanceScore IS NOT NULL
    """);
    return {
      'totalRevisions': (totalResult.first['total'] as int?) ?? 0,
      'completedRevisions': (completedResult.first['completed'] as int?) ?? 0,
      'avgPerformance': (performanceResult.first['avgPerformance'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ============================================================
  // STUDY PLANS CRUD
  // ============================================================
  Future<int> insertStudyPlan(StudyPlan plan) async {
    final db = await database;
    return db.insert('study_plans', plan.toMap()..remove('id'));
  }

  Future<int> updateStudyPlan(StudyPlan plan) async {
    final db = await database;
    return db.update('study_plans', plan.toMap(), where: 'id = ?', whereArgs: [plan.id]);
  }

  Future<int> deleteStudyPlan(int id) async {
    final db = await database;
    await db.delete('study_plan_items', where: 'planId = ?', whereArgs: [id]);
    return db.delete('study_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<StudyPlan>> getAllStudyPlans() async {
    final db = await database;
    final rows = await db.query('study_plans', orderBy: 'startDateMillis DESC');
    return rows.map((r) => StudyPlan.fromMap(r)).toList();
  }

  Future<StudyPlan?> getStudyPlan(int id) async {
    final db = await database;
    final rows = await db.query('study_plans', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudyPlan.fromMap(rows.first);
  }

  Future<List<StudyPlan>> getActiveStudyPlans() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'study_plans',
      where: 'isActive = 1 AND startDateMillis <= ? AND endDateMillis >= ?',
      whereArgs: [now, now],
      orderBy: 'startDateMillis ASC',
    );
    return rows.map((r) => StudyPlan.fromMap(r)).toList();
  }

  // ============================================================
  // STUDY PLAN ITEMS CRUD
  // ============================================================
  Future<int> insertStudyPlanItem(StudyPlanItem item) async {
    final db = await database;
    return db.insert('study_plan_items', item.toMap()..remove('id'));
  }

  Future<int> updateStudyPlanItem(StudyPlanItem item) async {
    final db = await database;
    return db.update('study_plan_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteStudyPlanItem(int id) async {
    final db = await database;
    return db.delete('study_plan_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<StudyPlanItem>> getStudyPlanItemsForPlan(int planId) async {
    final db = await database;
    final rows = await db.query(
      'study_plan_items',
      where: 'planId = ?',
      whereArgs: [planId],
      orderBy: 'scheduledDateMillis ASC',
    );
    return rows.map((r) => StudyPlanItem.fromMap(r)).toList();
  }

  Future<List<StudyPlanItem>> getStudyPlanItemsForPlanInDateRange(
    int planId,
    int startMillis,
    int endMillis,
  ) async {
    final db = await database;
    final rows = await db.query(
      'study_plan_items',
      where: 'planId = ? AND scheduledDateMillis >= ? AND scheduledDateMillis < ?',
      whereArgs: [planId, startMillis, endMillis],
      orderBy: 'scheduledDateMillis ASC',
    );
    return rows.map((r) => StudyPlanItem.fromMap(r)).toList();
  }

  Future<void> completeStudyPlanItem(int id) async {
    final db = await database;
    await db.update(
      'study_plan_items',
      {'isCompleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateStudyPlanItemNotes(int id, String notes) async {
    final db = await database;
    return db.update(
      'study_plan_items',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // STUDY PLAN GENERATION
  // ============================================================
  Future<StudyPlan> generateStudyPlan({
    required String name,
    required int subjectId,
    required int dailyStudyMinutes,
    int? eventId,
    String strategy = 'balanced',
    int bufferDays = 7,
  }) async {
    final db = await database;
    final now = DateTime.now();

    int endDateMillis;
    if (eventId != null) {
      final eventMaps = await db.query('events', where: 'id = ?', whereArgs: [eventId]);
      if (eventMaps.isNotEmpty) {
        endDateMillis = eventMaps.first['dateMillis'] as int;
      } else {
        endDateMillis = now.add(const Duration(days: 30)).millisecondsSinceEpoch;
      }
    } else {
      endDateMillis = now.add(const Duration(days: 30)).millisecondsSinceEpoch;
    }

    final plan = StudyPlan(
      name: name,
      subjectId: subjectId,
      eventId: eventId,
      startDateMillis: now.millisecondsSinceEpoch,
      endDateMillis: endDateMillis,
      dailyStudyMinutes: dailyStudyMinutes,
      isActive: 1,
      strategy: strategy,
      bufferDays: bufferDays,
      createdAtMillis: now.millisecondsSinceEpoch,
    );
    final planId = await db.insert('study_plans', plan.toMap());

    final units = await getSyllabusUnitsForSubject(subjectId);
    List<SyllabusTopic> allTopics = [];
    for (final unit in units) {
      final topics = await getSyllabusTopicsForUnit(unit.id!);
      allTopics.addAll(topics
