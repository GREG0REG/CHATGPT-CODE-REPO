import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database_helper.dart';
import '../models/event.dart';

/// Exports/imports events to/from a local JSON file. Purely local - no
/// network calls, no cloud storage.
class ExportImportService {
  ExportImportService._();

  /// Writes all events to a JSON file in the app's documents directory,
  /// copies it to Downloads for easy access, and returns the file path.
  static Future<String> exportToJson() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    // Save to app documents first
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'event_countdown_export_$timestamp.json';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsString(jsonString);

    // Try to copy to Downloads for easy user access
    String? downloadsPath;
    try {
      // Request storage permission for Android 10+
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isGranted) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (downloadsDir.existsSync()) {
            final downloadsFile = File('${downloadsDir.path}/$fileName');
            await appFile.copy(downloadsFile.path);
            downloadsPath = downloadsFile.path;
          }
        }
      }
    } catch (e) {
      // Downloads not accessible, fallback to app directory only
      debugPrint('Downloads export failed: $e');
    }

    return downloadsPath ?? appFile.path;
  }

  /// Reads events from a JSON file at [filePath] and replaces the current
  /// database contents with them.
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
    if (decoded is! List) {
      throw Exception('Invalid JSON format: expected a list of events');
    }
    
    final events = decoded
        .map((e) {
          if (e is! Map) {
            throw Exception('Invalid event format in JSON');
          }
          return Event.fromJson(Map<String, dynamic>.from(e as Map));
        })
        .toList();
    
    await DatabaseHelper.instance.replaceAllEvents(events);
    return events.length;
  }

  /// Share export file using system share sheet
  static Future<void> shareExport() async {
    final path = await exportToJson();
    // Use share_plus to share the file
    // This requires adding share_plus to pubspec.yaml
  }
}
