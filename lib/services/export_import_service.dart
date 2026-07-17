import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        final downloadsFile = File('${downloadsDir.path}/$fileName');
        await appFile.copy(downloadsFile.path);
        downloadsPath = downloadsFile.path;
      }
    } catch (e) {
      // Downloads not accessible, fallback to app directory only
    }

    return downloadsPath ?? appFile.path;
  }

  /// Reads events from a JSON file at [filePath] and replaces the current
  /// database contents with them.
  static Future<int> importFromJson(String filePath) async {
    final file = File(filePath);
    final contents = await file.readAsString();
    final decoded = jsonDecode(contents) as List<dynamic>;
    final events = decoded
        .map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    await DatabaseHelper.instance.replaceAllEvents(events);
    return events.length;
  }
}
