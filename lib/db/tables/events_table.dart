// FILE: lib/db/tables/events_table.dart
// GROUP A — events, custom_reminders, notification_history

import 'package:sqflite/sqflite.dart';
import 'package:event_countdown/models/event.dart';
import 'package:event_countdown/models/custom_reminder.dart';
import 'package:event_countdown/models/notification_history.dart';
import '../../database_helper.dart';   // ✅ CORRECT - goes up TWO levels to lib/


mixin EventsTable on DatabaseHelper {
  // ============================================================
  // EVENT CRUD
  // ============================================================
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

  // ============================================================
  // CUSTOM REMINDER CRUD
  // ============================================================
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

  // ============================================================
  // NOTIFICATION HISTORY CRUD
  // ============================================================
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
}
