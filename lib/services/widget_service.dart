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

  // ==================== REFRESH ALL WIDGETS ====================
  static Future<void> refreshAllWidgets() async {
    await refreshWidget();
    await refreshPomodoroWidget();
    await refreshAttendanceWidget();
    await refreshTimetableWidget();
    await refreshHabitWidget();      // NEW
    await refreshReadingWidget();    // NEW
  }

  // ==================== EVENT COUNTDOWN WIDGET ====================
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

  // ==================== POMODORO WIDGET ====================
  static Future<void> refreshPomodoroWidget() async {
    try {
      await _channel.invokeMethod('updatePomodoroWidget');
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }

  // ==================== ATTENDANCE WIDGET ====================
  static Future<void> refreshAttendanceWidget() async {
    try {
      final subjects = await DatabaseHelper.instance.getAllAttendanceSubjects();
      
      if (subjects.isEmpty) {
        final data = <String, dynamic>{
          'subjectName': 'No Subjects',
          'percentage': 0,
          'attended': 0,
          'total': 0,
          'statusColor': 'grey',
          'canMissText': 'Add subjects to track attendance',
          'threshold': 75,
          'isAtRisk': false,
        };
        await _writeWidgetData('attendance_widget_data.json', data);
        await _channel.invokeMethod('updateAttendanceWidget');
        return;
      }

      // Find the most at-risk subject (lowest percentage below threshold)
      Map<String, dynamic>? mostAtRiskSubject;
      double lowestPercentage = double.infinity;
      double defaultThreshold = 75.0;

      for (final subject in subjects) {
        final subjectName = subject['name'] as String;
        final requiredPercentage = (subject['requiredPercentage'] as num?)?.toDouble() ?? defaultThreshold;
        
        final stats = await DatabaseHelper.instance.getAttendanceStatsForSubject(subjectName);
        final total = (stats['total'] as int?) ?? 0;
        final present = (stats['present'] as int?) ?? 0;
        final excused = (stats['excused'] as int?) ?? 0;
        
        if (total == 0) continue;
        
        final percentage = ((present + excused) / total) * 100;
        
        // At-risk if below threshold, prioritize lowest percentage
        if (percentage < requiredPercentage) {
          if (percentage < lowestPercentage) {
            lowestPercentage = percentage;
            mostAtRiskSubject = {
              'subject': subject,
              'stats': stats,
              'percentage': percentage,
              'requiredPercentage': requiredPercentage,
            };
          }
        }
      }

      // If no subject is below threshold, pick the one with lowest percentage overall
      if (mostAtRiskSubject == null) {
        lowestPercentage = double.infinity;
        for (final subject in subjects) {
          final subjectName = subject['name'] as String;
          final requiredPercentage = (subject['requiredPercentage'] as num?)?.toDouble() ?? defaultThreshold;
          
          final stats = await DatabaseHelper.instance.getAttendanceStatsForSubject(subjectName);
          final total = (stats['total'] as int?) ?? 0;
          final present = (stats['present'] as int?) ?? 0;
          final excused = (stats['excused'] as int?) ?? 0;
          
          if (total == 0) continue;
          
          final percentage = ((present + excused) / total) * 100;
          
          if (percentage < lowestPercentage) {
            lowestPercentage = percentage;
            mostAtRiskSubject = {
              'subject': subject,
              'stats': stats,
              'percentage': percentage,
              'requiredPercentage': requiredPercentage,
            };
          }
        }
      }

      String subjectName;
      int attended = 0;
      int total = 0;
      int percentage = 0;
      String statusColor;
      String canMissText;
      double threshold;
      bool isAtRisk;

      if (mostAtRiskSubject != null) {
        final subject = mostAtRiskSubject['subject'] as Map<String, dynamic>;
        final stats = mostAtRiskSubject['stats'] as Map<String, dynamic>;
        final pct = mostAtRiskSubject['percentage'] as double;
        threshold = mostAtRiskSubject['requiredPercentage'] as double;
        
        subjectName = subject['name'] as String;
        attended = ((stats['present'] as int?) ?? 0) + ((stats['excused'] as int?) ?? 0);
        total = (stats['total'] as int?) ?? 0;
        percentage = pct.round();
        
        // Determine status color
        if (pct < threshold - 15) {
          statusColor = 'red';
        } else if (pct < threshold - 5) {
          statusColor = 'orange';
        } else if (pct < threshold) {
          statusColor = 'yellow';
        } else {
          statusColor = 'green';
        }
        
        isAtRisk = pct < threshold;
        
        // Calculate "can miss X more" text
        if (isAtRisk) {
          final canMiss = ((attended / (threshold / 100)) - total).floor();
          if (canMiss <= 0) {
            canMissText = 'CRITICAL: Cannot miss any more classes!';
          } else if (canMiss == 1) {
            canMissText = 'Can miss 1 more class';
          } else {
            canMissText = 'Can miss $canMiss more classes';
          }
        } else {
          final canMiss = ((attended / (threshold / 100)) - total).floor();
          if (canMiss <= 0) {
            canMissText = 'At threshold - cannot miss any';
          } else if (canMiss == 1) {
            canMissText = 'Can safely miss 1 class';
          } else {
            canMissText = 'Can safely miss $canMiss classes';
          }
        }
      } else {
        subjectName = 'No Data';
        statusColor = 'grey';
        canMissText = 'No attendance data available';
        threshold = defaultThreshold;
        isAtRisk = false;
      }

      final data = <String, dynamic>{
        'subjectName': subjectName,
        'percentage': percentage,
        'attended': attended,
        'total': total,
        'statusColor': statusColor,
        'canMissText': canMissText,
        'threshold': threshold,
        'isAtRisk': isAtRisk,
      };

      await _writeWidgetData('attendance_widget_data.json', data);
      await _channel.invokeMethod('updateAttendanceWidget');
    } catch (e) {
      debugPrint('Attendance widget refresh error: $e');
    }
  }

  // ==================== TIMETABLE WIDGET ====================
  static Future<void> refreshTimetableWidget() async {
    try {
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1=Mon, 7=Sun
      final currentTimeMinutes = now.hour * 60 + now.minute;
      
      final upcomingClasses = <Map<String, dynamic>>[];
      
      // Search today + tomorrow (max 2 days)
      for (int dayOffset = 0; dayOffset < 2; dayOffset++) {
        if (upcomingClasses.length >= 3) break;
        
        final searchDate = now.add(Duration(days: dayOffset));
        final searchWeekday = searchDate.weekday;
        
        // Get timetable classes for this day
        final classes = await DatabaseHelper.instance.getTimetableClassesForDay(searchWeekday);
        
        for (final cls in classes) {
          if (upcomingClasses.length >= 3) break;
          
          final startTimeMinutes = (cls['startTimeMinutes'] as int?) ?? 0;
          final endTimeMinutes = (cls['endTimeMinutes'] as int?) ?? 0;
          
          // For today, skip classes that have already ended
          if (dayOffset == 0 && endTimeMinutes <= currentTimeMinutes) {
            continue;
          }
          
          // Calculate countdown minutes
          int countdownMinutes;
          if (dayOffset == 0) {
            countdownMinutes = startTimeMinutes - currentTimeMinutes;
          } else {
            countdownMinutes = (dayOffset * 24 * 60) + startTimeMinutes - currentTimeMinutes;
          }
          
          // Format time slot
          final startHour = startTimeMinutes ~/ 60;
          final startMin = startTimeMinutes % 60;
          final endHour = endTimeMinutes ~/ 60;
          final endMin = endTimeMinutes % 60;
          final timeSlot = '${_pad(startHour)}:${_pad(startMin)} - ${_pad(endHour)}:${_pad(endMin)}';
          
          // Format countdown text
          String countdownText;
          if (countdownMinutes < 60) {
            countdownText = '${countdownMinutes}m';
          } else if (countdownMinutes < 24 * 60) {
            final hours = countdownMinutes ~/ 60;
            final mins = countdownMinutes % 60;
            countdownText = '${hours}h ${mins}m';
          } else {
            final days = countdownMinutes ~/ (24 * 60);
            final hours = (countdownMinutes % (24 * 60)) ~/ 60;
            countdownText = '${days}d ${hours}h';
          }
          
          upcomingClasses.add({
            'subject': cls['subjectName'] ?? 'Unknown',
            'timeSlot': timeSlot,
            'room': cls['room'] ?? 'TBD',
            'countdownMinutes': countdownMinutes,
            'countdownText': countdownText,
            'colorHex': cls['colorHex'] ?? '#2196F3',
            'dayOffset': dayOffset,
            'isToday': dayOffset == 0,
            'startTimeMinutes': startTimeMinutes,
            'endTimeMinutes': endTimeMinutes,
            'professor': cls['professor'] ?? '',
            'classType': cls['classType'] ?? 'lecture',
          });
        }
      }
      
      // Sort by countdown (soonest first)
      upcomingClasses.sort((a, b) => (a['countdownMinutes'] as int).compareTo(b['countdownMinutes'] as int));
      
      // Take only top 3
      final top3Classes = upcomingClasses.take(3).toList();
      
      // Format day name
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayName = dayNames[now.weekday - 1];
      final tomorrowName = dayNames[(now.weekday) % 7];
      
      final data = <String, dynamic>{
        'dayName': todayName,
        'dateText': '${_monthName(now.month)} ${now.day}',
        'nextDayName': tomorrowName,
        'classes': top3Classes,
        'totalUpcoming': upcomingClasses.length,
        'hasMore': upcomingClasses.length > 3,
      };

      await _writeWidgetData('timetable_widget_data.json', data);
      await _channel.invokeMethod('updateTimetableWidget');
    } catch (e) {
      debugPrint('Timetable widget refresh error: $e');
    }
  }

  // ==================== HABIT WIDGET (NEW) ====================
  static Future<void> refreshHabitWidget() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final weekStart = todayStart - ((now.weekday - 1) * const Duration(days: 1).inMilliseconds);
      
      final habits = await DatabaseHelper.instance.getAllHabits(includeArchived: false);
      
      if (habits.isEmpty) {
        final data = <String, dynamic>{
          'habitName': 'No Habits',
          'weekProgress': 0,
          'weekTarget': 0,
          'streak': 0,
          'todayCompleted': false,
          'statusColor': 'grey',
          'message': 'Add habits to start tracking',
        };
        await _writeWidgetData('habit_widget_data.json', data);
        await _channel.invokeMethod('updateHabitWidget');
        return;
      }

      // Find the habit with the best streak to showcase
      Map<String, dynamic>? featuredHabit;
      int bestStreak = -1;
      
      for (final habit in habits) {
        final habitId = habit['id'] as int;
        final streak = await DatabaseHelper.instance.getHabitStreak(habitId);
        if (streak > bestStreak) {
          bestStreak = streak;
          featuredHabit = habit;
        }
      }
      
      // If no streaks, pick the first habit
      featuredHabit ??= habits.first;
      final habitId = featuredHabit['id'] as int;
      final habitName = featuredHabit['name'] as String;
      final targetPerWeek = (featuredHabit['targetPerWeek'] as int?) ?? 7;
      final colorHex = (featuredHabit['colorHex'] as String?) ?? '#4CAF50';
      
      // Get weekly stats
      final weeklyStats = await DatabaseHelper.instance.getHabitWeeklyStats(habitId, weekStart);
      final weekProgress = weeklyStats['completed'] as int;
      final streak = await DatabaseHelper.instance.getHabitStreak(habitId);
      
      // Check today's completion
      final todayLog = await DatabaseHelper.instance.getHabitLogForDate(habitId, todayStart);
      final todayCompleted = todayLog != null && (todayLog['completed'] as int?) == 1;
      
      // Determine status color
      String statusColor;
      final percentage = targetPerWeek > 0 ? (weekProgress / targetPerWeek * 100).round() : 0;
      if (percentage >= 100) {
        statusColor = 'green';
      } else if (percentage >= 75) {
        statusColor = 'light_green';
      } else if (percentage >= 50) {
        statusColor = 'yellow';
      } else if (percentage >= 25) {
        statusColor = 'orange';
      } else {
        statusColor = 'red';
      }
      
      final data = <String, dynamic>{
        'habitName': habitName,
        'weekProgress': weekProgress,
        'weekTarget': targetPerWeek,
        'streak': streak,
        'todayCompleted': todayCompleted,
        'statusColor': statusColor,
        'percentage': percentage,
        'colorHex': colorHex,
        'message': '$weekProgress / $targetPerWeek this week',
      };

      await _writeWidgetData('habit_widget_data.json', data);
      await _channel.invokeMethod('updateHabitWidget');
    } catch (e) {
      debugPrint('Habit widget refresh error: $e');
    }
  }

  // ==================== READING WIDGET (NEW) ====================
  static Future<void> refreshReadingWidget() async {
    try {
      final books = await DatabaseHelper.instance.getAllReadingBooks(includeCompleted: false);
      
      if (books.isEmpty) {
        final data = <String, dynamic>{
          'bookTitle': 'No Books',
          'author': '',
          'progressPercent': 0,
          'currentPage': 0,
          'totalPages': 0,
          'pagesLeft': 0,
          'minutesReadToday': 0,
          'totalMinutesRead': 0,
          'statusColor': 'grey',
          'message': 'Add books to track reading',
        };
        await _writeWidgetData('reading_widget_data.json', data);
        await _channel.invokeMethod('updateReadingWidget');
        return;
      }

      // Pick the book with the most progress (closest to completion)
      Map<String, dynamic>? featuredBook;
      double bestProgress = -1;
      
      for (final book in books) {
        final totalPages = (book['totalPages'] as int?) ?? 1;
        final currentPage = (book['currentPage'] as int?) ?? 0;
        final progress = totalPages > 0 ? currentPage / totalPages : 0.0;
        if (progress > bestProgress) {
          bestProgress = progress;
          featuredBook = book;
        }
      }
      
      featuredBook ??= books.first;
      final bookId = featuredBook['id'] as int;
      final bookTitle = featuredBook['title'] as String;
      final author = (featuredBook['author'] as String?) ?? 'Unknown Author';
      final totalPages = (featuredBook['totalPages'] as int?) ?? 1;
      final currentPage = (featuredBook['currentPage'] as int?) ?? 0;
      final minutesReadToday = (featuredBook['minutesReadToday'] as int?) ?? 0;
      final totalMinutesRead = (featuredBook['totalMinutesRead'] as int?) ?? 0;
      
      final progressPercent = totalPages > 0 ? (currentPage / totalPages * 100).round() : 0;
      final pagesLeft = totalPages - currentPage;
      
      // Get detailed progress stats
      final progressStats = await DatabaseHelper.instance.getReadingProgress(bookId);
      final onTrack = progressStats['onTrack'] as bool? ?? true;
      
      // Determine status color
      String statusColor;
      if (progressPercent >= 90) {
        statusColor = 'green';
      } else if (progressPercent >= 60) {
        statusColor = 'light_green';
      } else if (progressPercent >= 30) {
        statusColor = 'blue';
      } else {
        statusColor = 'orange';
      }
      if (!onTrack) statusColor = 'red';
      
      final data = <String, dynamic>{
        'bookTitle': bookTitle,
        'author': author,
        'progressPercent': progressPercent,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'pagesLeft': pagesLeft,
        'minutesReadToday': minutesReadToday,
        'totalMinutesRead': totalMinutesRead,
        'statusColor': statusColor,
        'onTrack': onTrack,
        'message': '$currentPage / $totalPages pages',
        'dailyPageGoal': progressStats['dailyPageGoal'] ?? 20,
        'pagesPerDayNeeded': progressStats['pagesPerDayNeeded'] ?? 0,
      };

      await _writeWidgetData('reading_widget_data.json', data);
      await _channel.invokeMethod('updateReadingWidget');
    } catch (e) {
      debugPrint('Reading widget refresh error: $e');
    }
  }

  // ==================== HELPER METHODS ====================
  static Future<void> _writeWidgetData(String filename, Map<String, dynamic> data) async {
    try {
      // FIXED: Write to filesDir so Android Kotlin side can read from context.filesDir
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonEncode(data));
      debugPrint('Widget data written to: ${file.path}');
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
