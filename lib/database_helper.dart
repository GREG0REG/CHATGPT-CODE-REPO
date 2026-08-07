// FILE: lib/db/database_helper.dart
// COMPLETE REPLACEMENT — Version 16 (NEET Edition)
// FIXED: Import paths resolved, getAllClassSchedules() added
// FIXED: Event._validateMap now accepts bool AND int for boolean fields
// NEW: gpa_courses table with proper GPA schema
// NEW: NEET fields in events and study_sessions tables
// NEW: 5 NEET analytics methods
// NEW: DateTime convenience overloads for timetable, habit, reading APIs
// ALL v1-v15 migrations preserved, v15→v16 migration added

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:event_countdown/models/flashcard_review_history.dart';
import 'package:event_countdown/models/daily_card_goal.dart';
import 'package:event_countdown/models/event.dart';
import 'package:event_countdown/models/custom_reminder.dart';
import 'package:event_countdown/models/notification_history.dart';
import 'package:event_countdown/models/study_session.dart';
import 'package:event_countdown/models/subtask.dart';
import 'package:event_countdown/models/flashcard.dart';
import 'package:event_countdown/models/study_schedule.dart';
import 'package:event_countdown/models/daily_goal.dart';
import 'package:event_countdown/models/study_subject.dart';

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
      version: 17, // BUMPED: v16 adds NEET fields + gpa_courses + fixes
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateV1ToV2(db);
        if (oldVersion < 3) await _migrateV2ToV3(db);
        if (oldVersion < 4) await _migrateV3ToV4(db);
        if (oldVersion < 5) await _migrateV4ToV5(db);
        if (oldVersion < 6) await _migrateV5ToV6(db);
        if (oldVersion < 7) await _migrateV6ToV7(db);
        if (oldVersion < 8) await _migrateV7ToV8(db);
        if (oldVersion < 9) await _migrateV8ToV9(db);
        if (oldVersion < 10) await _migrateV9ToV10(db);
        if (oldVersion < 11) await _migrateV10ToV11(db);
        if (oldVersion < 12) await _migrateV11ToV12(db);
        if (oldVersion < 13) await _migrateV12ToV13(db);
        if (oldVersion < 14) await _migrateV13ToV14(db);
        if (oldVersion < 15) await _migrateV14ToV15(db);
        if (oldVersion < 16) await _migrateV15ToV16(db); // NEW: NEET + gpa_courses
        if (oldVersion < 17) await _migrateV16ToV17(db);
      },
    );
  }

    Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final result = await db.rawQuery("PRAGMA table_info($table)");
    final columns = result.map((c) => c['name'] as String).toList();
    if (!columns.contains(column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
   
    }

  Future<void> _createTables(Database db) async {
    // ---- EVENTS (with NEET fields v16) ----
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
        isCompleted INTEGER DEFAULT 0,
        isNeetExam INTEGER DEFAULT 0,
        neetTotalMarks INTEGER,
        neetTargetScore INTEGER,
        neetSubjectFocus TEXT,
        targetScore INTEGER,
        neetExamType TEXT,
        revisionRound TEXT,
        isPyqSession INTEGER DEFAULT 0,
        difficulty TEXT,
        studyDuration TEXT,
        studyModeTagsJson TEXT
      )
    """);

    // ---- CUSTOM REMINDERS ----
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

    // ---- NOTIFICATION HISTORY ----
    await db.execute("""
      CREATE TABLE notification_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        eventTitle TEXT NOT NULL,
        reminderType TEXT NOT NULL,
        sentAtMillis INTEGER NOT NULL
      )
    """);

    // ---- STUDY SESSIONS (with NEET fields v16) ----
    await db.execute("""
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        subjectTag TEXT,
        durationMinutes INTEGER NOT NULL,
        completedAtMillis INTEGER NOT NULL,
        sessionType TEXT DEFAULT 'pomodoro',
        notes TEXT,
        distractionCount INTEGER DEFAULT 0,
        intensityRating INTEGER DEFAULT 0,
        topicTag TEXT,
        neetSubject INTEGER,
        mcqsAttempted INTEGER DEFAULT 0,
        mcqsCorrect INTEGER DEFAULT 0,
        difficultyLevel INTEGER DEFAULT 1,
        revisionRound INTEGER DEFAULT 0,
        mockTestScore INTEGER,
        mockTestRank INTEGER
      )
    """);
    

    // ---- SUBTASKS ----
    await db.execute("""
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        title TEXT NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        orderIndex INTEGER DEFAULT 0
      )
    """);

    // ---- FLASHCARDS ----
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

    // ---- STUDY SCHEDULES ----
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

     // ---- EVENTS TABLE (with NEET fields) ----
    await db.execute("""
      CREATE TABLE IF NOT EXISTS events (
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
        isCompleted INTEGER DEFAULT 0,
        isNeetExam INTEGER DEFAULT 0,
        neetTotalMarks INTEGER,
        neetTargetScore INTEGER,
        neetSubjectFocus TEXT,
        targetScore INTEGER,
        neetExamType TEXT,
        revisionRound TEXT,
        isPyqSession INTEGER DEFAULT 0,
        difficulty TEXT,
        studyDuration TEXT,
        studyModeTagsJson TEXT
      )
    """);
    
    // ---- DAILY GOALS ----
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

    // ---- GRADE COMPONENTS (v8) — LEGACY, preserved for backward compat ----
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

    // ---- GPA COURSES (v16) — NEW proper GPA schema ----
    await db.execute("""
      CREATE TABLE gpa_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        credits INTEGER NOT NULL DEFAULT 3,
        grade TEXT NOT NULL,
        gradePoints REAL NOT NULL,
        semester TEXT DEFAULT 'Current',
        subjectCategory TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // ---- QUICK NOTES (v8) ----
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

    // ---- ATTENDANCE SUBJECTS (v11) ----
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

    // ---- ATTENDANCE SCHEDULES (v11) ----
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

    // ---- TIMETABLE CLASSES (v11) ----
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

    // ---- TIMETABLE TASKS (v11) ----
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

    // ---- ACADEMIC CALENDAR (v11) ----
    await db.execute("""
      CREATE TABLE academic_calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isRecurringYearly INTEGER DEFAULT 0
      )
    """);

    // ---- CLASS SCHEDULE (v12) ----
    await db.execute("""
      CREATE TABLE class_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectName TEXT NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        startTimeMinutes INTEGER NOT NULL,
        endTimeMinutes INTEGER NOT NULL,
        room TEXT,
        colorHex TEXT DEFAULT '#2196F3',
        isActive INTEGER DEFAULT 1
      )
    """);

    // ---- HABITS (v12, ENHANCED v13) ----
    await db.execute("""
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subjectName TEXT,
        colorHex TEXT DEFAULT '#4CAF50',
        targetPerWeek INTEGER DEFAULT 7,
        reminderTimeMinutes INTEGER,
        createdAtMillis INTEGER NOT NULL,
        isArchived INTEGER DEFAULT 0,
        habitType INTEGER DEFAULT 0,
        metricGoal INTEGER,
        unitLabel TEXT
      )
    """);

    // ---- HABIT LOGS (v12, ENHANCED v13) ----
    await db.execute("""
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        dateMillis INTEGER NOT NULL,
        completed INTEGER DEFAULT 1,
        note TEXT,
        metricValue INTEGER
      )
    """);

    // ---- READING BOOKS (v12) ----
    await db.execute("""
      CREATE TABLE reading_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        totalPages INTEGER NOT NULL,
        currentPage INTEGER DEFAULT 0,
        subjectName TEXT,
        colorHex TEXT DEFAULT '#2196F3',
        startDateMillis INTEGER,
        targetEndDateMillis INTEGER,
        dailyPageGoal INTEGER DEFAULT 20,
        minutesReadToday INTEGER DEFAULT 0,
        totalMinutesRead INTEGER DEFAULT 0,
        isCompleted INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    // ---- READING SESSIONS (v14) ----
    await db.execute("""
      CREATE TABLE reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        startPage INTEGER NOT NULL,
        endPage INTEGER NOT NULL,
        pagesRead INTEGER NOT NULL,
        minutesRead INTEGER NOT NULL,
        pagesPerMinute REAL,
        sessionDateMillis INTEGER NOT NULL,
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  // ============================================
  // MIGRATIONS v1-v15 (PRESERVED EXACTLY)
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
        sessionType TEXT DEFAULT 'pomodoro',
        notes TEXT,
        distractionCount INTEGER DEFAULT 0,
        intensityRating INTEGER DEFAULT 0,
        topicTag TEXT
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

  Future<void> _migrateV10ToV11(Database db) async {
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN subjectId INTEGER');
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN scheduleId INTEGER');
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN markedAtMillis INTEGER');
    await db.execute('ALTER TABLE attendance_logs ADD COLUMN isAutoGenerated INTEGER DEFAULT 0');
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

  Future<void> _migrateV11ToV12(Database db) async {
    await db.execute("""
      CREATE TABLE class_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectName TEXT NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        startTimeMinutes INTEGER NOT NULL,
        endTimeMinutes INTEGER NOT NULL,
        room TEXT,
        colorHex TEXT DEFAULT '#2196F3',
        isActive INTEGER DEFAULT 1
      )
    """);
    await db.execute("""
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subjectName TEXT,
        colorHex TEXT DEFAULT '#4CAF50',
        targetPerWeek INTEGER DEFAULT 7,
        reminderTimeMinutes INTEGER,
        createdAtMillis INTEGER NOT NULL,
        isArchived INTEGER DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        dateMillis INTEGER NOT NULL,
        completed INTEGER DEFAULT 1,
        note TEXT
      )
    """);
    await db.execute("""
      CREATE TABLE reading_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        totalPages INTEGER NOT NULL,
        currentPage INTEGER DEFAULT 0,
        subjectName TEXT,
        colorHex TEXT DEFAULT '#2196F3',
        startDateMillis INTEGER,
        targetEndDateMillis INTEGER,
        dailyPageGoal INTEGER DEFAULT 20,
        minutesReadToday INTEGER DEFAULT 0,
        totalMinutesRead INTEGER DEFAULT 0,
        isCompleted INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  Future<void> _migrateV12ToV13(Database db) async {
    await db.execute('ALTER TABLE habits ADD COLUMN habitType INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE habits ADD COLUMN metricGoal INTEGER');
    await db.execute('ALTER TABLE habits ADD COLUMN unitLabel TEXT');
    await db.execute('ALTER TABLE habit_logs ADD COLUMN metricValue INTEGER');
  }

  Future<void> _migrateV13ToV14(Database db) async {
    await db.execute("""
      CREATE TABLE reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        startPage INTEGER NOT NULL,
        endPage INTEGER NOT NULL,
        pagesRead INTEGER NOT NULL,
        minutesRead INTEGER NOT NULL,
        pagesPerMinute REAL,
        sessionDateMillis INTEGER NOT NULL,
        note TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  Future<void> _migrateV14ToV15(Database db) async {
    await db.execute('ALTER TABLE study_sessions ADD COLUMN distractionCount INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN intensityRating INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN topicTag TEXT');
  }

  // ═══════════════════════════════════════════════════════════════
  // NEW MIGRATION: v15 → v16 — NEET fields + gpa_courses table
  // ═══════════════════════════════════════════════════════════════
  Future<void> _migrateV15ToV16(Database db) async {
    // 1. Add NEET columns to 'events' table
    await _addColumnIfNotExists(db, 'events', 'targetScore', 'INTEGER');
    await _addColumnIfNotExists(db, 'events', 'neetExamType', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'revisionRound', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'isPyqSession', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'events', 'difficulty', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'studyDuration', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'studyModeTagsJson', 'TEXT');
    
    

    // 3. Add NEET columns to 'study_sessions' table
    await db.execute('ALTER TABLE study_sessions ADD COLUMN neetSubject INTEGER');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mcqsAttempted INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mcqsCorrect INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN difficultyLevel INTEGER DEFAULT 1');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN revisionRound INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mockTestScore INTEGER');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mockTestRank INTEGER');

    // 4. Create NEW 'gpa_courses' table (proper GPA schema)
    await db.execute("""
      CREATE TABLE gpa_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        credits INTEGER NOT NULL DEFAULT 3,
        grade TEXT NOT NULL,
        gradePoints REAL NOT NULL,
        semester TEXT DEFAULT 'Current',
        subjectCategory TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }
    Future<void> _migrateV16ToV17(Database db) async {
      await _addColumnIfNotExists(db, 'events', 'assignmentType', 'TEXT');
    }

  // ============================================
  // EVENT CRUD (PRESERVED)
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
  // CUSTOM REMINDER CRUD (PRESERVED)
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
  // NOTIFICATION HISTORY CRUD (PRESERVED)
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
  // STUDY SESSION CRUD (PRESERVED + NEET ENHANCED)
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

  // ============================================
  // NEW: Home Screen Helper Methods (v16.1)
  // ============================================

  /// Check if any study sessions exist on a specific date
  /// Returns true if student studied on that day
  Future<bool> hasStudySessionsOnDate(int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ?
    """, [dateMillis, endOfDay]);
    return ((result.first['count'] as int?) ?? 0) > 0;
  }

  /// Get today's attendance summary for home screen dashboard
  /// Returns: {'present': 3, 'absent': 1, 'total': 4, 'percentage': 75.0}
  Future<Map<String, dynamic>> getTodayAttendanceSummary() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;

    final result = await db.rawQuery("""
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
        SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late
      FROM attendance_logs
      WHERE dateMillis >= ? AND dateMillis < ?
    """, [todayStart, todayEnd]);

    final total = (result.first['total'] as int?) ?? 0;
    final present = (result.first['present'] as int?) ?? 0;
    final absent = (result.first['absent'] as int?) ?? 0;
    final late = (result.first['late'] as int?) ?? 0;
    final percentage = total > 0 ? ((present + late * 0.5) / total * 100) : 0.0;

    return {
      'total': total,
      'present': present,
      'absent': absent,
      'late': late,
      'percentage': percentage,
    };
  }

  /// Get upcoming events for next N days (for home screen reminders)
  Future<List<Event>> getUpcomingEvents(int daysAhead) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final endMillis = now + Duration(days: daysAhead).inMilliseconds;
    final rows = await db.query(
      'events',
      where: 'dateMillis >= ? AND dateMillis < ? AND isCompleted = 0',
      whereArgs: [now, endMillis],
      orderBy: 'dateMillis ASC',
      limit: 10,
    );
    return rows.map((r) => Event.fromMap(r)).toList();
  }

  /// Get overdue events (for home screen alerts)
  Future<List<Event>> getOverdueEvents() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'events',
      where: 'dateMillis < ? AND isCompleted = 0',
      whereArgs: [now],
      orderBy: 'dateMillis ASC',
      limit: 10,
    );
    return rows.map((r) => Event.fromMap(r)).toList();
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

  // ═══════════════════════════════════════════════════════════════
  // NEW: NEET ANALYTICS METHODS (v16)
  // ═══════════════════════════════════════════════════════════════

  /// Helper: Convert NEET subject index to name
  String _neetSubjectName(int index) {
    const names = ['Physics', 'Chemistry', 'Biology', 'General'];
    return (index >= 0 && index < names.length) ? names[index] : 'Unknown';
  }

  /// Get study sessions filtered by NEET subject (0=Physics, 1=Chemistry, 2=Biology, 3=General)
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

  /// Get today's study time broken down by NEET subject
  /// Returns: {'Physics': 120, 'Chemistry': 90, 'Biology': 180}
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

  /// Get MCQ accuracy percentage by NEET subject
  /// Returns: {'Physics': 85.5, 'Chemistry': 72.3, 'Biology': 91.0}
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

  /// Get total MCQs attempted and correct across all sessions
  /// Returns: {'attempted': 1250, 'correct': 980}
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

  /// Get mock test score history (sorted by date desc)
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

  /// Get best (highest) mock test score
  Future<int> getBestMockTestScore() async {
    final db = await database;
    final result = await db.rawQuery("""
      SELECT MAX(mockTestScore) as best
      FROM study_sessions
      WHERE mockTestScore IS NOT NULL
    """);
    return (result.first['best'] as int?) ?? 0;
  }

  // ============================================
  // SUBTASK CRUD (PRESERVED)
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
  // FLASHCARD CRUD (PRESERVED)
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
  // FLASHCARD REVIEW HISTORY CRUD (PRESERVED)
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
  // DAILY CARD GOAL CRUD (PRESERVED)
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
  // STUDY SCHEDULE CRUD (PRESERVED)
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
  // DAILY GOAL CRUD (PRESERVED)
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
  // STUDY SUBJECT CRUD (PRESERVED)
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
  // GRADE COMPONENT CRUD (PRESERVED — LEGACY)
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
  // GPA COURSES CRUD (NEW v16 — Proper GPA Schema)
  // ============================================
  Future<int> insertGpaCourse(Map<String, dynamic> course) async {
    final db = await database;
    final grade = course['grade'] as String;
    final data = {
      'name': course['name'],
      'credits': course['credits'] ?? 3,
      'grade': grade,
      'gradePoints': course['gradePoints'] ?? _gradeToPoints(grade),
      'semester': course['semester'] ?? 'Current',
      'subjectCategory': course['subjectCategory'],
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('gpa_courses', data);
  }

  Future<int> updateGpaCourse(int id, Map<String, dynamic> course) async {
    final db = await database;
    final grade = course['grade'] as String?;
    final data = <String, dynamic>{
      'name': course['name'],
      'credits': course['credits'] ?? 3,
      if (grade != null) 'grade': grade,
      if (grade != null) 'gradePoints': course['gradePoints'] ?? _gradeToPoints(grade),
      'semester': course['semester'] ?? 'Current',
      'subjectCategory': course['subjectCategory'],
    };
    return db.update('gpa_courses', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGpaCourse(int id) async {
    final db = await database;
    return db.delete('gpa_courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllGpaCourses() async {
    final db = await database;
    final rows = await db.query('gpa_courses', orderBy: 'createdAtMillis DESC');
    return rows;
  }

  Future<List<Map<String, dynamic>>> getGpaCoursesBySemester(String semester) async {
    final db = await database;
    final rows = await db.query(
      'gpa_courses',
      where: 'semester = ?',
      whereArgs: [semester],
      orderBy: 'createdAtMillis DESC',
    );
    return rows;
  }

  Future<void> clearGpaCourses() async {
    final db = await database;
    await db.delete('gpa_courses');
  }

  static double _gradeToPoints(String grade) {
    switch (grade) {
      case 'A+': return 4.0;
      case 'A': return 4.0;
      case 'A-': return 3.7;
      case 'B+': return 3.3;
      case 'B': return 3.0;
      case 'B-': return 2.7;
      case 'C+': return 2.3;
      case 'C': return 2.0;
      case 'C-': return 1.7;
      case 'D+': return 1.3;
      case 'D': return 1.0;
      case 'F': return 0.0;
      default: return 0.0;
    }
  }

  // ============================================
  // QUICK NOTES CRUD (PRESERVED)
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
  // ATTENDANCE LOGS CRUD (PRESERVED)
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
  // ATTENDANCE SUBJECTS CRUD (PRESERVED)
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
  // ATTENDANCE SCHEDULES CRUD (PRESERVED)
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
  // TIMETABLE CLASSES CRUD (PRESERVED)
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
  // TIMETABLE TASKS CRUD (PRESERVED)
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

  /// Convenience overload: accepts DateTime instead of millis
  Future<List<Map<String, dynamic>>> getTimetableTasksForDateTime(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    return getTimetableTasksForDate(startOfDay);
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
  // ACADEMIC CALENDAR CRUD (PRESERVED)
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
  // CLASS SCHEDULE CRUD (PRESERVED + FIX)
  // ============================================
  Future<int> insertClassSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    final data = {
      'subjectName': schedule['subjectName'],
      'dayOfWeek': schedule['dayOfWeek'],
      'startTimeMinutes': schedule['startTimeMinutes'],
      'endTimeMinutes': schedule['endTimeMinutes'],
      'room': schedule['room'],
      'colorHex': schedule['colorHex'] ?? '#2196F3',
      'isActive': schedule['isActive'] ?? 1,
    };
    return db.insert('class_schedule', data);
  }

  Future<int> updateClassSchedule(int id, Map<String, dynamic> schedule) async {
    final db = await database;
    final data = {
      'subjectName': schedule['subjectName'],
      'dayOfWeek': schedule['dayOfWeek'],
      'startTimeMinutes': schedule['startTimeMinutes'],
      'endTimeMinutes': schedule['endTimeMinutes'],
      'room': schedule['room'],
      'colorHex': schedule['colorHex'] ?? '#2196F3',
      'isActive': schedule['isActive'] ?? 1,
    };
    return db.update('class_schedule', data, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════
  // FIXED: deleteClassSchedule — was copy-pasted from getAllClassSchedules()
  // Returns int (rows deleted) instead of List<Map>
  // ═══════════════════════════════════════════════════════════════
  Future<int> deleteClassSchedule(int id) async {
    final db = await database;
    return db.delete('class_schedule', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════
  // FIXED: Added missing getAllClassSchedules() method
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getAllClassSchedules() async {
    final db = await database;
    final rows = await db.query('class_schedule', orderBy: 'dayOfWeek ASC, startTimeMinutes ASC');
    return rows;
  }

  Future<Map<String, dynamic>?> getClassScheduleById(int id) async {
    final db = await database;
    final rows = await db.query('class_schedule', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getClassSchedulesForDay(int dayOfWeek) async {
    final db = await database;
    final rows = await db.query(
      'class_schedule',
      where: 'dayOfWeek = ? AND isActive = 1',
      whereArgs: [dayOfWeek],
      orderBy: 'startTimeMinutes ASC',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getActiveClassSchedules() async {
    final db = await database;
    final rows = await db.query(
      'class_schedule',
      where: 'isActive = 1',
      orderBy: 'dayOfWeek ASC, startTimeMinutes ASC',
    );
    return rows;
  }

  Future<void> toggleClassScheduleActive(int id, bool isActive) async {
    final db = await database;
    await db.update(
      'class_schedule',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // HABITS CRUD (PRESERVED)
  // ============================================
  Future<int> insertHabit(Map<String, dynamic> habit) async {
    final db = await database;
    final data = {
      'name': habit['name'],
      'subjectName': habit['subjectName'],
      'colorHex': habit['colorHex'] ?? '#4CAF50',
      'targetPerWeek': habit['targetPerWeek'] ?? 7,
      'reminderTimeMinutes': habit['reminderTimeMinutes'],
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      'isArchived': habit['isArchived'] ?? 0,
      'habitType': habit['habitType'] ?? 0,
      'metricGoal': habit['metricGoal'],
      'unitLabel': habit['unitLabel'],
    };
    return db.insert('habits', data);
  }

  Future<int> updateHabit(int id, Map<String, dynamic> habit) async {
    final db = await database;
    final data = {
      'name': habit['name'],
      'subjectName': habit['subjectName'],
      'colorHex': habit['colorHex'] ?? '#4CAF50',
      'targetPerWeek': habit['targetPerWeek'] ?? 7,
      'reminderTimeMinutes': habit['reminderTimeMinutes'],
      'isArchived': habit['isArchived'] ?? 0,
      'habitType': habit['habitType'] ?? 0,
      'metricGoal': habit['metricGoal'],
      'unitLabel': habit['unitLabel'],
    };
    return db.update('habits', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    await db.delete('habit_logs', where: 'habitId = ?', whereArgs: [id]);
    return db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllHabits({bool includeArchived = false}) async {
    final db = await database;
    if (includeArchived) {
      final rows = await db.query('habits', orderBy: 'createdAtMillis DESC');
      return rows;
    }
    final rows = await db.query(
      'habits',
      where: 'isArchived = 0',
      orderBy: 'createdAtMillis DESC',
    );
    return rows;
  }

  Future<Map<String, dynamic>?> getHabitById(int id) async {
    final db = await database;
    final rows = await db.query('habits', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getHabitsBySubject(String subjectName) async {
    final db = await database;
    final rows = await db.query(
      'habits',
      where: 'subjectName = ? AND isArchived = 0',
      whereArgs: [subjectName],
      orderBy: 'createdAtMillis DESC',
    );
    return rows;
  }

  Future<void> archiveHabit(int id, bool archive) async {
    final db = await database;
    await db.update(
      'habits',
      {'isArchived': archive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // HABIT LOGS CRUD (PRESERVED)
  // ============================================
  Future<int> insertHabitLog(Map<String, dynamic> log) async {
    final db = await database;
    final data = {
      'habitId': log['habitId'],
      'dateMillis': log['dateMillis'],
      'completed': log['completed'] ?? 1,
      'note': log['note'],
      'metricValue': log['metricValue'],
    };
    return db.insert('habit_logs', data);
  }

  Future<int> updateHabitLog(int id, Map<String, dynamic> log) async {
    final db = await database;
    final data = {
      'habitId': log['habitId'],
      'dateMillis': log['dateMillis'],
      'completed': log['completed'] ?? 1,
      'note': log['note'],
      'metricValue': log['metricValue'],
    };
    return db.update('habit_logs', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHabitLog(int id) async {
    final db = await database;
    return db.delete('habit_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getHabitLogsForHabit(int habitId) async {
    final db = await database;
    final rows = await db.query(
      'habit_logs',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'dateMillis DESC',
    );
    return rows;
  }

  Future<Map<String, dynamic>?> getHabitLogForDate(int habitId, int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final rows = await db.query(
      'habit_logs',
      where: 'habitId = ? AND dateMillis >= ? AND dateMillis < ?',
      whereArgs: [habitId, dateMillis, endOfDay],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getHabitLogsForDateRange(int habitId, int startMillis, int endMillis) async {
    final db = await database;
    final rows = await db.query(
      'habit_logs',
      where: 'habitId = ? AND dateMillis >= ? AND dateMillis < ?',
      whereArgs: [habitId, startMillis, endMillis],
      orderBy: 'dateMillis ASC',
    );
    return rows;
  }

  /// Convenience overload: accepts DateTime instead of millis
  Future<List<Map<String, dynamic>>> getHabitLogsForDateTimeRange(int habitId, DateTime start, DateTime end) async {
    final startMillis = DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
    final endMillis = DateTime(end.year, end.month, end.day).millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds;
    return getHabitLogsForDateRange(habitId, startMillis, endMillis);
  }

  Future<int> getHabitCompletionCountForWeek(int habitId, int weekStartMillis) async {
    final db = await database;
    final weekEndMillis = weekStartMillis + const Duration(days: 7).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count FROM habit_logs
      WHERE habitId = ? AND dateMillis >= ? AND dateMillis < ? AND completed = 1
    """, [habitId, weekStartMillis, weekEndMillis]);
    return (result.first['count'] as int?) ?? 0;
  }

  /// Convenience overload: accepts DateTime instead of millis
  Future<int> getHabitCompletionCountForWeekDateTime(int habitId, DateTime weekStart) async {
    final weekStartMillis = DateTime(weekStart.year, weekStart.month, weekStart.day).millisecondsSinceEpoch;
    return getHabitCompletionCountForWeek(habitId, weekStartMillis);
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

  // ============================================
  // READING BOOKS CRUD (PRESERVED + ENHANCED)
  // ============================================
  Future<int> insertReadingBook(Map<String, dynamic> book) async {
    final db = await database;
    final data = {
      'title': book['title'],
      'author': book['author'],
      'totalPages': book['totalPages'],
      'currentPage': book['currentPage'] ?? 0,
      'subjectName': book['subjectName'],
      'colorHex': book['colorHex'] ?? '#2196F3',
      'startDateMillis': book['startDateMillis'],
      'targetEndDateMillis': book['targetEndDateMillis'],
      'dailyPageGoal': book['dailyPageGoal'] ?? 20,
      'minutesReadToday': book['minutesReadToday'] ?? 0,
      'totalMinutesRead': book['totalMinutesRead'] ?? 0,
      'isCompleted': book['isCompleted'] ?? 0,
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('reading_books', data);
  }

  Future<int> updateReadingBook(int id, Map<String, dynamic> book) async {
    final db = await database;
    final data = {
      'title': book['title'],
      'author': book['author'],
      'totalPages': book['totalPages'],
      'currentPage': book['currentPage'] ?? 0,
      'subjectName': book['subjectName'],
      'colorHex': book['colorHex'] ?? '#2196F3',
      'startDateMillis': book['startDateMillis'],
      'targetEndDateMillis': book['targetEndDateMillis'],
      'dailyPageGoal': book['dailyPageGoal'] ?? 20,
      'minutesReadToday': book['minutesReadToday'] ?? 0,
      'totalMinutesRead': book['totalMinutesRead'] ?? 0,
      'isCompleted': book['isCompleted'] ?? 0,
    };
    return db.update('reading_books', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteReadingBook(int id) async {
    final db = await database;
    await db.delete('reading_sessions', where: 'bookId = ?', whereArgs: [id]);
    return db.delete('reading_books', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllReadingBooks({bool includeCompleted = true}) async {
    final db = await database;
    if (includeCompleted) {
      final rows = await db.query('reading_books', orderBy: 'createdAtMillis DESC');
      return rows;
    }
    final rows = await db.query(
      'reading_books',
      where: 'isCompleted = 0',
      orderBy: 'createdAtMillis DESC',
    );
    return rows;
  }

  Future<Map<String, dynamic>?> getReadingBookById(int id) async {
    final db = await database;
    final rows = await db.query('reading_books', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getReadingBooksBySubject(String subjectName) async {
    final db = await database;
    final rows = await db.query(
      'reading_books',
      where: 'subjectName = ?',
      whereArgs: [subjectName],
      orderBy: 'createdAtMillis DESC',
    );
    return rows;
  }

  Future<void> updateReadingProgress(int id, int currentPage, int minutesRead) async {
    final db = await database;
    final book = await getReadingBookById(id);
    if (book == null) return;

    final oldPage = (book['currentPage'] as int?) ?? 0;
    final totalPages = (book['totalPages'] as int?) ?? 1;
    final pagesRead = currentPage - oldPage;
    final isCompleted = currentPage >= totalPages;

    await db.update(
      'reading_books',
      {
        'currentPage': currentPage,
        'minutesReadToday': ((book['minutesReadToday'] as int?) ?? 0) + minutesRead,
        'totalMinutesRead': ((book['totalMinutesRead'] as int?) ?? 0) + minutesRead,
        'isCompleted': isCompleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (pagesRead > 0 && minutesRead > 0) {
      final pagesPerMin = pagesRead / minutesRead;
      await db.insert('reading_sessions', {
        'bookId': id,
        'startPage': oldPage,
        'endPage': currentPage,
        'pagesRead': pagesRead,
        'minutesRead': minutesRead,
        'pagesPerMinute': pagesPerMin,
        'sessionDateMillis': DateTime.now().millisecondsSinceEpoch,
        'note': null,
        'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> resetDailyReadingStats() async {
    final db = await database;
    await db.update(
      'reading_books',
      {'minutesReadToday': 0},
    );
  }

  Future<Map<String, dynamic>> getReadingProgress(int bookId) async {
    final db = await database;
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

  // ============================================
  // READING SESSIONS CRUD (v14)
  // ============================================
  Future<int> insertReadingSession(Map<String, dynamic> session) async {
    final db = await database;
    final data = {
      'bookId': session['bookId'],
      'startPage': session['startPage'],
      'endPage': session['endPage'],
      'pagesRead': session['pagesRead'],
      'minutesRead': session['minutesRead'],
      'pagesPerMinute': session['pagesPerMinute'],
      'sessionDateMillis': session['sessionDateMillis'],
      'note': session['note'],
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.insert('reading_sessions', data);
  }

  Future<int> updateReadingSession(int id, Map<String, dynamic> session) async {
    final db = await database;
    final data = {
      'bookId': session['bookId'],
      'startPage': session['startPage'],
      'endPage': session['endPage'],
      'pagesRead': session['pagesRead'],
      'minutesRead': session['minutesRead'],
      'pagesPerMinute': session['pagesPerMinute'],
      'sessionDateMillis': session['sessionDateMillis'],
      'note': session['note'],
    };
    return db.update('reading_sessions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteReadingSession(int id) async {
    final db = await database;
    return db.delete('reading_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getReadingSessionsForBook(int bookId, {int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'reading_sessions',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'sessionDateMillis DESC',
      limit: limit,
    );
    return rows;
  }

  Future<Map<String, dynamic>?> getReadingSessionById(int id) async {
    final db = await database;
    final rows = await db.query('reading_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ============================================
  // READING STATS METHODS (v14)
  // ============================================
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

  // ============================================
  // STATS METHODS (8 methods for stats_screen.dart)
  // ============================================
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

  // ============================================
  // EXPORT/IMPORT (PRESERVED + v16)
  // ============================================
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
      'gpa_courses', // NEW v16
      'quick_notes',
      'attendance_logs',
      'attendance_subjects',
      'attendance_schedules',
      'timetable_classes',
      'timetable_tasks',
      'academic_calendar',
      'class_schedule',
      'habits',
      'habit_logs',
      'reading_books',
      'reading_sessions',
    ];

    for (final table in tables) {
      try {
        final rows = await db.query(table);
        result[table] = rows;
      } catch (e) {
        result[table] = [];
      }
    }

    return result;
  }

  Future<void> importAllTables(Map<String, List<Map<String, dynamic>>> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in data.entries) {
        final table = entry.key;
        final rows = entry.value;

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
  // UTILITY (PRESERVED)
  // ============================================
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
}
// --- END OF FILE ---
