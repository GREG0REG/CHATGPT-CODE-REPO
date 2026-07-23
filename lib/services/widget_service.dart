import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
          smartFormatEnabled: await SettingsService.instance.getSmartFormatEnabled(),
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
        if (diff.inDays < 1) urgencyColor = 'red';
        else if (diff.inDays < 3) urgencyColor = 'deepOrange';
        else if (diff.inDays < 7) urgencyColor = 'orange';
        else if (diff.inDays < 30) urgencyColor = 'green';

        data['title'] = nextEvent.title;
        data['countdown'] = result.text;
        data['deadlineMillis'] = nextEvent.finalMillis;
        data['startMillis'] = nextEvent.startTimeMillis ?? nextEvent.dateMillis;
        data['progressPercent'] = progressPercent;
        data['urgencyColor'] = urgencyColor;
        data['smartFormat'] = true;
        data['bgColor'] = '#00BFA5';
        data['textColor'] = '#FFFFFF';
      } else {
        data['title'] = 'No upcoming events';
        data['countdown'] = 'Add an event to see countdown';
        data['progressPercent'] = 0;
        data['deadlineMillis'] = 0;
        data['startMillis'] = 0;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_widgetDataFileName');
      await file.writeAsString(jsonEncode(data));

      debugPrint('Widget data written: ${file.path}');
      debugPrint('Data: $data');

      try {
        await _platform.invokeMethod('updateWidget');
      } catch (e) {
        debugPrint('Method channel error: $e');
      }
    } catch (e, stack) {
      debugPrint('Widget refresh error: $e');
      debugPrint('$stack');
    }
  }

  static Future<void> refreshPomodoroWidget() async {
    try {
      await _platform.invokeMethod('updatePomodoroWidget');
    } catch (e) {
      debugPrint('Pomodoro widget refresh error: $e');
    }
  }
}
