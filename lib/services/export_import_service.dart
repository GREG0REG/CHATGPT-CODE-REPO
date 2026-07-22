import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../database_helper.dart';
import '../models/event.dart';

/// Exports/imports events to/from a local JSON file. Purely local - no
/// network calls, no cloud storage.
///
/// FIXES:
/// - Issue 53: Removed deprecated Permission.storage usage.
/// - Issue 54: Removed hardcoded /storage/emulated/0/Download path.
/// - Issue 55: Validates ALL events BEFORE replacing database. Backup + rollback.
/// - Issue 56: Added comprehensive exportAllData() / importAllData() for all tables.
/// - Issue 57: Completed shareExport() with Share.shareXFiles().
class ExportImportService {
  ExportImportService._();

  // ==================== EVENT-ONLY EXPORT/IMPORT ====================

  /// Writes all events to a JSON file in the app's documents directory
  /// and returns the file path. The file can then be shared via shareExport().
  static Future<String> exportToJson() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'event_countdown_export_$timestamp.json';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsString(jsonString);

    return appFile.path;
  }

  /// Reads events from a JSON file at [filePath] and replaces the current
  /// database contents with them.
  ///
  /// Validates every event BEFORE touching the database. If validation or
  /// import fails, the original database is restored from backup.
  static Future<int> importFromJson(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      throw Exception('File is empty');
    }

    final decoded = jsonDecode(contents);

    // Support both old format (List) and new comprehensive format
    List<dynamic> eventList;
    if (decoded is List) {
      eventList = decoded;
    } else if (decoded is Map &&
        decoded['tables'] != null &&
        decoded['tables']['events'] != null) {
      eventList = decoded['tables']['events'] as List;
    } else {
      throw Exception(
          'Invalid JSON format: expected a list of events or a comprehensive export');
    }

    // Validate ALL events BEFORE touching the database
    final events = <Event>[];
    for (var i = 0; i < eventList.length; i++) {
      final item = eventList[i];
      if (item is! Map) {
        throw Exception(
            'Invalid event format at index $i: expected a map, got ${item.runtimeType}');
      }
      try {
        final event = Event.fromJson(Map<String, dynamic>.from(item as Map));
        events.add(event);
      } catch (e) {
        throw Exception('Invalid event at index $i: $e');
      }
    }

    // Backup existing events before replacing
    final backup = await DatabaseHelper.instance.getAllEventsSorted();

    try {
      await DatabaseHelper.instance.replaceAllEvents(events);
    } catch (e) {
      // Rollback on failure
      await DatabaseHelper.instance.replaceAllEvents(backup);
      throw Exception(
          'Import failed. Database restored from backup. Error: $e');
    }

    return events.length;
  }

  // ==================== COMPREHENSIVE EXPORT/IMPORT ====================

  /// Exports ALL database tables (events, study data, flashcards, notes, etc.)
  /// into a single JSON file and returns its path.
  static Future<String> exportAllData() async {
    final allData = await DatabaseHelper.instance.exportAllTables();

    final exportMap = {
      'exportVersion': 1,
      'appName': 'event_countdown',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': allData,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'event_countdown_full_export_$timestamp.json';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsString(jsonString);

    return appFile.path;
  }

  /// Imports ALL database tables from a comprehensive export file.
  ///
  /// Validates the export format and event data BEFORE touching the database.
  /// If anything fails, the original database is restored from backup.
  static Future<void> importAllData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      throw Exception('File is empty');
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map) {
      throw Exception('Invalid export format: expected a map');
    }

    final exportVersion = decoded['exportVersion'];
    if (exportVersion != 1) {
      throw Exception('Unsupported export version: $exportVersion');
    }

    final tablesData = decoded['tables'];
    if (tablesData is! Map) {
      throw Exception(
          'Invalid export format: missing or invalid "tables" key');
    }

    final typedTables = <String, List<Map<String, dynamic>>>{};
    for (final entry in (tablesData as Map).entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! List) {
        throw Exception(
            'Invalid data for table "$key": expected a list, got ${value.runtimeType}');
      }
      typedTables[key] = value.cast<Map<String, dynamic>>();
    }

    // Validate events specifically if present
    if (typedTables.containsKey('events')) {
      final eventList = typedTables['events']!;
      for (var i = 0; i < eventList.length; i++) {
        try {
          Event.fromJson(eventList[i]);
        } catch (e) {
          throw Exception(
              'Invalid event at index $i in "events" table: $e');
        }
      }
    }

    // Backup before import
    final backup = await DatabaseHelper.instance.exportAllTables();

    try {
      await DatabaseHelper.instance.importAllTables(typedTables);
    } catch (e) {
      // Rollback
      await DatabaseHelper.instance.importAllTables(backup);
      throw Exception(
          'Import failed. Database restored from backup. Error: $e');
    }
  }

  // ==================== SHARE ====================

  /// Share the event-only export file using the system share sheet.
  static Future<void> shareExport() async {
    final path = await exportToJson();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Event Countdown Export',
      text: 'Here is my Event Countdown export file.',
    );
  }

  /// Share the comprehensive export file using the system share sheet.
  static Future<void> shareFullExport() async {
    final path = await exportAllData();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Event Countdown Full Export',
      text: 'Here is my complete Event Countdown data export.',
    );
  }

  // ==================== FILE PICKER IMPORT ====================

  /// Let the user pick a JSON file and import events only.
  static Future<int> importEventsFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final path = result.files.single.path;
    if (path == null) {
      throw Exception('Could not access file path');
    }

    return importFromJson(path);
  }

  /// Let the user pick a JSON file and import all data comprehensively.
  static Future<void> importAllDataFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final path = result.files.single.path;
    if (path == null) {
      throw Exception('Could not access file path');
    }

    return importAllData(path);
  }
}
