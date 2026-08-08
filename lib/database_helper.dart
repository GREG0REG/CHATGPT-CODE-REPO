import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/event.dart';
import '../models/study_plan.dart';
import '../models/study_plan_item.dart';
import '../models/syllabus_subject.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subtopic.dart';
import '../models/syllabus_resource.dart';
import '../models/syllabus_revision_schedule.dart';

/// Local-only SQLite storage. No network, no cloud sync.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'event_countdown.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        dateMillis INTEGER NOT NULL,
        startTimeMillis INTEGER,
        deadlineMillis INTEGER,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        colorHex TEXT DEFAULT '#2196F3',
        targetCompletionDateMillis INTEGER,
        totalMarksWeightage INTEGER,
        examCategory TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        weightage INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unitId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        status TEXT DEFAULT 'notStarted',
        difficulty TEXT,
        estimatedMinutes INTEGER,
        neetMarksWeightage INTEGER,
        timesRevised INTEGER DEFAULT 0,
        lastStudiedMillis INTEGER,
        targetCompletionDateMillis INTEGER,
        mcqsAttempted INTEGER DEFAULT 0,
        mcqsCorrect INTEGER DEFAULT 0,
        lastMockScore INTEGER,
        bestMockScore INTEGER,
        totalStudyMinutes INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_subtopics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        status TEXT DEFAULT 'notStarted',
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_resources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER,
        subtopicId INTEGER,
        resourceType TEXT NOT NULL,
        title TEXT NOT NULL,
        filePath TEXT,
        url TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_revision_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        revisionNumber INTEGER NOT NULL,
        scheduledDateMillis INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        performanceScore INTEGER,
        actualRevisionDateMillis INTEGER,
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE study_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        eventId INTEGER,
        subjectId INTEGER,
        startDateMillis INTEGER NOT NULL,
        endDateMillis INTEGER NOT NULL,
        dailyStudyMinutes INTEGER DEFAULT 120,
        isActive INTEGER DEFAULT 1,
        priority INTEGER DEFAULT 2,
        strategy TEXT DEFAULT 'balanced',
        bufferDays INTEGER DEFAULT 7,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE study_plan_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        planId INTEGER NOT NULL,
        topicId INTEGER,
        scheduledDateMillis INTEGER NOT NULL,
        allocatedMinutes INTEGER DEFAULT 60,
        isCompleted INTEGER DEFAULT 0,
        notes TEXT,
        orderIndex INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mock_test_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER,
        testName TEXT NOT NULL,
        score INTEGER NOT NULL,
        totalMarks INTEGER NOT NULL,
        rank INTEGER,
        totalStudents INTEGER,
        dateMillis INTEGER NOT NULL,
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chapter_deadlines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        targetDateMillis INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER,
        planItemId INTEGER,
        startTimeMillis INTEGER NOT NULL,
        endTimeMillis INTEGER,
        durationMinutes INTEGER,
        notes TEXT,
        mood TEXT,
        productivity INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _onCreate(db, newVersion);
    }
  }

  // EVENT METHODS
  Future<int> insertEvent(Event event) async {
    final db = await database;
    return db.insert('events', event.toMap()..remove('id'));
  }

  Future<int> updateEvent(Event event) async {
    final db = await database;
    return db.update('events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
  }

  Future<int> deleteEvent(int id) async {
    final db = await database;
    return db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Event>> getAllEventsSorted() async {
    final db = await database;
    try {
      final rows = await db.query('events', orderBy: 'dateMillis ASC');
      return rows.map((r) => Event.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Event?> getEvent(int id) async {
    final db = await database;
    try {
      final rows = await db.query('events', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      return Event.fromMap(rows.first);
    } catch (e) {
      return null;
    }
  }

  Future<void> replaceAllEvents(List<Event> events) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('events');
      for (final e in events) {
        await txn.insert('events', e.toMap()..remove('id'));
      }
    });
  }

  // SYLLABUS SUBJECT METHODS
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
    return db.transaction((txn) async {
      final units = await txn.query('syllabus_units', where: 'subjectId = ?', whereArgs: [id]);
      for (final u in units) {
        final unitId = u['id'] as int;
        final topics = await txn.query('syllabus_topics', where: 'unitId = ?', whereArgs: [unitId]);
        for (final t in topics) {
          final topicId = t['id'] as int;
          await txn.delete('syllabus_subtopics', where: 'topicId = ?', whereArgs: [topicId]);
          await txn.delete('syllabus_resources', where: 'topicId = ?', whereArgs: [topicId]);
          await txn.delete('syllabus_revision_schedules', where: 'topicId = ?', whereArgs: [topicId]);
          await txn.delete('chapter_deadlines', where: 'topicId = ?', whereArgs: [topicId]);
        }
        await txn.delete('syllabus_topics', where: 'unitId = ?', whereArgs: [unitId]);
      }
      await txn.delete('syllabus_units', where: 'subjectId = ?', whereArgs: [id]);
      return await txn.delete('syllabus_subjects', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<SyllabusSubject>> getAllSyllabusSubjects() async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_subjects', orderBy: 'createdAtMillis DESC');
      return rows.map((r) => SyllabusSubject.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<SyllabusSubject?> getSyllabusSubject(int id) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_subjects', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      return SyllabusSubject.fromMap(rows.first);
    } catch (e) {
      return null;
    }
  }

  // SYLLABUS UNIT METHODS
  Future<int> insertSyllabusUnit(SyllabusUnit unit) async {
    final db = await database;
    return db.insert('syllabus_units', unit.toMap()..remove('id'));
  }

  Future<int> updateSyllabusUnit(SyllabusUnit unit) async {
    final db = await database;
    return db.update('syllabus_units', unit.toMap(), where: 'id = ?', whereArgs: [unit.id]);
  }

  Future<List<SyllabusUnit>> getSyllabusUnitsForSubject(int subjectId) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_units', where: 'subjectId = ?', whereArgs: [subjectId], orderBy: 'orderIndex ASC');
      return rows.map((r) => SyllabusUnit.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // SYLLABUS TOPIC METHODS
  Future<int> insertSyllabusTopic(SyllabusTopic topic) async {
    final db = await database;
    return db.insert('syllabus_topics', topic.toMap()..remove('id'));
  }

  Future<int> updateSyllabusTopic(SyllabusTopic topic) async {
    final db = await database;
    return db.update('syllabus_topics', topic.toMap(), where: 'id = ?', whereArgs: [topic.id]);
  }

  Future<List<SyllabusTopic>> getSyllabusTopicsForUnit(int unitId) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_topics', where: 'unitId = ?', whereArgs: [unitId], orderBy: 'orderIndex ASC');
      return rows.map((r) => SyllabusTopic.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<SyllabusTopic?> getSyllabusTopic(int id) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_topics', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      return SyllabusTopic.fromMap(rows.first);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getSyllabusProgressForSubject(int subjectId) async {
    final db = await database;
    try {
      final units = await getSyllabusUnitsForSubject(subjectId);
      int total = 0;
      int completed = 0;
      for (final unit in units) {
        final topics = await getSyllabusTopicsForUnit(unit.id!);
        total += topics.length;
        completed += topics.where((t) => t.status == 'completed').length;
      }
      return {'total': total, 'completed': completed};
    } catch (e) {
      return {'total': 0, 'completed': 0};
    }
  }

  Future<Map<String, dynamic>> getSyllabusPaceAnalysis(int subjectId) async {
    final db = await database;
    try {
      final subject = await getSyllabusSubject(subjectId);
      if (subject == null || subject.targetCompletionDateMillis == null) {
        return {'status': null};
      }
      final units = await getSyllabusUnitsForSubject(subjectId);
      int totalTopics = 0;
      int completedTopics = 0;
      for (final unit in units) {
        final topics = await getSyllabusTopicsForUnit(unit.id!);
        totalTopics += topics.length;
        completedTopics += topics.where((t) => t.status == 'completed').length;
      }
      if (totalTopics == 0) return {'status': null};
      final now = DateTime.now().millisecondsSinceEpoch;
      final deadline = subject.targetCompletionDateMillis!;
      final created = subject.createdAtMillis;
      final totalDuration = deadline - created;
      final elapsed = now - created;
      final expectedProgress = totalDuration > 0 ? elapsed / totalDuration : 0.0;
      final actualProgress = completedTopics / totalTopics;
      final daysLeft = (deadline - now) ~/ 86400000;
      String status;
      if (actualProgress >= expectedProgress - 0.05) {
        status = 'On Track';
      } else if (actualProgress >= expectedProgress - 0.2) {
        status = 'Slightly Behind';
      } else {
        status = 'Behind Schedule';
      }
      return {
        'status': status,
        'remainingTopics': totalTopics - completedTopics,
        'daysLeft': daysLeft,
        'expectedProgress': expectedProgress,
        'actualProgress': actualProgress,
      };
    } catch (e) {
      return {'status': null};
    }
  }

  Future<Map<String, dynamic>> getTopicMcqStats(int topicId) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_topics', where: 'id = ?', whereArgs: [topicId]);
      if (rows.isEmpty) return {'attempted': 0, 'correct': 0, 'accuracy': 0.0};
      final topic = SyllabusTopic.fromMap(rows.first);
      final attempted = topic.mcqsAttempted ?? 0;
      final correct = topic.mcqsCorrect ?? 0;
      return {
        'attempted': attempted,
        'correct': correct,
        'accuracy': attempted > 0 ? (correct / attempted * 100).roundToDouble() : 0.0,
      };
    } catch (e) {
      return {'attempted': 0, 'correct': 0, 'accuracy': 0.0};
    }
  }

  Future<void> updateTopicMcqStats(int topicId, int attempted, int correct) async {
    final db = await database;
    await db.update('syllabus_topics', {'mcqsAttempted': attempted, 'mcqsCorrect': correct}, where: 'id = ?', whereArgs: [topicId]);
  }

  // SYLLABUS SUBTOPIC METHODS
  Future<int> insertSyllabusSubtopic(SyllabusSubtopic subtopic) async {
    final db = await database;
    return db.insert('syllabus_subtopics', subtopic.toMap()..remove('id'));
  }

  Future<int> updateSyllabusSubtopic(SyllabusSubtopic subtopic) async {
    final db = await database;
    return db.update('syllabus_subtopics', subtopic.toMap(), where: 'id = ?', whereArgs: [subtopic.id]);
  }

  Future<List<SyllabusSubtopic>> getSyllabusSubtopicsForTopic(int topicId) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_subtopics', where: 'topicId = ?', whereArgs: [topicId], orderBy: 'orderIndex ASC');
      return rows.map((r) => SyllabusSubtopic.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // SYLLABUS RESOURCE METHODS
  Future<int> insertSyllabusResource(SyllabusResource resource) async {
    final db = await database;
    return db.insert('syllabus_resources', resource.toMap()..remove('id'));
  }

  Future<int> deleteSyllabusResource(int id) async {
    final db = await database;
    return db.delete('syllabus_resources', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyllabusResource>> getSyllabusResourcesForTopic(int topicId) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_resources', where: 'topicId = ?', whereArgs: [topicId], orderBy: 'createdAtMillis DESC');
      return rows.map((r) => SyllabusResource.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // REVISION SCHEDULE METHODS
  Future<int> insertSyllabusRevisionSchedule(SyllabusRevisionSchedule revision) async {
    final db = await database;
    return db.insert('syllabus_revision_schedules', revision.toMap()..remove('id'));
  }

  Future<int> updateSyllabusRevisionSchedule(SyllabusRevisionSchedule revision) async {
    final db = await database;
    return db.update('syllabus_revision_schedules', revision.toMap(), where: 'id = ?', whereArgs: [revision.id]);
  }

  Future<List<SyllabusRevisionSchedule>> getSyllabusRevisionsForTopic(int topicId) async {
    final db = await database;
    try {
      final rows = await db.query('syllabus_revision_schedules', where: 'topicId = ?', whereArgs: [topicId], orderBy: 'revisionNumber ASC');
      return rows.map((r) => SyllabusRevisionSchedule.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> generateRevisionSchedules(int topicId) async {
    final db = await database;
    try {
      await db.delete('syllabus_revision_schedules', where: 'topicId = ?', whereArgs: [topicId]);
      final now = DateTime.now();
      final intervals = [1, 3, 7, 14, 30, 60];
      final nowMillis = now.millisecondsSinceEpoch;
      for (int i = 0; i < intervals.length; i++) {
        final scheduledDate = now.add(Duration(days: intervals[i]));
        final revision = SyllabusRevisionSchedule(
          topicId: topicId,
          revisionNumber: i + 1,
          scheduledDateMillis: DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day).millisecondsSinceEpoch,
          isCompleted: 0,
          createdAtMillis: nowMillis,
        );
        await db.insert('syllabus_revision_schedules', revision.toMap());
      }
      await db.update('syllabus_topics', {'timesRevised': 0, 'lastStudiedMillis': nowMillis}, where: 'id = ?', whereArgs: [topicId]);
    } catch (e) {
      // Silently fail if table doesn't exist yet
    }
  }

  Future<List<Map<String, dynamic>>> getTopicsForToday() async {
    final db = await database;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;
      final rows = await db.rawQuery('''
        SELECT r.*, t.name as topicName, t.status, t.difficulty, t.neetMarksWeightage,
               u.name as unitName, s.name as subjectName, s.colorHex
        FROM syllabus_revision_schedules r
        JOIN syllabus_topics t ON r.topicId = t.id
        JOIN syllabus_units u ON t.unitId = u.id
        JOIN syllabus_subjects s ON u.subjectId = s.id
        WHERE r.scheduledDateMillis >= ? AND r.scheduledDateMillis < ? AND r.isCompleted = 0
        ORDER BY r.revisionNumber ASC
      ''', [todayStart, todayEnd]);
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingRevisions(int daysAhead) async {
    final db = await database;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final futureEnd = todayStart + Duration(days: daysAhead).inMilliseconds;
      final rows = await db.rawQuery('''
        SELECT r.*, t.name as topicName, t.status, t.difficulty,
               u.name as unitName, s.name as subjectName, s.colorHex
        FROM syllabus_revision_schedules r
        JOIN syllabus_topics t ON r.topicId = t.id
        JOIN syllabus_units u ON t.unitId = u.id
        JOIN syllabus_subjects s ON u.subjectId = s.id
        WHERE r.scheduledDateMillis >= ? AND r.scheduledDateMillis < ? AND r.isCompleted = 0
        ORDER BY r.scheduledDateMillis ASC
      ''', [todayStart, futureEnd]);
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOverdueRevisions() async {
    final db = await database;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final rows = await db.rawQuery('''
        SELECT r.*, t.name as topicName, t.status, t.difficulty,
               u.name as unitName, s.name as subjectName, s.colorHex
        FROM syllabus_revision_schedules r
        JOIN syllabus_topics t ON r.topicId = t.id
        JOIN syllabus_units u ON t.unitId = u.id
        JOIN syllabus_subjects s ON u.subjectId = s.id
        WHERE r.scheduledDateMillis < ? AND r.isCompleted = 0
        ORDER BY r.scheduledDateMillis ASC
      ''', [todayStart]);
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRevisionStats() async {
    final db = await database;
    try {
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalRevisions,
          SUM(CASE WHEN isCompleted = 1 THEN 1 ELSE 0 END) as completedRevisions,
          AVG(CASE WHEN performanceScore IS NOT NULL THEN performanceScore END) as avgPerformance
        FROM syllabus_revision_schedules
      ''');
      return rows;
    } catch (e) {
      return [{'totalRevisions': 0, 'completedRevisions': 0, 'avgPerformance': 0.0}];
    }
  }

  // DEADLINE METHODS
  Future<int> insertChapterDeadline(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('chapter_deadlines', {...data, 'createdAtMillis': DateTime.now().millisecondsSinceEpoch});
  }

  Future<int> updateChapterDeadline(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('chapter_deadlines', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getChapterDeadlineForTopic(int topicId) async {
    final db = await database;
    try {
      final rows = await db.query('chapter_deadlines', where: 'topicId = ?', whereArgs: [topicId], orderBy: 'createdAtMillis DESC', limit: 1);
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getOverdueDeadlines() async {
    final db = await database;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final rows = await db.rawQuery('''
        SELECT d.*, t.name as topicName, t.status, t.difficulty,
               u.name as unitName, s.name as subjectName, s.colorHex
        FROM chapter_deadlines d
        JOIN syllabus_topics t ON d.topicId = t.id
        JOIN syllabus_units u ON t.unitId = u.id
        JOIN syllabus_subjects s ON u.subjectId = s.id
        WHERE d.targetDateMillis < ? AND d.isCompleted = 0 AND t.status != 'completed'
        ORDER BY d.targetDateMillis ASC
      ''', [todayStart]);
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingDeadlines(int daysAhead) async {
    final db = await database;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final futureEnd = todayStart + Duration(days: daysAhead).inMilliseconds;
      final rows = await db.rawQuery('''
        SELECT d.*, t.name as topicName, t.status, t.difficulty,
               u.name as unitName, s.name as subjectName, s.colorHex
        FROM chapter_deadlines d
        JOIN syllabus_topics t ON d.topicId = t.id
        JOIN syllabus_units u ON t.unitId = u.id
        JOIN syllabus_subjects s ON u.subjectId = s.id
        WHERE d.targetDateMillis >= ? AND d.targetDateMillis < ? AND d.isCompleted = 0 AND t.status != 'completed'
        ORDER BY d.targetDateMillis ASC
      ''', [todayStart, futureEnd]);
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<void> markDeadlineComplete(int topicId) async {
    final db = await database;
    try {
      await db.update('chapter_deadlines', {'isCompleted': 1}, where: 'topicId = ?', whereArgs: [topicId]);
    } catch (e) {
      // Silently fail
    }
  }

  // STUDY PLAN METHODS
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
    return db.transaction((txn) async {
      await txn.delete('study_plan_items', where: 'planId = ?', whereArgs: [id]);
      await txn.delete('study_sessions', where: 'planItemId IN (SELECT id FROM study_plan_items WHERE planId = ?)', whereArgs: [id]);
      return await txn.delete('study_plans', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<StudyPlan>> getAllStudyPlans() async {
    final db = await database;
    try {
      final rows = await db.query('study_plans', orderBy: 'createdAtMillis DESC');
      return rows.map((r) => StudyPlan.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<StudyPlanItem>> getStudyPlanItemsForPlan(int planId) async {
    final db = await database;
    try {
      final rows = await db.query('study_plan_items', where: 'planId = ?', whereArgs: [planId], orderBy: 'scheduledDateMillis ASC, orderIndex ASC');
      return rows.map((r) => StudyPlanItem.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<StudyPlanItem>> getStudyPlanItemsForPlanInDateRange(int planId, int startMillis, int endMillis) async {
    final db = await database;
    try {
      final rows = await db.query('study_plan_items', where: 'planId = ? AND scheduledDateMillis >= ? AND scheduledDateMillis < ?', whereArgs: [planId, startMillis, endMillis], orderBy: 'orderIndex ASC, scheduledDateMillis ASC');
      return rows.map((r) => StudyPlanItem.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

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
    final nowMillis = now.millisecondsSinceEpoch;
    final units = await getSyllabusUnitsForSubject(subjectId);
    List<SyllabusTopic> allTopics = [];
    for (final unit in units) {
      final topics = await getSyllabusTopicsForUnit(unit.id!);
      allTopics.addAll(topics.where((t) => t.status != 'completed'));
    }
    if (allTopics.isEmpty) {
      final plan = StudyPlan(
        name: name,
        subjectId: subjectId,
        eventId: eventId,
        startDateMillis: nowMillis,
        endDateMillis: now.add(const Duration(days: 7)).millisecondsSinceEpoch,
        dailyStudyMinutes: dailyStudyMinutes,
        strategy: strategy,
        bufferDays: bufferDays,
        createdAtMillis: nowMillis,
      );
      final planId = await insertStudyPlan(plan);
      return plan.copyWith(id: planId);
    }
    switch (strategy) {
      case 'hardFirst':
        allTopics.sort((a, b) {
          final diffOrder = {'hard': 0, 'medium': 1, 'easy': 2};
          return (diffOrder[a.difficulty] ?? 3).compareTo(diffOrder[b.difficulty] ?? 3);
        });
        break;
      case 'easyFirst':
        allTopics.sort((a, b) {
          final diffOrder = {'easy': 0, 'medium': 1, 'hard': 2};
          return (diffOrder[a.difficulty] ?? 3).compareTo(diffOrder[b.difficulty] ?? 3);
        });
        break;
      case 'marksWeighted':
        allTopics.sort((a, b) => (b.neetMarksWeightage ?? 0).compareTo(a.neetMarksWeightage ?? 0));
        break;
      default:
        allTopics.shuffle();
        break;
    }
    final totalMinutes = allTopics.fold<int>(0, (sum, t) => sum + (t.estimatedMinutes ?? 60));
    final totalDays = (totalMinutes / dailyStudyMinutes).ceil() + bufferDays;
    final endDate = now.add(Duration(days: totalDays));
    final plan = StudyPlan(
      name: name,
      subjectId: subjectId,
      eventId: eventId,
      startDateMillis: nowMillis,
      endDateMillis: endDate.millisecondsSinceEpoch,
      dailyStudyMinutes: dailyStudyMinutes,
      strategy: strategy,
      bufferDays: bufferDays,
      createdAtMillis: nowMillis,
    );
    final planId = await insertStudyPlan(plan);
    int currentDayOffset = 0;
    int minutesUsedToday = 0;
    int orderIndex = 0;
    for (final topic in allTopics) {
      final topicMinutes = topic.estimatedMinutes ?? 60;
      if (minutesUsedToday + topicMinutes > dailyStudyMinutes && minutesUsedToday > 0) {
        currentDayOffset++;
        minutesUsedToday = 0;
      }
      final scheduledDate = DateTime(now.year, now.month, now.day).add(Duration(days: currentDayOffset));
      final item = StudyPlanItem(
        planId: planId,
        topicId: topic.id,
        scheduledDateMillis: scheduledDate.millisecondsSinceEpoch,
        allocatedMinutes: topicMinutes,
        orderIndex: orderIndex++,
        createdAtMillis: nowMillis,
      );
      await insertStudyPlanItem(item);
      minutesUsedToday += topicMinutes;
    }
    return plan.copyWith(id: planId);
  }

  // MOCK TEST METHODS
  Future<int> insertMockTestHistory(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('mock_test_history', {...data, 'createdAtMillis': DateTime.now().millisecondsSinceEpoch});
  }

  Future<int> deleteMockTestHistory(int id) async {
    final db = await database;
    return db.delete('mock_test_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllMockTestHistory() async {
    final db = await database;
    try {
      final rows = await db.rawQuery('''
        SELECT m.*, s.name as subjectName, s.colorHex
        FROM mock_test_history m
        LEFT JOIN syllabus_subjects s ON m.subjectId = s.id
        ORDER BY m.dateMillis DESC
      ''');
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMockTestStats() async {
    final db = await database;
    try {
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalTests,
          AVG(CAST(score AS REAL) / CAST(totalMarks AS REAL) * 100) as avgPercentage,
          MAX(score) as bestScore,
          SUM(score) as totalScore,
          SUM(totalMarks) as totalMarksSum
        FROM mock_test_history
      ''');
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      return {'totalTests': 0, 'avgPercentage': 0.0, 'bestScore': 0};
    }
  }

  // STUDY SESSION METHODS (NEW)
  Future<int> insertStudySession(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('study_sessions', {...data, 'createdAtMillis': DateTime.now().millisecondsSinceEpoch});
  }

  Future<List<Map<String, dynamic>>> getStudySessionsForPlan(int planId) async {
    final db = await database;
    try {
      final rows = await db.rawQuery('''
        SELECT s.*, t.name as topicName
        FROM study_sessions s
        JOIN study_plan_items i ON s.planItemId = i.id
        JOIN syllabus_topics t ON i.topicId = t.id
        WHERE i.planId = ?
        ORDER BY s.startTimeMillis DESC
      ''', [planId]);
      return rows;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getStudySessionStats(int planId) async {
    final db = await database;
    try {
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalSessions,
          SUM(durationMinutes) as totalMinutes,
          AVG(durationMinutes) as avgSessionMinutes,
          AVG(productivity) as avgProductivity
        FROM study_sessions s
        JOIN study_plan_items i ON s.planItemId = i.id
        WHERE i.planId = ?
      ''', [planId]);
      if (rows.isEmpty) {
        return {'totalSessions': 0, 'totalMinutes': 0, 'avgSessionMinutes': 0.0, 'avgProductivity': 0.0};
      }
      return rows.first;
    } catch (e) {
      return {'totalSessions': 0, 'totalMinutes': 0, 'avgSessionMinutes': 0.0, 'avgProductivity': 0.0};
    }
  }

  Future<Map<String, dynamic>> getWeeklyStudyStats(int planId) async {
    final db = await database;
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) as sessionsThisWeek,
          SUM(durationMinutes) as minutesThisWeek,
          AVG(productivity) as avgProductivityThisWeek
        FROM study_sessions s
        JOIN study_plan_items i ON s.planItemId = i.id
        WHERE i.planId = ? AND s.startTimeMillis >= ?
      ''', [planId, weekAgo]);
      if (rows.isEmpty) {
        return {'sessionsThisWeek': 0, 'minutesThisWeek': 0, 'avgProductivityThisWeek': 0.0};
      }
      return rows.first;
    } catch (e) {
      return {'sessionsThisWeek': 0, 'minutesThisWeek': 0, 'avgProductivityThisWeek': 0.0};
    }
  }
}
