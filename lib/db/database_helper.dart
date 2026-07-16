import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/custom_reminder.dart';
import '../models/event.dart';
import '../models/notification_history.dart';

/// Local-only SQLite storage for events. No network, no cloud sync.
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
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
      },
    );
  }

  Future<void> _createV1Tables(Database db) async {
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
  }

  // ============================================
  // SESSION 4 & 5: v2 tables
  // ============================================
  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      ALTER TABLE events ADD COLUMN recurrence TEXT DEFAULT 'none'
    ''');

    await db.execute('''
      CREATE TABLE custom_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        minutesBefore INTEGER NOT NULL,
        type TEXT NOT NULL,
        soundUri TEXT,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        eventTitle TEXT NOT NULL,
        reminderType TEXT NOT NULL,
        sentAtMillis INTEGER NOT NULL,
        wasSnoozed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute('''
      ALTER TABLE events ADD COLUMN recurrence TEXT DEFAULT 'none'
    ''');

    await db.execute('''
      CREATE TABLE custom_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        minutesBefore INTEGER NOT NULL,
        type TEXT NOT NULL,
        soundUri TEXT,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER,
        eventTitle TEXT NOT NULL,
        reminderType TEXT NOT NULL,
        sentAtMillis INTEGER NOT NULL,
        wasSnoozed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ============================================
  // Existing event methods (preserved)
  // ============================================
  Future<int> insertEvent(Event event) async {
    final db = await database;
    return db.insert('events', event.toMap()..remove('id'));
  }

  Future<int> updateEvent(Event event) async {
    final db = await database;
    return db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(int id) async {
    final db = await database;
    return db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns all events sorted by date, nearest first.
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

  /// Wipes all events and replaces them with [events]. Used for JSON import.
  Future<void> replaceAllEvents(List<Event> events) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('events');
      for (final e in events) {
        await txn.insert('events', e.toMap()..remove('id'));
      }
    });
  }

  // ============================================
  // SESSION 4: Custom Reminder CRUD
  // ============================================
  Future<int> insertCustomReminder(CustomReminder reminder) async {
    final db = await database;
    return db.insert('custom_reminders', reminder.toMap()..remove('id'));
  }

  Future<int> updateCustomReminder(CustomReminder reminder) async {
    final db = await database;
    return db.update(
      'custom_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteCustomReminder(int id) async {
    final db = await database;
    return db.delete('custom_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CustomReminder>> getCustomRemindersForEvent(int eventId) async {
    final db = await database;
    final rows = await db.query(
      'custom_reminders',
      where: 'eventId = ?',
      whereArgs: [eventId],
      orderBy: 'minutesBefore DESC',
    );
    return rows.map((r) => CustomReminder.fromMap(r)).toList();
  }

  Future<void> deleteCustomRemindersForEvent(int eventId) async {
    final db = await database;
    await db.delete('custom_reminders', where: 'eventId = ?', whereArgs: [eventId]);
  }

  // ============================================
  // SESSION 4: Notification History
  // ============================================
  Future<int> insertNotificationHistory(NotificationHistory entry) async {
    final db = await database;
    return db.insert('notification_history', entry.toMap()..remove('id'));
  }

  Future<List<NotificationHistory>> getNotificationHistory({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'notification_history',
      orderBy: 'sentAtMillis DESC',
      limit: limit,
    );
    return rows.map((r) => NotificationHistory.fromMap(r)).toList();
  }

  Future<void> clearNotificationHistory() async {
    final db = await database;
    await db.delete('notification_history');
  }

  // ============================================
  // SESSION 9: Maintenance
  // ============================================
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
}
