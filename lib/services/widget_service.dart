import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'models/event.dart';
import 'models/custom_reminder.dart';
import 'models/notification_history.dart';
import 'models/study_session.dart';
import 'models/subtask.dart';
import 'models/flashcard.dart';
import 'models/study_schedule.dart';
import 'models/daily_goal.dart';
import 'models/study_subject.dart';

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
      version: 7,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1ToV2(db);
        }
        if (oldVersion < 3) {
          await _migrateV2ToV3(db);
        }
        if (oldVersion < 4) {
          await _migrateV3ToV4(db);
        }
        if (oldVersion < 5) {
          await _migrateV4ToV5(db);
        }
        if (oldVersion < 6) {
          await _migrateV5ToV6(db);
        }
        if (oldVersion < 7) {
          await _migrateV6ToV7(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // ---- EXISTING TABLES (UNCHANGED) ----
    await db.execute("""
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        dateMillis INTEGER NOT NULL,
        startTimeMillis INTEGER,
        deadlineMillis INTEGER,
        notes TEXT,
        recurrence INTEGER DEFAULT 0,
        recurrenceInterval INTEGER DEFAULT 1,
        yearlyUseSpecificDates INTEGER DEFAULT 0,
        yearlySpecificDatesJson TEXT,
        excludedDatesJson TEXT,
        iconName TEXT,
        priority INTEGER DEFAULT 2,
        subjectTag TEXT,
        isCompleted INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE custom_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        minutesBefore INTEGER NOT NULL,
        type TEXT DEFAULT 'notification',
        soundUri TEXT,
        isEnabled INTEGER DEFAULT 1
      )
    """);
    await db.execute("""
      CREATE TABLE notification_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        eventTitle TEXT NOT NULL,
        reminderType TEXT NOT NULL,
        sentAtMillis INTEGER NOT NULL
      )
    """);

    // ---- STUDY SUITE TABLES ----
    await db.execute("""
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        subjectTag TEXT,
        durationMinutes INTEGER NOT NULL,
        completedAtMillis INTEGER NOT NULL,
        sessionType TEXT DEFAULT 'pomodoro',
        notes TEXT
      )
    """);
    await db.execute("""
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        title TEXT NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        orderIndex INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectTag TEXT NOT NULL,
        frontText TEXT NOT NULL,
        backText TEXT NOT NULL,
        boxLevel INTEGER DEFAULT 1,
        lastReviewedMillis INTEGER,
        nextReviewMillis INTEGER
      )
    """);
    await db.execute("""
      CREATE TABLE study_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        subjectTag TEXT,
        suggestedDateMillis INTEGER NOT NULL,
        suggestedDurationMinutes INTEGER DEFAULT 25,
        isCompleted INTEGER DEFAULT 0,
        isAccepted INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE daily_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL UNIQUE,
        targetMinutes INTEGER DEFAULT 120,
        targetPomodoros INTEGER DEFAULT 4,
        achievedMinutes INTEGER DEFAULT 0,
        achievedPomodoros INTEGER DEFAULT 0,
        streakCount INTEGER DEFAULT 0
      )
    """);

    // ---- STUDY SUBJECTS (v6) ----
    await db.execute("""
      CREATE TABLE study_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        colorHex TEXT DEFAULT '#2196F3',
        totalFocusMinutes INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  // ============================================
  // EXISTING MIGRATIONS (PRESERVED EXACTLY)
  // ============================================
  Future<void> _migrateV1ToV2(Database db) async {
    await db.execute('ALTER TABLE events ADD COLUMN recurrence INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE events ADD COLUMN recurrenceInterval INTEGER DEFAULT 1');
    await db.execute('ALTER TABLE events ADD COLUMN yearlyUseSpecificDates INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE events ADD COLUMN yearlySpecificDatesJson TEXT');
    await db.execute('ALTER TABLE events ADD COLUMN excludedDatesJson TEXT');
  }

  Future<void> _migrateV2ToV3(Database db) async {
    await db.execute('ALTER TABLE custom_reminders ADD COLUMN isEnabled INTEGER DEFAULT 1');
  }

  Future<void> _migrateV3ToV4(Database db) async {
    await db.execute('ALTER TABLE events ADD COLUMN iconName TEXT');
    await db.execute('ALTER TABLE events ADD COLUMN priority INTEGER DEFAULT 2');
    await db.execute('ALTER TABLE events ADD COLUMN subjectTag TEXT');
    await db.execute('ALTER TABLE events ADD COLUMN isCompleted INTEGER DEFAULT 0');
  }

  Future<void> _migrateV4ToV5(Database db) async {
    await db.execute("""
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        subjectTag TEXT,
        durationMinutes INTEGER NOT NULL,
        completedAtMillis INTEGER NOT NULL,
        sessionType TEXT DEFAULT 'pomodoro'
      )
    """);
    await db.execute("""
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        title TEXT NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        orderIndex INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectTag TEXT NOT NULL,
        frontText TEXT NOT NULL,
        backText TEXT NOT NULL,
        boxLevel INTEGER DEFAULT 1,
        lastReviewedMillis INTEGER,
        nextReviewMillis INTEGER
      )
    """);
    await db.execute("""
      CREATE TABLE study_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        subjectTag TEXT,
        suggestedDateMillis INTEGER NOT NULL,
        suggestedDurationMinutes INTEGER DEFAULT 25,
        isCompleted INTEGER DEFAULT 0,
        isAccepted INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE daily_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL UNIQUE,
        targetMinutes INTEGER DEFAULT 120,
        targetPomodoros INTEGER DEFAULT 4,
        achievedMinutes INTEGER DEFAULT 0,
        achievedPomodoros INTEGER DEFAULT 0,
        streakCount INTEGER DEFAULT 0
      )
    """);
  }

  // v5 -> v6 migration (study subjects)
  Future<void> _migrateV5ToV6(Database db) async {
    await db.execute("""
      CREATE TABLE study_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        colorHex TEXT DEFAULT '#2196F3',
        totalFocusMinutes INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  // v6 -> v7 migration (session notes)
  Future<void> _migrateV6ToV7(Database db) async {
    await db.execute('ALTER TABLE study_sessions ADD COLUMN notes TEXT');
  }

  // ============================================
  // EXISTING EVENT CRUD (UNCHANGED)
  // ============================================
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
    await db.delete('subtasks', where: 'eventId = ?', whereArgs: [id]);
    await db.delete('study_schedules', where: 'eventId = ?', whereArgs: [id]);
    await db.delete('custom_reminders', where: 'eventId = ?', whereArgs: [id]);
    return db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Event>> getAllEventsSorted() async {
    final db = await database;
    final rows = await db.query('events', orderBy: 'dateMillis ASC');
    return rows.map((r) => Event.fromMap(r)).toList();
  }

  Future<Event?> getEvent(int id) async {
    final db = await database;
    final rows = await db.query('events', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Event.fromMap(rows.first);
  }

  Future<void> replaceAllEvents(List<Event> events) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('events');
      await txn.delete('custom_reminders');
      await txn.delete('subtasks');
      await txn.delete('study_schedules');
      for (final e in events) {
        await txn.insert('events', e.toMap()..remove('id'));
      }
    });
  }

  // ============================================
  // EXISTING CUSTOM REMINDER CRUD (UNCHANGED)
  // ============================================
  Future<int> insertCustomReminder(CustomReminder reminder) async {
    final db = await database;
    return db.insert('custom_reminders', reminder.toMap()..remove('id'));
  }

  Future<int> updateCustomReminder(CustomReminder reminder) async {
    final db = await database;
    return db.update('custom_reminders', reminder.toMap(), where: 'id = ?', whereArgs: [reminder.id]);
  }

  Future<int> deleteCustomReminder(int id) async {
    final db = await database;
    return db.delete('custom_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CustomReminder>> getCustomRemindersForEvent(int eventId) async {
    final db = await database;
    final rows = await db.query('custom_reminders', where: 'eventId = ?', whereArgs: [eventId]);
    return rows.map((r) => CustomReminder.fromMap(r)).toList();
  }

  // ============================================
  // EXISTING NOTIFICATION HISTORY CRUD (UNCHANGED)
  // ============================================
  Future<int> insertNotificationHistory(NotificationHistory history) async {
    final db = await database;
    return db.insert('notification_history', history.toMap()..remove('id'));
  }

  Future<List<NotificationHistory>> getNotificationHistory({int limit = 20}) async {
    final db = await database;
    final rows = await db.query('notification_history', orderBy: 'sentAtMillis DESC', limit: limit);
    return rows.map((r) => NotificationHistory.fromMap(r)).toList();
  }

  Future<void> clearNotificationHistory() async {
    final db = await database;
    await db.delete('notification_history');
  }

  // ============================================
  // EXISTING STUDY SESSION CRUD (UNCHANGED)
  // ============================================
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

  // NEW: Update session note
  Future<void> updateSessionNote(int id, String note) async {
    final db = await database;
    await db.update(
      'study_sessions',
      {'notes': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // EXISTING SUBTASK CRUD (UNCHANGED)
  // ============================================
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

  // ============================================
  // EXISTING FLASHCARD CRUD (UNCHANGED)
  // ============================================
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

  // ============================================
  // EXISTING STUDY SCHEDULE CRUD (UNCHANGED)
  // ============================================
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

  // ============================================
  // EXISTING DAILY GOAL CRUD (UNCHANGED)
  // ============================================
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

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  // ============================================
  // STUDY SUBJECT CRUD
  // ============================================
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
