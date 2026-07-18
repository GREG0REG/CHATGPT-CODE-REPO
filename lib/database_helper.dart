import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'models/event.dart';
import 'models/custom_reminder.dart';
import 'models/notification_history.dart';

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
      version: 4,
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
      },
    );
  }

  Future<void> _createTables(Database db) async {
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
  }

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

  // NEW: Migration for Student Study Pack columns
  Future<void> _migrateV3ToV4(Database db) async {
    await db.execute('ALTER TABLE events ADD COLUMN iconName TEXT');
    await db.execute('ALTER TABLE events ADD COLUMN priority INTEGER DEFAULT 2');
    await db.execute('ALTER TABLE events ADD COLUMN subjectTag TEXT');
    await db.execute('ALTER TABLE events ADD COLUMN isCompleted INTEGER DEFAULT 0');
  }

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
      for (final e in events) {
        await txn.insert('events', e.toMap()..remove('id'));
      }
    });
  }

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

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
}
