// FILE: lib/db/analytics/attendance_analytics.dart
// Attendance summary and statistics

import 'package:sqflite/sqflite.dart';
import '../../database_helper.dart';   // ✅ CORRECT - goes up TWO levels to lib/


mixin AttendanceAnalytics on DatabaseHelper {
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
}
