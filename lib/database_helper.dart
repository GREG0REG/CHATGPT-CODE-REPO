import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'models/flashcard_review_history.dart';
import 'models/daily_card_goal.dart';

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
      version: 11, // BUMPED: was 10, now 11 for attendance & timetable suite
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
        if (oldVersion < 8) {
          await _migrateV7ToV8(db);
        }
        if (oldVersion < 9) {
          await _migrateV8ToV9(db);
        }
        if (oldVersion < 10) {
          await _migrateV9ToV10(db);
        }
        if (oldVersion < 11) {
          await _migrateV10ToV11(db); // NEW: v10→v11 adds attendance & timetable tables
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
    // FIXED: flashcards table now includes ALL columns from Flashcard model
    await db.execute("""
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectTag TEXT NOT NULL,
        frontText TEXT NOT NULL,
        backText TEXT NOT NULL,
        boxLevel INTEGER DEFAULT 1,
        lastReviewedMillis INTEGER,
        nextReviewMillis INTEGER,
        imagePath TEXT,
        audioFrontPath TEXT,
        audioBackPath TEXT,
        tagsJson TEXT DEFAULT '[]',
        totalReviews INTEGER DEFAULT 0,
        consecutiveCorrect INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL,
        isFavorite INTEGER DEFAULT 0,
        difficultyRating REAL DEFAULT 2.5,
        reviewHistoryJson TEXT
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
    
    // ---- FLASHCARD REVIEW HISTORY (v8) ----
    await db.execute("""
      CREATE TABLE flashcard_review_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cardId INTEGER NOT NULL,
        reviewedAtMillis INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        timeSpentSeconds INTEGER DEFAULT 0,
        boxLevelBefore INTEGER DEFAULT 1,
        boxLevelAfter INTEGER DEFAULT 1,
        sessionId TEXT
      )
    """);

    // ---- DAILY CARD GOALS (v8) ----
    await db.execute("""
      CREATE TABLE daily_card_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL UNIQUE,
        targetReviews INTEGER DEFAULT 20,
        achievedReviews INTEGER DEFAULT 0,
        targetNewCards INTEGER DEFAULT 5,
        achievedNewCards INTEGER DEFAULT 0,
        streakCount INTEGER DEFAULT 0
      )
    """);
    
    // ---- GRADE COMPONENTS (v8) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE grade_components (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        score REAL NOT NULL,
        totalPoints REAL NOT NULL DEFAULT 100,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    
    // ---- QUICK NOTES (v8) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE quick_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        subject TEXT NOT NULL DEFAULT 'General',
        createdAtMillis INTEGER NOT NULL,
        updatedAtMillis INTEGER
      )
    """);

    // ---- ATTENDANCE LOGS (v10, ENHANCED v11) ----
    await db.execute("""
      CREATE TABLE attendance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectName TEXT NOT NULL,
        subjectId INTEGER,
        scheduleId INTEGER,
        dateMillis INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'present',
        note TEXT,
        markedAtMillis INTEGER,
        isAutoGenerated INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // ---- ATTENDANCE SUBJECTS (v11) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE attendance_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        requiredPercentage REAL DEFAULT 75.0,
        maxAllowedAbsences INTEGER,
        semesterStartMillis INTEGER,
        semesterEndMillis INTEGER,
        colorHex TEXT DEFAULT '#2196F3',
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // ---- ATTENDANCE SCHEDULES (v11) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE attendance_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        startTimeMinutes INTEGER NOT NULL,
        endTimeMinutes INTEGER NOT NULL,
        room TEXT,
        professor TEXT,
        scheduleType TEXT DEFAULT 'lecture',
        isActive INTEGER DEFAULT 1
      )
    """);

    // ---- TIMETABLE CLASSES (v11) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE timetable_classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectName TEXT NOT NULL,
        classType TEXT DEFAULT 'lecture',
        dayOfWeek INTEGER NOT NULL,
        startTimeMinutes INTEGER NOT NULL,
        endTimeMinutes INTEGER NOT NULL,
        room TEXT,
        professor TEXT,
        colorHex TEXT DEFAULT '#2196F3',
        isRecurring INTEGER DEFAULT 1,
        startDateMillis INTEGER,
        endDateMillis INTEGER,
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // ---- TIMETABLE TASKS (v11) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE timetable_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        taskType TEXT NOT NULL,
        subjectName TEXT,
        dueDateMillis INTEGER,
        startTimeMinutes INTEGER,
        endTimeMinutes INTEGER,
        isAllDay INTEGER DEFAULT 0,
        colorHex TEXT DEFAULT '#2196F3',
        isCompleted INTEGER DEFAULT 0,
        reminderMinutes INTEGER DEFAULT 60,
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // ---- ACADEMIC CALENDAR (v11) ---- NEW TABLE
    await db.execute("""
      CREATE TABLE academic_calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isRecurringYearly INTEGER DEFAULT 0
      )
    """);
  }

  // ============================================
  // MIGRATIONS
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

  Future<void> _migrateV6ToV7(Database db) async {
    await db.execute('ALTER TABLE study_sessions ADD COLUMN notes TEXT');
  }

  // v7 -> v8 migration
  Future<void> _migrateV7ToV8(Database db) async {
    await db.execute("""
      CREATE TABLE flashcard_review_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cardId INTEGER NOT NULL,
        reviewedAtMillis INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        timeSpentSeconds INTEGER DEFAULT 0,
        boxLevelBefore INTEGER DEFAULT 1,
        boxLevelAfter INTEGER DEFAULT 1,
        sessionId TEXT
      )
    """);
    await db.execute("""
      CREATE TABLE daily_card_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL UNIQUE,
        targetReviews INTEGER DEFAULT 20,
        achievedReviews INTEGER DEFAULT 0,
        targetNewCards INTEGER DEFAULT 5,
        achievedNewCards INTEGER DEFAULT 0,
        streakCount INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE grade_components (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        score REAL NOT NULL,
        totalPoints REAL NOT NULL DEFAULT 100,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE quick_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        subject TEXT NOT NULL DEFAULT 'General',
        createdAtMillis INTEGER NOT NULL,
        updatedAtMillis INTEGER
      )
    """);
  }

  // v8 -> v9 migration
  Future<void> _migrateV8ToV9(Database db) async {
    await db.execute('ALTER TABLE flashcards ADD COLUMN imagePath TEXT');
    await db.execute('ALTER TABLE flashcards ADD COLUMN audioFrontPath TEXT');
    await db.execute('ALTER TABLE flashcards ADD COLUMN audioBackPath TEXT');
    await db.execute('ALTER TABLE flashcards ADD COLUMN tagsJson TEXT DEFAULT "[]"');
    await db.execute('ALTER TABLE flashcards ADD COLUMN totalReviews INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE flashcards ADD COLUMN consecutiveCorrect INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE flashcards ADD COLUMN createdAtMillis INTEGER');
    await db.execute('ALTER TABLE flashcards ADD COLUMN isFavorite INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE flashcards ADD COLUMN difficultyRating REAL DEFAULT 2.5');
    await db.execute('ALTER TABLE flashcards ADD COLUMN reviewHistoryJson TEXT');
    
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute('UPDATE flashcards SET createdAtMillis = ? WHERE createdAtMillis IS NULL', [now]);
  }

  // v9 -> v10 migration
  Future<void> _migrateV9ToV10(Database db) async {
    await db.execute("""
      CREATE TABLE attendance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectName TEXT NOT NULL,
        dateMillis INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'present',
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  // NEW: v10 -> v11 migration
  Future<void> _migrateV10ToV11(Database db) async {
    // Enhance existing attendance_logs with new columns
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN subjectId INTEGER');
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN scheduleId INTEGER');
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN markedAtMillis INTEGER');
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN isAutoGenerated INTEGER DEFAULT 0');

    // Create attendance_subjects table
    await db.execute("""
      CREATE TABLE attendance_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        requiredPercentage REAL DEFAULT 75.0,
        maxAllowedAbsences INTEGER,
        semesterStartMillis INTEGER,
        semesterEndMillis INTEGER,
        colorHex TEXT DEFAULT '#2196F3',
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // Create attendance_schedules table
    await db.execute("""
      CREATE TABLE attendance_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        startTimeMinutes INTEGER NOT NULL,
        endTimeMinutes INTEGER NOT NULL,
        room TEXT,
        professor TEXT,
        scheduleType TEXT DEFAULT 'lecture',
        isActive INTEGER DEFAULT 1
      )
    """);

    // Create timetable_classes table
    await db.execute("""
      CREATE TABLE timetable_classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectName TEXT NOT NULL,
        classType TEXT DEFAULT 'lecture',
        dayOfWeek INTEGER NOT NULL,
        startTimeMinutes INTEGER NOT NULL,
        endTimeMinutes INTEGER NOT NULL,
        room TEXT,
        professor TEXT,
        colorHex TEXT DEFAULT '#2196F3',
        isRecurring INTEGER DEFAULT 1,
        startDateMillis INTEGER,
        endDateMillis INTEGER,
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // Create timetable_tasks table
    await db.execute("""
      CREATE TABLE timetable_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        taskType TEXT NOT NULL,
        subjectName TEXT,
        dueDateMillis INTEGER,
        startTimeMinutes INTEGER,
        endTimeMinutes INTEGER,
        isAllDay INTEGER DEFAULT 0,
        colorHex TEXT DEFAULT '#2196F3',
        isCompleted INTEGER DEFAULT 0,
        reminderMinutes INTEGER DEFAULT 60,
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // Create academic_calendar table
    await db.execute("""
      CREATE TABLE academic_calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isRecurringYearly INTEGER DEFAULT 0
      )
    """);
  }

  // ============================================
  // EVENT CRUD
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
  // CUSTOM REMINDER CRUD
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
  // NOTIFICATION HISTORY CRUD
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
  // STUDY SESSION CRUD
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
  // SUBTASK CRUD
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
      where: 'eventTag = ?',
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
  // FLASHCARD CRUD
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
  // FLASHCARD REVIEW HISTORY CRUD (NEW - v8)
  // ============================================
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

  // ============================================
  // DAILY CARD GOAL CRUD (NEW - v8)
  // ============================================
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

  // ============================================
  // STUDY SCHEDULE CRUD
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
  // DAILY GOAL CRUD
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

  // ============================================
  // GRADE COMPONENT CRUD (NEW - v8)
  // ============================================
  Future<int> insertGradeComponent(Map<String, dynamic> component) async {
    final db = await database;
    final data = {
      'name': component['name'],
      'weight': component['weight'],
      'score': component['score'],
      'totalPoints': component['totalPoints'] ?? 100.0,
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('grade_components', data);
  }

  Future<int> updateGradeComponent(int id, Map<String, dynamic> component) async {
    final db = await database;
    final data = {
      'name': component['name'],
      'weight': component['weight'],
      'score': component['score'],
      'totalPoints': component['totalPoints'] ?? 100.0,
    };
    return db.update('grade_components', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGradeComponent(int id) async {
    final db = await database;
    return db.delete('grade_components', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllGradeComponents() async {
    final db = await database;
    final rows = await db.query('grade_components', orderBy: 'createdAtMillis DESC');
    return rows;
  }

  Future<void> clearGradeComponents() async {
    final db = await database;
    await db.delete('grade_components');
  }

  // ============================================
  // QUICK NOTES CRUD (NEW - v8)
  // ============================================
  Future<int> insertQuickNote(Map<String, dynamic> note) async {
    final db = await database;
    final data = {
      'title': note['title'],
      'content': note['content'],
      'subject': note['subject'] ?? 'General',
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      'updatedAtMillis': null,
    };
    return db.insert('quick_notes', data);
  }

  Future<int> updateQuickNote(int id, Map<String, dynamic> note) async {
    final db = await database;
    final data = {
      'title': note['title'],
      'content': note['content'],
      'subject': note['subject'] ?? 'General',
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.update('quick_notes', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteQuickNote(int id) async {
    final db = await database;
    return db.delete('quick_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllQuickNotes({String? subjectFilter}) async {
    final db = await database;
    if (subjectFilter != null && subjectFilter != 'All') {
      final rows = await db.query(
        'quick_notes',
        where: 'subject = ?',
        whereArgs: [subjectFilter],
        orderBy: 'createdAtMillis DESC',
      );
      return rows;
    }
    final rows = await db.query('quick_notes', orderBy: 'createdAtMillis DESC');
    return rows;
  }

  Future<Map<String, dynamic>?> getQuickNote(int id) async {
    final db = await database;
    final rows = await db.query('quick_notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ============================================
  // ATTENDANCE LOGS CRUD (ENHANCED - v11)
  // ============================================
  Future<int> insertAttendanceLog(Map<String, dynamic> log) async {
    final db = await database;
    final data = {
      'subjectName': log['subjectName'],
      'subjectId': log['subjectId'],
      'scheduleId': log['scheduleId'],
      'dateMillis': log['dateMillis'],
      'status': log['status'] ?? 'present',
      'note': log['note'],
      'markedAtMillis': log['markedAtMillis'] ?? DateTime.now().millisecondsSinceEpoch,
      'isAutoGenerated': log['isAutoGenerated'] ?? 0,
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('attendance_logs', data);
  }

  Future<int> updateAttendanceLog(int id, Map<String, dynamic> log) async {
    final db = await database;
    final data = {
      'subjectName': log['subjectName'],
      'subjectId': log['subjectId'],
      'scheduleId': log['scheduleId'],
      'dateMillis': log['dateMillis'],
      'status': log['status'],
      'note': log['note'],
      'markedAtMillis': log['markedAtMillis'],
      'isAutoGenerated': log['isAutoGenerated'] ?? 0,
    };
    return db.update('attendance_logs', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAttendanceLog(int id) async {
    final db = await database;
    return db.delete('attendance_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAttendanceLogsForSubject(String subjectName) async {
    final db = await database;
    final rows = await db.query(
      'attendance_logs',
      where: 'subjectName = ?',
      whereArgs: [subjectName],
      orderBy: 'dateMillis DESC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAttendanceLogsForDate(int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final rows = await db.query(
      'attendance_logs',
      where: 'dateMillis >= ? AND dateMillis < ?',
      whereArgs: [dateMillis, endOfDay],
      orderBy: 'dateMillis ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAllAttendanceLogs() async {
    final db = await database;
    final rows = await db.query('attendance_logs', orderBy: 'dateMillis DESC');
    return rows;
  }

  Future<Map<String, dynamic>?> getAttendanceLogForSubjectAndDate(String subjectName, int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final rows = await db.query(
      'attendance_logs',
      where: 'subjectName = ? AND dateMillis >= ? AND dateMillis < ?',
      whereArgs: [subjectName, dateMillis, endOfDay],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>> getAttendanceStatsForSubject(String subjectName) async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
        SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late,
        SUM(CASE WHEN status = 'excused' THEN 1 ELSE 0 END) as excused
      FROM attendance_logs
      WHERE subjectName = ?
    """, [subjectName]);
    return result.first;
  }

  Future<List<String>> getAttendanceSubjects() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT DISTINCT subjectName FROM attendance_logs ORDER BY subjectName ASC
    """);
    return rows.map((r) => r['subjectName'] as String).toList();
  }

  // ============================================
  // ATTENDANCE SUBJECTS CRUD (NEW - v11)
  // ============================================
  Future<int> insertAttendanceSubject(Map<String, dynamic> subject) async {
    final db = await database;
    final data = {
      'name': subject['name'],
      'requiredPercentage': subject['requiredPercentage'] ?? 75.0,
      'maxAllowedAbsences': subject['maxAllowedAbsences'],
      'semesterStartMillis': subject['semesterStartMillis'],
      'semesterEndMillis': subject['semesterEndMillis'],
      'colorHex': subject['colorHex'] ?? '#2196F3',
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('attendance_subjects', data);
  }

  Future<int> updateAttendanceSubject(int id, Map<String, dynamic> subject) async {
    final db = await database;
    final data = {
      'name': subject['name'],
      'requiredPercentage': subject['requiredPercentage'] ?? 75.0,
      'maxAllowedAbsences': subject['maxAllowedAbsences'],
      'semesterStartMillis': subject['semesterStartMillis'],
      'semesterEndMillis': subject['semesterEndMillis'],
      'colorHex': subject['colorHex'] ?? '#2196F3',
    };
    return db.update('attendance_subjects', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAttendanceSubject(int id) async {
    final db = await database;
    return db.delete('attendance_subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllAttendanceSubjects() async {
    final db = await database;
    final rows = await db.query('attendance_subjects', orderBy: 'name ASC');
    return rows;
  }

  Future<Map<String, dynamic>?> getAttendanceSubjectById(int id) async {
    final db = await database;
    final rows = await db.query('attendance_subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> getAttendanceSubjectByName(String name) async {
    final db = await database;
    final rows = await db.query('attendance_subjects', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ============================================
  // ATTENDANCE SCHEDULES CRUD (NEW - v11)
  // ============================================
  Future<int> insertAttendanceSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    final data = {
      'subjectId': schedule['subjectId'],
      'dayOfWeek': schedule['dayOfWeek'],
      'startTimeMinutes': schedule['startTimeMinutes'],
      'endTimeMinutes': schedule['endTimeMinutes'],
      'room': schedule['room'],
      'professor': schedule['professor'],
      'scheduleType': schedule['scheduleType'] ?? 'lecture',
      'isActive': schedule['isActive'] ?? 1,
    };
    return db.insert('attendance_schedules', data);
  }

  Future<int> updateAttendanceSchedule(int id, Map<String, dynamic> schedule) async {
    final db = await database;
    final data = {
      'subjectId': schedule['subjectId'],
      'dayOfWeek': schedule['dayOfWeek'],
      'startTimeMinutes': schedule['startTimeMinutes'],
      'endTimeMinutes': schedule['endTimeMinutes'],
      'room': schedule['room'],
      'professor': schedule['professor'],
      'scheduleType': schedule['scheduleType'] ?? 'lecture',
      'isActive': schedule['isActive'] ?? 1,
    };
    return db.update('attendance_schedules', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAttendanceSchedule(int id) async {
    final db = await database;
    return db.delete('attendance_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllAttendanceSchedules() async {
    final db = await database;
    final rows = await db.query('attendance_schedules', orderBy: 'dayOfWeek ASC, startTimeMinutes ASC');
    return rows;
  }

  Future<Map<String, dynamic>?> getAttendanceScheduleById(int id) async {
    final db = await database;
    final rows = await db.query('attendance_schedules', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getAttendanceSchedulesForSubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      'attendance_schedules',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'dayOfWeek ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAttendanceSchedulesForDay(int dayOfWeek) async {
    final db = await database;
    final rows = await db.query(
      'attendance_schedules',
      where: 'dayOfWeek = ? AND isActive = 1',
      whereArgs: [dayOfWeek],
      orderBy: 'startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getActiveAttendanceSchedules() async {
    final db = await database;
    final rows = await db.query(
      'attendance_schedules',
      where: 'isActive = 1',
      orderBy: 'dayOfWeek ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  // ============================================
  // TIMETABLE CLASSES CRUD (NEW - v11)
  // ============================================
  Future<int> insertTimetableClass(Map<String, dynamic> timetableClass) async {
    final db = await database;
    final data = {
      'subjectName': timetableClass['subjectName'],
      'classType': timetableClass['classType'] ?? 'lecture',
      'dayOfWeek': timetableClass['dayOfWeek'],
      'startTimeMinutes': timetableClass['startTimeMinutes'],
      'endTimeMinutes': timetableClass['endTimeMinutes'],
      'room': timetableClass['room'],
      'professor': timetableClass['professor'],
      'colorHex': timetableClass['colorHex'] ?? '#2196F3',
      'isRecurring': timetableClass['isRecurring'] ?? 1,
      'startDateMillis': timetableClass['startDateMillis'],
      'endDateMillis': timetableClass['endDateMillis'],
      'note': timetableClass['note'],
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('timetable_classes', data);
  }

  Future<int> updateTimetableClass(int id, Map<String, dynamic> timetableClass) async {
    final db = await database;
    final data = {
      'subjectName': timetableClass['subjectName'],
      'classType': timetableClass['classType'] ?? 'lecture',
      'dayOfWeek': timetableClass['dayOfWeek'],
      'startTimeMinutes': timetableClass['startTimeMinutes'],
      'endTimeMinutes': timetableClass['endTimeMinutes'],
      'room': timetableClass['room'],
      'professor': timetableClass['professor'],
      'colorHex': timetableClass['colorHex'] ?? '#2196F3',
      'isRecurring': timetableClass['isRecurring'] ?? 1,
      'startDateMillis': timetableClass['startDateMillis'],
      'endDateMillis': timetableClass['endDateMillis'],
      'note': timetableClass['note'],
    };
    return db.update('timetable_classes', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTimetableClass(int id) async {
    final db = await database;
    return db.delete('timetable_classes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllTimetableClasses() async {
    final db = await database;
    final rows = await db.query('timetable_classes', orderBy: 'dayOfWeek ASC, startTimeMinutes ASC');
    return rows;
  }

  Future<Map<String, dynamic>?> getTimetableClassById(int id) async {
    final db = await database;
    final rows = await db.query('timetable_classes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getTimetableClassesForSubject(String subjectName) async {
    final db = await database;
    final rows = await db.query(
      'timetable_classes',
      where: 'subjectName = ?',
      whereArgs: [subjectName],
      orderBy: 'dayOfWeek ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTimetableClassesForDay(int dayOfWeek) async {
    final db = await database;
    final rows = await db.query(
      'timetable_classes',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
      orderBy: 'startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTimetableClassesForDateRange(int startMillis, int endMillis) async {
    final db = await database;
    final rows = await db.query(
      'timetable_classes',
      where: '(startDateMillis IS NULL OR startDateMillis <= ?) AND (endDateMillis IS NULL OR endDateMillis >= ?)',
      whereArgs: [endMillis, startMillis],
      orderBy: 'dayOfWeek ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  // ============================================
  // TIMETABLE TASKS CRUD (NEW - v11)
  // ============================================
  Future<int> insertTimetableTask(Map<String, dynamic> task) async {
    final db = await database;
    final data = {
      'title': task['title'],
      'taskType': task['taskType'],
      'subjectName': task['subjectName'],
      'dueDateMillis': task['dueDateMillis'],
      'startTimeMinutes': task['startTimeMinutes'],
      'endTimeMinutes': task['endTimeMinutes'],
      'isAllDay': task['isAllDay'] ?? 0,
      'colorHex': task['colorHex'] ?? '#2196F3',
      'isCompleted': task['isCompleted'] ?? 0,
      'reminderMinutes': task['reminderMinutes'] ?? 60,
      'note': task['note'],
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('timetable_tasks', data);
  }

  Future<int> updateTimetableTask(int id, Map<String, dynamic> task) async {
    final db = await database;
    final data = {
      'title': task['title'],
      'taskType': task['taskType'],
      'subjectName': task['subjectName'],
      'dueDateMillis': task['dueDateMillis'],
      'startTimeMinutes': task['startTimeMinutes'],
      'endTimeMinutes': task['endTimeMinutes'],
      'isAllDay': task['isAllDay'] ?? 0,
      'colorHex': task['colorHex'] ?? '#2196F3',
      'isCompleted': task['isCompleted'] ?? 0,
      'reminderMinutes': task['reminderMinutes'] ?? 60,
      'note': task['note'],
    };
    return db.update('timetable_tasks', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTimetableTask(int id) async {
    final db = await database;
    return db.delete('timetable_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllTimetableTasks() async {
    final db = await database;
    final rows = await db.query('timetable_tasks', orderBy: 'dueDateMillis ASC, startTimeMinutes ASC');
    return rows;
  }

  Future<Map<String, dynamic>?> getTimetableTaskById(int id) async {
    final db = await database;
    final rows = await db.query('timetable_tasks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getTimetableTasksForSubject(String subjectName) async {
    final db = await database;
    final rows = await db.query(
      'timetable_tasks',
      where: 'subjectName = ?',
      whereArgs: [subjectName],
      orderBy: 'dueDateMillis ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTimetableTasksForDate(int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final rows = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ?',
      whereArgs: [dateMillis, endOfDay],
      orderBy: 'startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTimetableTasksForDateRange(int startMillis, int endMillis) async {
    final db = await database;
    final rows = await db.query(
      'timetable_tasks',
      where: 'dueDateMillis >= ? AND dueDateMillis < ?',
      whereArgs: [startMillis, endMillis],
      orderBy: 'dueDateMillis ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getPendingTimetableTasks() async {
    final db = await database;
    final rows = await db.query(
      'timetable_tasks',
      where: 'isCompleted = 0',
      orderBy: 'dueDateMillis ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  Future<void> toggleTimetableTaskComplete(int id, bool completed) async {
    final db = await database;
    await db.update(
      'timetable_tasks',
      {'isCompleted': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // ACADEMIC CALENDAR CRUD (NEW - v11)
  // ============================================
  Future<int> insertAcademicCalendarEntry(Map<String, dynamic> entry) async {
    final db = await database;
    final data = {
      'dateMillis': entry['dateMillis'],
      'name': entry['name'],
      'type': entry['type'],
      'isRecurringYearly': entry['isRecurringYearly'] ?? 0,
    };
    return db.insert('academic_calendar', data);
  }

  Future<int> updateAcademicCalendarEntry(int id, Map<String, dynamic> entry) async {
    final db = await database;
    final data = {
      'dateMillis': entry['dateMillis'],
      'name': entry['name'],
      'type': entry['type'],
      'isRecurringYearly': entry['isRecurringYearly'] ?? 0,
    };
    return db.update('academic_calendar', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAcademicCalendarEntry(int id) async {
    final db = await database;
    return db.delete('academic_calendar', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllAcademicCalendarEntries() async {
    final db = await database;
    final rows = await db.query('academic_calendar', orderBy: 'dateMillis ASC');
    return rows;
  }

  Future<Map<String, dynamic>?> getAcademicCalendarEntryById(int id) async {
    final db = await database;
    final rows = await db.query('academic_calendar', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getAcademicCalendarEntriesForDate(int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final rows = await db.query(
      'academic_calendar',
      where: 'dateMillis >= ? AND dateMillis < ?',
      whereArgs: [dateMillis, endOfDay],
      orderBy: 'dateMillis ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAcademicCalendarEntriesForDateRange(int startMillis, int endMillis) async {
    final db = await database;
    final rows = await db.query(
      'academic_calendar',
      where: 'dateMillis >= ? AND dateMillis < ?',
      whereArgs: [startMillis, endMillis],
      orderBy: 'dateMillis ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAcademicCalendarEntriesByType(String type) async {
    final db = await database;
    final rows = await db.query(
      'academic_calendar',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'dateMillis ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getRecurringAcademicCalendarEntries() async {
    final db = await database;
    final rows = await db.query(
      'academic_calendar',
      where: 'isRecurringYearly = 1',
      orderBy: 'dateMillis ASC',
    );
    return rows;
  }

  // ============================================
  // COMPREHENSIVE EXPORT/IMPORT (FIX for Issue 56)
  // ============================================

  /// Exports all database tables as raw maps.
  /// Returns a map where keys are table names and values are lists of row maps.
  Future<Map<String, List<Map<String, dynamic>>>> exportAllTables() async {
    final db = await database;
    final result = <String, List<Map<String, dynamic>>>{};

    const tables = [
      'events',
      'custom_reminders',
      'notification_history',
      'study_sessions',
      'subtasks',
      'flashcards',
      'study_schedules',
      'daily_goals',
      'study_subjects',
      'flashcard_review_history',
      'daily_card_goals',
      'grade_components',
      'quick_notes',
      'attendance_logs',
      'attendance_subjects',
      'attendance_schedules',
      'timetable_classes',
      'timetable_tasks',
      'academic_calendar',
    ];

    for (final table in tables) {
      try {
        final rows = await db.query(table);
        result[table] = rows;
      } catch (e) {
        // Table might not exist in older database versions
        result[table] = [];
      }
    }

    return result;
  }

  /// Imports all database tables from raw maps.
  /// Runs inside a transaction -- if any table fails, the entire import rolls back.
  Future<void> importAllTables(Map<String, List<Map<String, dynamic>>> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in data.entries) {
        final table = entry.key;
        final rows = entry.value;

        // Check if table exists before operating
        final tableCheck = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (tableCheck.isEmpty) continue;

        await txn.delete(table);
        for (final row in rows) {
          await txn.insert(table, row);
        }
      }
    });
  }

  // ============================================
  // UTILITY
  // ============================================
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
}
