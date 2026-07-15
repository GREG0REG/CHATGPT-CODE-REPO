import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/event.dart';

/// Exports/imports events to/from a local JSON file. Purely local - no
/// network calls, no cloud storage.
class ExportImportService {
  ExportImportService._();

  /// Writes all events to a JSON file in the app's documents directory and
  /// returns the file path.
  static Future<String> exportToJson() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/event_countdown_export_$timestamp.json');
    await file.writeAsString(jsonString);
    return file.path;
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
