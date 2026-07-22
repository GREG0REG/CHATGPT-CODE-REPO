import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../database_helper.dart';
import '../models/event.dart';

/// Exports/imports events to/from JSON files.
///
/// IMPORTANT: [exportToJson] and [exportAllData] save files to the app's
/// private documents directory. These files are DELETED when the user clears
/// app storage. For persistent exports, use [exportAndShareEvents],
/// [exportAndShareAllData], [saveExportToDevice], or [saveFullExportToDevice].
class ExportImportService {
  ExportImportService._();

  // ==================== INTERNAL EXPORT (app-private storage) ====================

  /// Writes all events to a JSON file in the app's private documents directory.
  /// WARNING: This file is deleted when app storage is cleared. Use
  /// [exportAndShareEvents] or [saveExportToDevice] for persistent exports.
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

  /// Exports ALL database tables to a JSON file in the app's private documents directory.
  /// WARNING: This file is deleted when app storage is cleared. Use
  /// [exportAndShareAllData] or [saveFullExportToDevice] for persistent exports.
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

  // ==================== SHARE EXPORT (system share sheet) ====================

  /// Exports events and immediately opens the system share sheet.
  /// The user can save to Downloads, email, cloud storage, etc.
  static Future<void> exportAndShareEvents() async {
    final path = await exportToJson();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Event Countdown Export',
      text: 'Here is my Event Countdown export file.',
    );
  }

  /// Exports all data and immediately opens the system share sheet.
  /// The user can save to Downloads, email, cloud storage, etc.
  static Future<void> exportAndShareAllData() async {
    final path = await exportAllData();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Event Countdown Full Export',
      text: 'Here is my complete Event Countdown data export.',
    );
  }

  // Legacy aliases
  static Future<void> shareExport() => exportAndShareEvents();
  static Future<void> shareFullExport() => exportAndShareAllData();

  // ==================== SAVE TO DEVICE (file picker save dialog) ====================

  /// Exports events and opens a system save dialog so the user can choose
  /// exactly where to save the file (e.g., Downloads folder).
  /// Returns the path where the file was saved, or null if cancelled.
  static Future<String?> saveExportToDevice() async {
    final exportPath = await exportToJson();
    final fileName = p.basename(exportPath);

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Event Export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath == null) return null;

    final bytes = await File(exportPath).readAsBytes();
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  /// Exports all data and opens a system save dialog so the user can choose
  /// exactly where to save the file (e.g., Downloads folder).
  /// Returns the path where the file was saved, or null if cancelled.
  static Future<String?> saveFullExportToDevice() async {
    final exportPath = await exportAllData();
    final fileName = p.basename(exportPath);

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Full Export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath == null) return null;

    final bytes = await File(exportPath).readAsBytes(bytes);
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  // ==================== EVENT-ONLY IMPORT ====================

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

  // ==================== COMPREHENSIVE IMPORT ====================

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
