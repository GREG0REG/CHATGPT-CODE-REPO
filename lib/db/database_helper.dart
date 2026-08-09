// FILE: lib/db/database_helper.dart
// REFACTORED v21 — Core singleton, database init, all table creation,
// all migrations, export/import, vacuum, and home screen helpers.
// All CRUD delegated to mixins in tables/ and analytics/ folders.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:event_countdown/models/event.dart';
import 'package:event_countdown/models/custom_reminder.dart';
import 'package:event_countdown/models/notification_history.dart';
import 'package:event_countdown/models/study_session.dart';
import 'package:event_countdown/models/subtask.dart';
import 'package:event_countdown/models/flashcard.dart';
import 'package:event_countdown/models/study_schedule.dart';
import 'package:event_countdown/models/daily_goal.dart';
import 'package:event_countdown/models/study_subject.dart';
import 'package:event_countdown/models/flashcard_review_history.dart';
import 'package:event_countdown/models/daily_card_goal.dart';
import 'package:event_countdown/models/syllabus_subject.dart';
import 'package:event_countdown/models/syllabus_unit.dart';
import 'package:event_countdown/models/syllabus_topic.dart';
import 'package:event_countdown/models/syllabus_subtopic.dart';
import 'package:event_countdown/models/syllabus_resource.dart';
import 'package:event_countdown/models/syllabus_study_link.dart';
import 'package:event_countdown/models/syllabus_revision_schedule.dart';
import 'package:event_countdown/models/study_plan.dart';
import 'package:event_countdown/models/study_plan_item.dart';

import 'tables/events_table.dart';
import 'tables/study_table.dart';
import 'tables/flashcard_table.dart';
import 'tables/academic_table.dart';
import 'tables/syllabus_table.dart';
import 'analytics/neet_analytics.dart';
import 'analytics/study_analytics.dart';
import 'analytics/syllabus_analytics.dart';
import 'analytics/reading_analytics.dart';
import 'analytics/attendance_analytics.dart';
import 'analytics/habit_analytics.dart';

class DatabaseHelper
    with
        EventsTable,
        StudyTable,
        FlashcardTable,
        AcademicTable,
        SyllabusTable,
        NeetAnalytics,
        StudyAnalytics,
        SyllabusAnalytics,
        ReadingAnalytics,
        AttendanceAnalytics,
        HabitAnalytics {
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
      version: 21,
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
        if (oldVersion < 16) await _migrateV15ToV16(db);
        if (oldVersion < 17) await _migrateV16ToV17(db);
        if (oldVersion < 18) await _migrateV17ToV18(db);
        if (oldVersion < 19) await _migrateV18ToV19(db);
        if (oldVersion < 20) await _migrateV19ToV20(db);
        if (oldVersion < 21) await _migrateV20ToV21(db);
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
    // ---- EVENTS ----
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
        mockTestRank INTEGER,
        productivity INTEGER DEFAULT 7
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

    await db.execute("""
      CREATE TABLE study_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        colorHex TEXT DEFAULT '#2196F3',
        totalFocusMinutes INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);

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

    await db.execute("""
      CREATE TABLE quick_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        subject TEXT NOT NULL DEFAULT 'General',
        tagsJson TEXT DEFAULT '[]',
        isPinned INTEGER DEFAULT 0,
        isArchived INTEGER DEFAULT 0,
        noteColor TEXT DEFAULT '#2D2D2D',
        createdAtMillis INTEGER NOT NULL,
        updatedAtMillis INTEGER
      )
    """);

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
        isArchived INTEGER DEFAULT 0,
        habitType INTEGER DEFAULT 0,
        metricGoal INTEGER,
        unitLabel TEXT
      )
    """);

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

    // ---- SYLLABUS TABLES (v17+) ----
    await db.execute("""
      CREATE TABLE syllabus_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        colorHex TEXT DEFAULT '#2196F3',
        targetCompletionDateMillis INTEGER,
        totalMarksWeightage INTEGER,
        examCategory TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE syllabus_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        weightage INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE syllabus_topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unitId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        status TEXT DEFAULT 'notStarted',
        difficulty TEXT,
        estimatedMinutes INTEGER,
        neetMarksWeightage INTEGER,
        targetCompletionDateMillis INTEGER,
        mcqsAttempted INTEGER DEFAULT 0,
        mcqsCorrect INTEGER DEFAULT 0,
        lastMockScore INTEGER,
        bestMockScore INTEGER,
        totalStudyMinutes INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE syllabus_subtopics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        status TEXT DEFAULT 'notStarted',
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
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
    """);

    await db.execute("""
      CREATE TABLE syllabus_study_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        studySessionId INTEGER NOT NULL,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
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
    """);

    await db.execute("""
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
    """);

    await db.execute("""
      CREATE TABLE study_plan_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        planId INTEGER NOT NULL,
        topicId INTEGER,
        scheduledDateMillis INTEGER NOT NULL,
        allocatedMinutes INTEGER DEFAULT 60,
        isCompleted INTEGER DEFAULT 0,
        notes TEXT,
        orderIndex INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE mock_test_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER,
        testName TEXT NOT NULL,
        score INTEGER NOT NULL,
        totalMarks INTEGER NOT NULL,
        rank INTEGER,
        totalStudents INTEGER,
        topicsTested TEXT,
        dateMillis INTEGER NOT NULL,
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE chapter_deadlines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL UNIQUE,
        targetDateMillis INTEGER NOT NULL,
        priority INTEGER DEFAULT 2,
        reminderDays INTEGER DEFAULT 3,
        isCompleted INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  // === Migrations (preserved exactly) ===
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

  Future<void> _migrateV15ToV16(Database db) async {
    await _addColumnIfNotExists(db, 'events', 'targetScore', 'INTEGER');
    await _addColumnIfNotExists(db, 'events', 'neetExamType', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'revisionRound', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'isPyqSession', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'events', 'difficulty', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'studyDuration', 'TEXT');
    await _addColumnIfNotExists(db, 'events', 'studyModeTagsJson', 'TEXT');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN neetSubject INTEGER');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mcqsAttempted INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mcqsCorrect INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN difficultyLevel INTEGER DEFAULT 1');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN revisionRound INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mockTestScore INTEGER');
    await db.execute('ALTER TABLE study_sessions ADD COLUMN mockTestRank INTEGER');
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

    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        colorHex TEXT DEFAULT '#2196F3',
        targetCompletionDateMillis INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        weightage INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unitId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        status TEXT DEFAULT 'notStarted',
        difficulty TEXT,
        estimatedMinutes INTEGER,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_subtopics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        status TEXT DEFAULT 'notStarted',
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_resources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER,
        subtopicId INTEGER,
        resourceType TEXT NOT NULL,
        title TEXT NOT NULL,
        filePath TEXT,
        url TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_study_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        studySessionId INTEGER NOT NULL,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS syllabus_revision_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL,
        revisionNumber INTEGER NOT NULL,
        scheduledDateMillis INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS study_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        eventId INTEGER,
        subjectId INTEGER,
        startDateMillis INTEGER NOT NULL,
        endDateMillis INTEGER NOT NULL,
        dailyStudyMinutes INTEGER DEFAULT 120,
        isActive INTEGER DEFAULT 1,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS study_plan_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        planId INTEGER NOT NULL,
        topicId INTEGER,
        scheduledDateMillis INTEGER NOT NULL,
        allocatedMinutes INTEGER DEFAULT 60,
        isCompleted INTEGER DEFAULT 0,
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  Future<void> _migrateV17ToV18(Database db) async {
    await _addColumnIfNotExists(db, 'quick_notes', 'tagsJson', "TEXT DEFAULT '[]'");
    await _addColumnIfNotExists(db, 'quick_notes', 'isPinned', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'quick_notes', 'isArchived', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'quick_notes', 'noteColor', "TEXT DEFAULT '#2D2D2D'");
  }

  Future<void> _migrateV18ToV19(Database db) async {
    await _addColumnIfNotExists(db, 'study_plans', 'priority', 'INTEGER DEFAULT 2');
    await _addColumnIfNotExists(db, 'study_plans', 'strategy', "TEXT DEFAULT 'balanced'");
    await _addColumnIfNotExists(db, 'study_plans', 'bufferDays', 'INTEGER DEFAULT 7');
    await _addColumnIfNotExists(db, 'study_plan_items', 'orderIndex', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'neetMarksWeightage', 'INTEGER');
  }

  Future<void> _migrateV19ToV20(Database db) async {
    await _addColumnIfNotExists(db, 'syllabus_topics', 'notes', 'TEXT');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'targetCompletionDateMillis', 'INTEGER');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'mcqsAttempted', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'mcqsCorrect', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'lastMockScore', 'INTEGER');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'bestMockScore', 'INTEGER');
    await _addColumnIfNotExists(db, 'syllabus_topics', 'totalStudyMinutes', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'syllabus_subjects', 'examCategory', 'TEXT');
    await _addColumnIfNotExists(db, 'syllabus_subjects', 'totalMarksWeightage', 'INTEGER');
    await _addColumnIfNotExists(db, 'syllabus_revision_schedules', 'performanceScore', 'INTEGER');
    await _addColumnIfNotExists(db, 'syllabus_revision_schedules', 'actualRevisionDateMillis', 'INTEGER');
    await _addColumnIfNotExists(db, 'syllabus_revision_schedules', 'notes', 'TEXT');
    await db.execute("""
      CREATE TABLE IF NOT EXISTS mock_test_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER,
        testName TEXT NOT NULL,
        score INTEGER NOT NULL,
        totalMarks INTEGER NOT NULL,
        rank INTEGER,
        totalStudents INTEGER,
        topicsTested TEXT,
        dateMillis INTEGER NOT NULL,
        notes TEXT,
        createdAtMillis INTEGER NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS chapter_deadlines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topicId INTEGER NOT NULL UNIQUE,
        targetDateMillis INTEGER NOT NULL,
        priority INTEGER DEFAULT 2,
        reminderDays INTEGER DEFAULT 3,
        isCompleted INTEGER DEFAULT 0,
        createdAtMillis INTEGER NOT NULL
      )
    """);
  }

  Future<void> _migrateV20ToV21(Database db) async {
    await _addColumnIfNotExists(db, 'study_sessions', 'productivity', 'INTEGER DEFAULT 7');
  }

  // ============================================================
  // EXPORT / IMPORT
  // ============================================================
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
      'gpa_courses',
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
      'syllabus_subjects',
      'syllabus_units',
      'syllabus_topics',
      'syllabus_subtopics',
      'syllabus_resources',
      'syllabus_study_links',
      'syllabus_revision_schedules',
      'study_plans',
      'study_plan_items',
      'mock_test_history',
      'chapter_deadlines',
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

  // ============================================================
  // UTILITY
  // ============================================================
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  // ============================================================
  // HOME SCREEN HELPERS
  // ============================================================
  Future<bool> hasStudySessionsOnDate(int dateMillis) async {
    final db = await database;
    final endOfDay = dateMillis + const Duration(days: 1).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count FROM study_sessions
      WHERE completedAtMillis >= ? AND completedAtMillis < ?
    """, [dateMillis, endOfDay]);
    return ((result.first['count'] as int?) ?? 0) > 0;
  }

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
}
