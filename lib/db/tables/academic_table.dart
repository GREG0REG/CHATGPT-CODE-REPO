// FILE: lib/db/tables/academic_table.dart
// GROUP D — grade_components, gpa_courses, quick_notes, attendance_logs,
// attendance_subjects, attendance_schedules, timetable_classes, timetable_tasks,
// academic_calendar, class_schedule, habits, habit_logs, reading_books, reading_sessions

import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

mixin AcademicTable on DatabaseHelper {
  // ============================================================
  // GRADE COMPONENT CRUD (legacy)
  // ============================================================
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

  // ============================================================
  // GPA COURSES CRUD
  // ============================================================
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

  // ============================================================
  // QUICK NOTES CRUD (v18 — Enhanced)
  // ============================================================
  Future<int> insertQuickNote(Map<String, dynamic> note) async {
    final db = await database;
    final data = {
      'title': note['title'],
      'content': note['content'],
      'subject': note['subject'] ?? 'General',
      'tagsJson': note['tagsJson'] ?? '[]',
      'isPinned': note['isPinned'] ?? 0,
      'isArchived': note['isArchived'] ?? 0,
      'noteColor': note['noteColor'] ?? '#2D2D2D',
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
      'tagsJson': note['tagsJson'] ?? '[]',
      'isPinned': note['isPinned'] ?? 0,
      'isArchived': note['isArchived'] ?? 0,
      'noteColor': note['noteColor'] ?? '#2D2D2D',
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    return db.update('quick_notes', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteQuickNote(int id) async {
    final db = await database;
    return db.delete('quick_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archiveQuickNote(int id, bool archive) async {
    final db = await database;
    return db.update(
      'quick_notes',
      {'isArchived': archive ? 1 : 0, 'updatedAtMillis': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pinQuickNote(int id, bool pin) async {
    final db = await database;
    return db.update(
      'quick_notes',
      {'isPinned': pin ? 1 : 0, 'updatedAtMillis': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllQuickNotes({
    String? subjectFilter,
    String? searchQuery,
    bool includeArchived = false,
    String sortBy = 'newest',
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (!includeArchived) {
      whereClause = 'isArchived = 0';
    }

    if (subjectFilter != null && subjectFilter != 'All') {
      whereClause = whereClause.isEmpty ? 'subject = ?' : '$whereClause AND subject = ?';
      whereArgs.add(subjectFilter);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      whereClause = whereClause.isEmpty
          ? '(title LIKE ? OR content LIKE ? OR tagsJson LIKE ?)'
          : '$whereClause AND (title LIKE ? OR content LIKE ? OR tagsJson LIKE ?)';
      whereArgs.addAll([query, query, query]);
    }

    String orderBy;
    switch (sortBy) {
      case 'oldest':
        orderBy = 'createdAtMillis ASC';
        break;
      case 'az':
        orderBy = 'title ASC';
        break;
      case 'za':
        orderBy = 'title DESC';
        break;
      case 'subject':
        orderBy = 'subject ASC, createdAtMillis DESC';
        break;
      default: // newest
        orderBy = 'createdAtMillis DESC';
    }

    final rows = await db.query(
      'quick_notes',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'isPinned DESC, $orderBy',
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getArchivedQuickNotes() async {
    final db = await database;
    return db.query(
      'quick_notes',
      where: 'isArchived = 1',
      orderBy: 'updatedAtMillis DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPinnedQuickNotes() async {
    final db = await database;
    return db.query(
      'quick_notes',
      where: 'isPinned = 1 AND isArchived = 0',
      orderBy: 'updatedAtMillis DESC',
    );
  }

  Future<Map<String, dynamic>?> getQuickNote(int id) async {
    final db = await database;
    final rows = await db.query('quick_notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<String>> getQuickNoteSubjects() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT DISTINCT subject FROM quick_notes ORDER BY subject ASC
    """);
    return rows.map((r) => r['subject'] as String).toList();
  }

  Future<Map<String, dynamic>> getQuickNoteStats() async {
    final db = await database;
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM quick_notes WHERE isArchived = 0');
    final pinnedResult = await db.rawQuery('SELECT COUNT(*) as count FROM quick_notes WHERE isPinned = 1 AND isArchived = 0');
    final archivedResult = await db.rawQuery('SELECT COUNT(*) as count FROM quick_notes WHERE isArchived = 1');

    return {
      'total': (totalResult.first['count'] as int?) ?? 0,
      'pinned': (pinnedResult.first['count'] as int?) ?? 0,
      'archived': (archivedResult.first['count'] as int?) ?? 0,
    };
  }

  // ============================================================
  // ATTENDANCE LOGS CRUD
  // ============================================================
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

  // ============================================================
  // ATTENDANCE SUBJECTS CRUD
  // ============================================================
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

  // ============================================================
  // ATTENDANCE SCHEDULES CRUD
  // ============================================================
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

  // ============================================================
  // TIMETABLE CLASSES CRUD
  // ============================================================
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

  // ============================================================
  // TIMETABLE TASKS CRUD
  // ============================================================
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

  // ============================================================
  // ACADEMIC CALENDAR CRUD
  // ============================================================
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

  // ============================================================
  // CLASS SCHEDULE CRUD
  // ============================================================
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

  Future<int> deleteClassSchedule(int id) async {
    final db = await database;
    return db.delete('class_schedule', where: 'id = ?', whereArgs: [id]);
  }

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

  // ============================================================
  // HABITS CRUD
  // ============================================================
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

  // ============================================================
  // HABIT LOGS CRUD
  // ============================================================
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

  Future<int> getHabitCompletionCountForWeek(int habitId, int weekStartMillis) async {
    final db = await database;
    final weekEndMillis = weekStartMillis + const Duration(days: 7).inMilliseconds;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count FROM habit_logs
      WHERE habitId = ? AND dateMillis >= ? AND dateMillis < ? AND completed = 1
    """, [habitId, weekStartMillis, weekEndMillis]);
    return (result.first['count'] as int?) ?? 0;
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

  // ============================================================
  // READING BOOKS CRUD
  // ============================================================
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

  // ============================================================
  // READING SESSIONS CRUD
  // ============================================================
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
}
