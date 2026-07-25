import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../database_helper.dart';
import '../models/event.dart';
import 'settings_service.dart';

class WidgetService {
  WidgetService._internal();
  static final WidgetService instance = WidgetService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.event_countdown/widget');

  // ==================== EXISTING: Event Widget ====================
  static Future<void> refreshWidget() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

      Event? nextEvent;
      for (final e in events) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(e.dateMillis);
        if (eventDate.isAfter(now) || _isSameDay(eventDate, now)) {
          nextEvent = e;
          break;
        }
      }

      if (nextEvent == null && events.isNotEmpty) {
        nextEvent = events.first;
      }

      final data = <String, dynamic>{};
      if (nextEvent != null) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(nextEvent.dateMillis);
        final diff = eventDate.difference(now);
        final smart = await SettingsService.instance.getSmartFormatEnabled();

        String countdownText;
        if (smart) {
          if (diff.inDays > 0) {
            countdownText = '${diff.inDays}d ${diff.inHours % 24}h left';
          } else if (diff.inHours > 0) {
            countdownText = '${diff.inHours}h ${diff.inMinutes % 60}m left';
          } else if (diff.inMinutes > 0) {
            countdownText = '${diff.inMinutes}m left';
          } else {
            countdownText = 'Now!';
          }
        } else {
          countdownText = _formatDate(eventDate);
        }

        int progress = 0;
        if (nextEvent.startTimeMillis != null && nextEvent.deadlineMillis != null) {
          final start = DateTime.fromMillisecondsSinceEpoch(nextEvent.startTimeMillis!);
          final end = DateTime.fromMillisecondsSinceEpoch(nextEvent.deadlineMillis!);
          final total = end.difference(start).inMinutes;
          final elapsed = now.difference(start).inMinutes;
          if (total > 0) {
            progress = ((elapsed / total) * 100).clamp(0, 100).toInt();
          }
        }

        String urgencyLabel = '';
        String urgencyColor = '';
        if (diff.inDays == 0 && diff.inHours <= 24 && diff.inHours > 0) {
          urgencyLabel = 'Under 24 hours';
          urgencyColor = 'orange';
        } else if (diff.inHours <= 1 && diff.inMinutes > 0) {
          urgencyLabel = 'Starting soon';
          urgencyColor = 'red';
        } else if (diff.inMinutes <= 0) {
          urgencyLabel = 'Happening now';
          urgencyColor = 'red';
        }

        data['title'] = nextEvent.title;
        data['countdown'] = countdownText;
        data['progressPercent'] = progress;
        data['deadlineMillis'] = nextEvent.dateMillis;
        data['urgencyLabel'] = urgencyLabel;
        data['urgencyColor'] = urgencyColor;
      } else {
        data['title'] = 'No upcoming events';
        data['countdown'] = 'Open app to add events';
        data['progressPercent'] = 0;
        data['deadlineMillis'] = 0;
        data['urgencyLabel'] = '';
        data['urgencyColor'] = '';
      }

      await _writeWidgetData('widget_data.json', data);
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('Widget refresh error: $e');
    }
  }

  // ==================== EXISTING: Pomodoro Widget ====================
  static Future<void> refreshPomodoroWidget() async {
    try {
      await _channel.invokeMethod('updatePomodoroWidget');
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }

  // ==================== NEW: Attendance Widget ====================
  static Future<void> refreshAttendanceWidget() async {
    try {
      final subjects = await DatabaseHelper.instance.getAttendanceSubjects();
      String targetSubject = '';
      int attended = 0;
      int total = 0;
      int percentage = 0;

      if (subjects.isNotEmpty) {
        targetSubject = subjects.first;
        
        final lastSubject = await SettingsService.instance.getLastViewedAttendanceSubject();
        if (lastSubject != null && subjects.contains(lastSubject)) {
          targetSubject = lastSubject;
        }

        final stats = await DatabaseHelper.instance.getAttendanceStatsForSubject(targetSubject);
        attended = (stats['present'] as int?) ?? 0;
        final excused = (stats['excused'] as int?) ?? 0;
        total = (stats['total'] as int?) ?? 0;
        
        if (total > 0) {
          percentage = (((attended + excused) / total) * 100).round();
        }
      }

      final data = <String, dynamic>{
        'subjectName': targetSubject.isEmpty ? 'No Subject' : targetSubject,
        'attended': attended,
        'total': total,
        'percentage': percentage,
      };

      await _writeWidgetData('attendance_widget_data.json', data);
      await _channel.invokeMethod('updateAttendanceWidget');
    } catch (e) {
      debugPrint('Attendance widget refresh error: $e');
    }
  }

  // ==================== NEW: Timetable Widget ====================
  static Future<void> refreshTimetableWidget() async {
    try {
      final now = DateTime.now();
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayName = dayNames[now.weekday - 1];
      
      final notes = await DatabaseHelper.instance.getAllQuickNotes();
      final dayPrefix = 'TT_$todayName';
      
      final classesList = <Map<String, dynamic>>[];
      
      for (final note in notes) {
        final subject = note['subject'] as String;
        if (subject.startsWith(dayPrefix)) {
          final parts = subject.split('_');
          final subjectName = parts.length > 2 ? parts.sublist(2, parts.length > 3 ? parts.length - 1 : parts.length).join('_') : 'Unknown';
          final colorHex = parts.length > 3 ? parts.last : '#2196F3';
          
          classesList.add({
            'subject': subjectName,
            'timeSlot': note['title'],
            'colorHex': colorHex,
          });
        }
      }

      classesList.sort((a, b) => (a['timeSlot'] as String).compareTo(b['timeSlot'] as String));

      final data = <String, dynamic>{
        'dayName': todayName,
        'dateText': '${_monthName(now.month)} ${now.day}',
        'classes': classesList,
      };

      await _writeWidgetData('timetable_widget_data.json', data);
      await _channel.invokeMethod('updateTimetableWidget');
    } catch (e) {
      debugPrint('Timetable widget refresh error: $e');
    }
  }

  // ==================== HELPER METHODS ====================
  static Future<void> _writeWidgetData(String filename, Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Widget data write error: $e');
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }
}
