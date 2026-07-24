import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../services/countdown_service.dart';
import '../services/settings_service.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _widgetDataFileName = 'widget_data.json';
  static const String _channel = 'com.example.event_countdown/widget';
  static const MethodChannel _platform = MethodChannel(_channel);

  static Future<void> refreshWidget() async {
    try {
      final smartFormatEnabled = await SettingsService.instance.getSmartFormatEnabled();

      // Write toggle to SharedPreferences so Android widget can read it
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smart_countdown_enabled', smartFormatEnabled);

      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final now = DateTime.now();

      Event? nextEvent;
      for (final e in events) {
        if (e.isCompleted) continue;
        if (e.finalMillis > now.millisecondsSinceEpoch) {
          nextEvent = e;
          break;
        }
      }

      final data = <String, dynamic>{};

      if (nextEvent != null) {
        final result = CountdownService.buildCountdownText(
          nextEvent,
          now,
          smartFormatEnabled: smartFormatEnabled,
        );

        int progressPercent = 0;
        if (nextEvent.startTimeMillis != null && nextEvent.deadlineMillis != null) {
          final total = nextEvent.deadlineMillis! - nextEvent.startTimeMillis!;
          final elapsed = now.millisecondsSinceEpoch - nextEvent.startTimeMillis!;
          if (total > 0) progressPercent = ((elapsed / total) * 100).toInt().clamp(0, 100);
        } else if (nextEvent.deadlineMillis != null) {
          final total = nextEvent.deadlineMillis! - nextEvent.dateMillis;
          final elapsed = now.millisecondsSinceEpoch - nextEvent.dateMillis;
          if (total > 0) progressPercent = ((elapsed / total) * 100).toInt().clamp(0, 100);
        }

        final diff = Duration(milliseconds: nextEvent.finalMillis - now.millisecondsSinceEpoch);
        String? urgencyColor;
        String? urgencyLabel;
        if (diff.inDays < 1) {
          urgencyColor = 'red';
          urgencyLabel = 'Critical';
        } else if (diff.inDays < 3) {
          urgencyColor = 'deepOrange';
          urgencyLabel = 'Urgent';
        } else if (diff.inDays < 7) {
          urgencyColor = 'orange';
          urgencyLabel = 'Soon';
        } else if (diff.inDays < 30) {
          urgencyColor = 'green';
          urgencyLabel = 'Upcoming';
        }

        data['title'] = nextEvent.title;
        data['countdown'] = result.text;
        data['deadlineMillis'] = nextEvent.finalMillis;
        data['startMillis'] = nextEvent.startTimeMillis ?? nextEvent.dateMillis;
        data['progressPercent'] = progressPercent;
        data['urgencyColor'] = urgencyColor;
        data['urgencyLabel'] = urgencyLabel;
        data['smartFormat'] = smartFormatEnabled;
        data['bgColor'] = '#00BFA5';
        data['textColor'] = '#FFFFFF';
      } else {
        data['title'] = 'No upcoming events';
        data['countdown'] = 'Open app to add events';
        data['progressPercent'] = 0;
        data['deadlineMillis'] = 0;
        data['startMillis'] = 0;
      }

      // CRITICAL FIX: Use getApplicationSupportDirectory() which maps to Context.getFilesDir()
      // on Android. This MUST match the Kotlin side reading from context.filesDir.
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_widgetDataFileName');
      await file.writeAsString(jsonEncode(data));

      debugPrint('✅ WIDGET DATA WRITTEN: ${file.path}');
      debugPrint('✅ DATA: $data');

      try {
        await _platform.invokeMethod('updateWidget');
      } catch (e) {
        debugPrint('Method channel (optional): $e');
      }
    } catch (e, stack) {
      debugPrint('❌ Widget refresh error: $e');
      debugPrint('$stack');
    }
  }

  static Future<void> refreshPomodoroWidget() async {
    debugPrint('✅ Triggering pomodoro widget update');
    try {
      await _platform.invokeMethod('updatePomodoroWidget');
    } catch (e) {
      debugPrint('Method channel (optional): $e');
    }
  }
}
