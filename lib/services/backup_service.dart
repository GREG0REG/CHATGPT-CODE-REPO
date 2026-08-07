// FILE: lib/services/backup_service.dart
// COMPLETE REPLACEMENT — Fixed row count bug, added empty backup warning
// CHANGES from previous version:
//   1. _importFullTables now counts ACTUAL rows from file, not just tables
//   2. Added warning when importing empty backup (all tables have 0 rows)
//   3. Safety backup row count also fixed

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'package:event_countdown/database_helper.dart';
import 'package:event_countdown/models/event.dart';

// ── Result objects ─────────────────────────────────────────────

class BackupResult {
  final bool success;
  final String? filePath;
  final String? message;
  final int? eventCount;
  final int? tableCount;

  const BackupResult._({
    required this.success,
    this.filePath,
    this.message,
    this.eventCount,
    this.tableCount,
  });

  factory BackupResult.ok({required String filePath, String? message, int? eventCount, int? tableCount}) =>
      BackupResult._(success: true, filePath: filePath, message: message, eventCount: eventCount, tableCount: tableCount);

  factory BackupResult.fail(String message) =>
      BackupResult._(success: false, message: message);
}

class ImportResult {
  final bool success;
  final String? message;
  final int? eventCount;
  final int? tableCount;
  final int? totalRows;        // NEW: actual total rows restored
  final bool wasEmpty;         // NEW: true if backup had 0 rows total

  const ImportResult._({
    required this.success,
    this.message,
    this.eventCount,
    this.tableCount,
    this.totalRows,
    this.wasEmpty = false,
  });

  factory ImportResult.ok({
    String? message,
    int? eventCount,
    int? tableCount,
    int? totalRows,
    bool wasEmpty = false,
  }) => ImportResult._(
    success: true,
    message: message,
    eventCount: eventCount,
    tableCount: tableCount,
    totalRows: totalRows,
    wasEmpty: wasEmpty,
  );

  factory ImportResult.fail(String message) =>
      ImportResult._(success: false, message: message);
}

// ── Main service ───────────────────────────────────────────────

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const String _appName = 'StudyFlow';
  static const String _appVersion = '1.0.0';
  static const int _exportVersion = 1;

  static const List<String> _backupPrefixes = [
    'studyflow_events_',
    'studyflow_full_',
    'studyflow_backup_',
    'event_countdown_backup_',
  ];

  // ── Internal helpers ────────────────────────────────────────

  String _fileName(String prefix) {
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return '${prefix}_$ts.json';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<Directory> get _appDir async {
    final d = await getApplicationDocumentsDirectory();
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory?> get _downloadsDir async {
    if (!Platform.isAndroid) return null;
    final d = Directory('/storage/emulated/0/Download');
    if (await d.exists()) return d;
    return null;
  }

  Future<String> _writeFile(String fileName, String jsonString) async {
    final dir = await _appDir;
    final path = p.join(dir.path, fileName);
    final file = File(path);
    await file.writeAsString(jsonString, encoding: utf8, flush: true);

    if (!await file.exists()) throw Exception('File write failed: $path');
    final size = await file.length();
    if (size == 0) throw Exception('File written but empty: $path');
    if (size < jsonString.length) throw Exception('File truncated: $path');

    return path;
  }

  Future<String?> _copyToDownloads(String sourcePath, String fileName) async {
    final downloads = await _downloadsDir;
    if (downloads == null) return null;
    try {
      final dest = File(p.join(downloads.path, fileName));
      await File(sourcePath).copy(dest.path);
      return dest.path;
    } catch (e) {
      if (kDebugMode) debugPrint('Downloads copy failed: $e');
      return null;
    }
  }

  String _prettyJson(dynamic object) =>
      const JsonEncoder.withIndent('  ').convert(object);

  dynamic _safeJsonDecode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) throw Exception('File is empty');
    return jsonDecode(trimmed);
  }

  bool _isOurBackup(String path) {
    final name = p.basename(path).toLowerCase();
    if (!name.endsWith('.json')) return false;
    return _backupPrefixes.any((prefix) => name.startsWith(prefix.toLowerCase()));
  }

  // ── Export: Events only ─────────────────────────────────────

  Future<BackupResult> exportEvents({bool share = false, bool saveToDownloads = false}) async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final jsonList = events.map((e) => e.toJson()).toList();

      final payload = {
        'exportVersion': _exportVersion,
        'appName': _appName,
        'appVersion': _appVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'exportType': 'events',
        'eventCount': events.length,
        'events': jsonList,
      };

      final jsonString = _prettyJson(payload);
      final fileName = _fileName('studyflow_events');
      final path = await _writeFile(fileName, jsonString);

      String? downloadPath;
      if (saveToDownloads) {
        downloadPath = await _copyToDownloads(path, fileName);
      }

      if (share) {
        try {
          await Share.shareXFiles(
            [XFile(path, mimeType: 'application/json', name: fileName)],
            subject: 'StudyFlow Events',
            text: 'StudyFlow events backup (${events.length} events)',
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Share failed: $e');
        }
      }

      return BackupResult.ok(
        filePath: downloadPath ?? path,
        message: 'Exported ${events.length} events',
        eventCount: events.length,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('exportEvents error: $e');
        debugPrint(st.toString());
      }
      return BackupResult.fail('Export failed: $e');
    }
  }

  // ── Export: Full database ───────────────────────────────────

  Future<BackupResult> exportFull({bool share = false, bool saveToDownloads = false}) async {
    try {
      final allData = await DatabaseHelper.instance.exportAllTables();

      // Count actual rows for the message
      int totalRows = 0;
      for (final rows in allData.values) {
        totalRows += rows.length;
      }

      final payload = {
        'exportVersion': _exportVersion,
        'appName': _appName,
        'appVersion': _appVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'exportType': 'full',
        'tableCount': allData.length,
        'totalRows': totalRows,   // NEW: include row count in file
        'tables': allData,
      };

      final jsonString = _prettyJson(payload);
      final fileName = _fileName('studyflow_full');
      final path = await _writeFile(fileName, jsonString);

      String? downloadPath;
      if (saveToDownloads) {
        downloadPath = await _copyToDownloads(path, fileName);
      }

      if (share) {
        try {
          await Share.shareXFiles(
            [XFile(path, mimeType: 'application/json', name: fileName)],
            subject: 'StudyFlow Full Backup',
            text: 'StudyFlow full database backup (${allData.length} tables, $totalRows rows)',
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Share failed: $e');
        }
      }

      return BackupResult.ok(
        filePath: downloadPath ?? path,
        message: 'Exported ${allData.length} tables, $totalRows rows',
        tableCount: allData.length,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('exportFull error: $e');
        debugPrint(st.toString());
      }
      return BackupResult.fail('Full export failed: $e');
    }
  }

  // ── Import: Auto-detect type ────────────────────────────────

  Future<ImportResult> importFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return ImportResult.fail('File not found');
      final raw = await file.readAsString(encoding: utf8);
      final decoded = _safeJsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return ImportResult.fail('Invalid format: expected JSON object');
      }

      final exportType = decoded['exportType'] as String?;
      if (exportType == null) {
        if (decoded is List) {
          return _importEventsList(decoded as List);
        }
        return ImportResult.fail('Unknown format: missing exportType');
      }

      // Safety backup before any destructive operation
      final safetyBackup = await exportFull();

      if (exportType == 'events') {
        final eventsList = decoded['events'];
        if (eventsList is! List) {
          return ImportResult.fail('Invalid events format');
        }
        return _importEventsList(eventsList, safetyBackup: safetyBackup.filePath);
      }

      if (exportType == 'full') {
        final tables = decoded['tables'];
        if (tables is! Map<String, dynamic>) {
          return ImportResult.fail('Invalid full backup format');
        }
        return _importFullTables(tables, safetyBackup: safetyBackup.filePath);
      }

      return ImportResult.fail('Unknown exportType: $exportType');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('importFromPath error: $e');
        debugPrint(st.toString());
      }
      return ImportResult.fail('Import failed: $e');
    }
  }

  Future<ImportResult> importFromPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return ImportResult.fail('No file selected');
      }
      final path = result.files.single.path;
      if (path == null) return ImportResult.fail('Could not access file path');
      return importFromPath(path);
    } catch (e) {
      return ImportResult.fail('Picker failed: $e');
    }
  }

  // ── Internal import logic ───────────────────────────────────
  // FIXED: Count actual rows from the file, not just tables

  Future<ImportResult> _importEventsList(List<dynamic> rawList, {String? safetyBackup}) async {
    final events = <Event>[];
    final errors = <String>[];

    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is! Map<String, dynamic>) {
        errors.add('Index $i: expected map, got ${item.runtimeType}');
        continue;
      }
      try {
        events.add(Event.fromJson(item));
      } catch (e) {
        errors.add('Index $i: $e');
      }
    }

    if (events.isEmpty) {
      final errMsg = errors.isEmpty
          ? 'No events found in file'
          : 'All events failed to parse:\n${errors.take(5).join('\n')}';
      return ImportResult.fail(errMsg);
    }

    if (errors.isNotEmpty && kDebugMode) {
      debugPrint('Import warnings (${errors.length} items skipped):\n${errors.take(10).join('\n')}');
    }

    try {
      await DatabaseHelper.instance.replaceAllEvents(events);
      return ImportResult.ok(
        message: errors.isEmpty
            ? 'Imported ${events.length} events'
            : 'Imported ${events.length} events (${errors.length} skipped)',
        eventCount: events.length,
      );
    } catch (e) {
      if (safetyBackup != null) {
        try {
          await _restoreSafetyBackup(safetyBackup);
        } catch (restoreErr) {
          return ImportResult.fail('Import failed AND auto-restore failed. Database may be corrupted. Error: $restoreErr');
        }
      }
      return ImportResult.fail('Import failed (database restored): $e');
    }
  }

  // FIXED: Count actual rows from file, warn if empty
  Future<ImportResult> _importFullTables(Map<String, dynamic> tables, {String? safetyBackup}) async {
    // Validate: check that 'events' table parses correctly before wiping anything
    final eventRows = tables['events'];
    if (eventRows is List) {
      for (int i = 0; i < eventRows.length; i++) {
        try {
          if (eventRows[i] is Map<String, dynamic>) {
            Event.fromMap(eventRows[i] as Map<String, dynamic>);
          }
        } catch (e) {
          return ImportResult.fail('Event validation failed at index $i: $e');
        }
      }
    }

    try {
      // Cast all table data to correct types
      final typedTables = <String, List<Map<String, dynamic>>>{};
      int totalRowsFromFile = 0;   // FIXED: count actual rows

      for (final entry in tables.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is! List) continue;

        final rows = <Map<String, dynamic>>[];
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            rows.add(item);
          } else if (item is Map) {
            rows.add(Map<String, dynamic>.from(item));
          }
        }
        typedTables[key] = rows;
        totalRowsFromFile += rows.length;   // FIXED: count rows
      }

      await DatabaseHelper.instance.importAllTables(typedTables);

      // FIXED: Build message with actual row count and warn if empty
      final bool wasEmpty = totalRowsFromFile == 0;
      String message;
      if (wasEmpty) {
        message = '⚠️ Restored ${typedTables.length} tables but backup is EMPTY (0 rows).\n\nYour data was NOT restored because the backup file contains no data. Make sure you export AFTER adding events.';
      } else {
        message = 'Restored ${typedTables.length} tables, $totalRowsFromFile rows';
      }

      return ImportResult.ok(
        message: message,
        tableCount: typedTables.length,
        totalRows: totalRowsFromFile,
        wasEmpty: wasEmpty,
      );
    } catch (e) {
      if (safetyBackup != null) {
        try {
          await _restoreSafetyBackup(safetyBackup);
        } catch (restoreErr) {
          return ImportResult.fail('Import failed AND auto-restore failed. Database may be corrupted. Error: $restoreErr');
        }
      }
      return ImportResult.fail('Full import failed (database restored): $e');
    }
  }

  Future<void> _restoreSafetyBackup(String path) async {
    final file = File(path);
    final raw = await file.readAsString(encoding: utf8);
    final decoded = _safeJsonDecode(raw) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    final typedTables = <String, List<Map<String, dynamic>>>{};
    for (final entry in tables.entries) {
      final rows = <Map<String, dynamic>>[];
      if (entry.value is List) {
        for (final item in entry.value as List) {
          if (item is Map<String, dynamic>) rows.add(item);
          else if (item is Map) rows.add(Map<String, dynamic>.from(item));
        }
      }
      typedTables[entry.key] = rows;
    }
    await DatabaseHelper.instance.importAllTables(typedTables);
  }

  // ── Find recent backup ──────────────────────────────────────

  Future<String?> findRecentBackup() async {
    final candidates = <File>[];

    final appDir = await _appDir;
    await for (final entity in appDir.list()) {
      if (entity is File && _isOurBackup(entity.path)) {
        candidates.add(entity);
      }
    }

    final downloads = await _downloadsDir;
    if (downloads != null && await downloads.exists()) {
      await for (final entity in downloads.list()) {
        if (entity is File && _isOurBackup(entity.path)) {
          candidates.add(entity);
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (_) {
        return b.path.compareTo(a.path);
      }
    });

    return candidates.first.path;
  }

  // ── Manual backup (used by Workmanager) ─────────────────────

  Future<String> createAutoBackup() async {
    final result = await exportFull();
    if (!result.success || result.filePath == null) {
      throw Exception(result.message ?? 'Auto-backup failed');
    }
    final fileName = p.basename(result.filePath!);
    await _copyToDownloads(result.filePath!, fileName);
    return result.filePath!;
  }

  // ── Plain JSON export ───────────────────────────────────────

  Future<BackupResult> exportEventsPlain() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final jsonList = events.map((e) => e.toJson()).toList();
      final jsonString = _prettyJson(jsonList);
      final fileName = _fileName('studyflow_plain');
      final path = await _writeFile(fileName, jsonString);
      return BackupResult.ok(
        filePath: path,
        message: 'Plain JSON: ${events.length} events',
        eventCount: events.length,
      );
    } catch (e) {
      return BackupResult.fail('Plain export failed: $e');
    }
  }

  // ── Save to specific location ───────────────────────────────

  Future<BackupResult> saveEventsToDevice() async {
    final result = await exportEvents();
    if (!result.success || result.filePath == null) return result;

    try {
      final fileName = p.basename(result.filePath!);
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Events Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (outputPath == null) {
        return BackupResult.fail('Save cancelled');
      }
      final bytes = await File(result.filePath!).readAsBytes();
      await File(outputPath).writeAsBytes(bytes);
      return BackupResult.ok(
        filePath: outputPath,
        message: 'Saved to $outputPath',
        eventCount: result.eventCount,
      );
    } catch (e) {
      return BackupResult.fail('Save failed: $e');
    }
  }
}
