import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:workmanager/workmanager.dart';

import '../database_helper.dart';
import '../models/event.dart';

// ============================================================================
// DATA MODELS FOR ATTENDANCE & TIMETABLE
// ============================================================================

/// Represents a single attendance record
class AttendanceRecord {
  final String subject;
  final DateTime date;
  final String status; // 'present', 'absent', 'late', 'excused'
  final String? note;

  AttendanceRecord({
    required this.subject,
    required this.date,
    required this.status,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'date': date.toIso8601String(),
        'status': status,
        'note': note,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      subject: json['subject'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      note: json['note'] as String?,
    );
  }

  List<String> toCsvRow() => [
        subject,
        _formatDate(date),
        status,
        note ?? '',
      ];

  static List<String> get csvHeaders => ['Subject', 'Date', 'Status', 'Note'];

  static AttendanceRecord fromCsvRow(List<String> row) {
    if (row.length < 3) {
      throw Exception('CSV row must have at least 3 columns: subject, date, status');
    }
    return AttendanceRecord(
      subject: row[0].trim(),
      date: _parseDate(row[1].trim()),
      status: row[2].trim().toLowerCase(),
      note: row.length > 3 ? row[3].trim() : null,
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  static DateTime _parseDate(String s) {
    // Try ISO format first
    try {
      return DateTime.parse(s);
    } catch (_) {}
    // Try yyyy-MM-dd
    final parts = s.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    throw Exception('Cannot parse date: $s');
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// Represents a single timetable entry
class TimetableEntry {
  final String day; // e.g., 'Monday', 'Tuesday', or '1', '2', etc.
  final String time; // e.g., '09:00 - 10:30'
  final String subject;
  final String? room;
  final String? professor;

  TimetableEntry({
    required this.day,
    required this.time,
    required this.subject,
    this.room,
    this.professor,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'time': time,
        'subject': subject,
        'room': room,
        'professor': professor,
      };

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      day: json['day'] as String,
      time: json['time'] as String,
      subject: json['subject'] as String,
      room: json['room'] as String?,
      professor: json['professor'] as String?,
    );
  }

  List<String> toCsvRow() => [
        day,
        time,
        subject,
        room ?? '',
        professor ?? '',
      ];

  static List<String> get csvHeaders => ['Day', 'Time', 'Subject', 'Room', 'Professor'];

  static TimetableEntry fromCsvRow(List<String> row) {
    if (row.length < 3) {
      throw Exception('CSV row must have at least 3 columns: day, time, subject');
    }
    return TimetableEntry(
      day: row[0].trim(),
      time: row[1].trim(),
      subject: row[2].trim(),
      room: row.length > 3 ? row[3].trim() : null,
      professor: row.length > 4 ? row[4].trim() : null,
    );
  }
}

// ============================================================================
// CSV HELPERS
// ============================================================================

class _CsvHelper {
  static const String _eol = '\r\n';

  /// Convert list of string rows to CSV string
  static String encode(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      final escaped = row.map(_escapeField).join(',');
      buffer.write(escaped);
      buffer.write(_eol);
    }
    return buffer.toString();
  }

  /// Parse CSV string into list of string rows
  static List<List<String>> decode(String csv) {
    final rows = <List<String>>[];
    final lines = csv.split(_eol);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      rows.add(_parseLine(trimmed));
    }
    return rows;
  }

  static String _escapeField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }

  static List<String> _parseLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}

// ============================================================================
// PDF PLACEHOLDER HELPERS
// ============================================================================

class PdfPlaceholderService {
  PdfPlaceholderService._();

  /// Generates a simple text-based "PDF-like" report.
  /// This is a placeholder until a real PDF library (like pdf package) is added.
  /// Returns a .txt file formatted like a report that can be shared.
  static Future<String> generateTextReport({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String? subtitle,
  }) async {
    final buffer = StringBuffer();
    final width = 80;

    // Header
    buffer.writeln('=' * width);
    buffer.writeln(_center(title, width));
    if (subtitle != null) {
      buffer.writeln(_center(subtitle, width));
    }
    buffer.writeln(_center('Generated: ${DateTime.now().toLocal()}', width));
    buffer.writeln('=' * width);
    buffer.writeln();

    // Table
    if (rows.isEmpty) {
      buffer.writeln('No data available.');
    } else {
      // Calculate column widths
      final colCount = headers.length;
      final colWidths = List<int>.filled(colCount, 0);
      for (var i = 0; i < colCount; i++) {
        colWidths[i] = headers[i].length;
        for (final row in rows) {
          if (i < row.length && row[i].length > colWidths[i]) {
            colWidths[i] = row[i].length;
          }
        }
        colWidths[i] = (colWidths[i] + 2).clamp(3, 30);
      }

      // Print headers
      _printRow(buffer, headers, colWidths);
      buffer.writeln('-' * colWidths.reduce((a, b) => a + b + 3));
      for (final row in rows) {
        _printRow(buffer, row, colWidths);
      }
    }

    buffer.writeln();
    buffer.writeln('=' * width);
    buffer.writeln(_center('End of Report', width));
    buffer.writeln('=' * width);

    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  static String _center(String text, int width) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  static void _printRow(StringBuffer buffer, List<String> row, List<int> widths) {
    for (var i = 0; i < widths.length; i++) {
      final text = i < row.length ? row[i] : '';
      buffer.write(text.padRight(widths[i]));
      if (i < widths.length - 1) buffer.write(' | ');
    }
    buffer.writeln();
  }
}

// ============================================================================
// WORKMANAGER BACKUP TASK
// ============================================================================

class BackupWorkManager {
  BackupWorkManager._();

  static const String _backupTaskName = 'event_countdown_monthly_backup';
  static const String _backupTaskTag = 'monthly_auto_backup';

  /// Initialize Workmanager with the backup callback
  static void initialize() {
    Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Register the monthly backup task
  static Future<void> registerMonthlyBackup() async {
    await Workmanager().registerPeriodicTask(
      _backupTaskName,
      _backupTaskName,
      tag: _backupTaskTag,
      frequency: const Duration(days: 30), // Approximate monthly
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Cancel the monthly backup task
  static Future<void> cancelMonthlyBackup() async {
    await Workmanager().cancelByTag(_backupTaskTag);
  }

  /// Check if monthly backup is scheduled
  static Future<bool> isMonthlyBackupScheduled() async {
    // Workmanager doesn't expose a direct "is scheduled" API,
    // so we track this via SharedPreferences in the app layer.
    // This method is a placeholder for that check.
    return false;
  }

  /// The callback dispatcher that runs in the background
  @pragma('vm:entry-point')
  static void _callbackDispatcher() {
    Workmanager().executeTask((taskName, inputData) async {
      try {
        if (taskName == _backupTaskName) {
          final path = await ExportImportService.exportAllData();
          if (kDebugMode) {
            debugPrint('Monthly auto-backup completed: $path');
          }
          return Future.value(true);
        }
        return Future.value(true);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Monthly auto-backup failed: $e');
          debugPrint(stackTrace.toString());
        }
        return Future.value(false);
      }
    });
  }
}

// ============================================================================
// MAIN EXPORT/IMPORT SERVICE
// ============================================================================

class ExportImportService {
  ExportImportService._();

  static const String _kAppVersion = '1.0.0';
  static const String _kAppName = 'event_countdown';

  // ==================== ZIP HELPERS ====================

  static String _computeChecksum(String dataJsonString) {
    final bytes = utf8.encode(dataJsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<String> _writeZipFile({
    required String exportType,
    required String dataJsonString,
    required String fileName,
  }) async {
    final manifest = {
      'exportVersion': 2,
      'appName': _kAppName,
      'appVersion': _kAppVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exportType': exportType,
      'checksum': _computeChecksum(dataJsonString),
    };

    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);
    final manifestBytes = utf8.encode(manifestJson);
    final dataBytes = utf8.encode(dataJsonString);

    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes)
        ..compressionLevel = 6)
      ..addFile(ArchiveFile('data.json', dataBytes.length, dataBytes)
        ..compressionLevel = 6);

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    if (encoded == null) {
      throw Exception('Failed to encode ZIP archive');
    }

    final dir = await getApplicationDocumentsDirectory();
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsBytes(encoded);

    return appFile.path;
  }

  static Future<Map<String, dynamic>> _readZipFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? manifestFile;
    ArchiveFile? dataFile;

    for (final entry in archive) {
      if (entry.name == 'manifest.json') {
        manifestFile = entry;
      } else if (entry.name == 'data.json') {
        dataFile = entry;
      }
    }

    if (manifestFile == null) {
      throw Exception('Corrupted backup: manifest.json missing');
    }
    if (dataFile == null) {
      throw Exception('Corrupted backup: data.json missing');
    }

    final manifestString = utf8.decode(manifestFile.content as List<int>);
    final dataString = utf8.decode(dataFile.content as List<int>);

    final manifest = jsonDecode(manifestString) as Map<String, dynamic>;

    final exportVersion = manifest['exportVersion'];
    if (exportVersion == null) {
      throw Exception('Corrupted backup: exportVersion missing from manifest');
    }
    if (exportVersion != 2) {
      throw Exception('Unsupported export version: $exportVersion');
    }

    final checksum = manifest['checksum'];
    if (checksum == null) {
      throw Exception('Corrupted backup: checksum missing from manifest');
    }

    final computed = _computeChecksum(dataString);
    if (computed != checksum) {
      throw Exception(
          'Corrupted backup (checksum mismatch). The file may have been tampered with or is incomplete.');
    }

    final exportType = manifest['exportType'];
    if (exportType == null) {
      throw Exception('Corrupted backup: exportType missing from manifest');
    }

    return {
      'exportType': exportType,
      'data': jsonDecode(dataString),
    };
  }

  static bool _isZipFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return ext == '.zip' || ext == '.ecbackup';
  }

  // ==================== INTERNAL EXPORT ====================

  static Future<String> exportToJson() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'event_countdown_export_$timestamp.ecbackup';

    return _writeZipFile(
      exportType: 'events',
      dataJsonString: jsonString,
      fileName: fileName,
    );
  }

  static Future<String> exportAllData() async {
    final allData = await DatabaseHelper.instance.exportAllTables();

    final exportMap = {
      'exportVersion': 1,
      'appName': _kAppName,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': allData,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'event_countdown_full_export_$timestamp.ecbackup';

    return _writeZipFile(
      exportType: 'full',
      dataJsonString: jsonString,
      fileName: fileName,
    );
  }

  // ==================== SHARE EXPORT ====================

  static Future<void> exportAndShareEvents() async {
    final path = await exportToJson();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Event Countdown Export',
      text: 'Here is my Event Countdown export file.',
    );
  }

  static Future<void> exportAndShareAllData() async {
    final path = await exportAllData();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Event Countdown Full Export',
      text: 'Here is my complete Event Countdown data export.',
    );
  }

  static Future<void> shareExport() => exportAndShareEvents();
  static Future<void> shareFullExport() => exportAndShareAllData();

  // ==================== SAVE TO DEVICE ====================

  static Future<String?> saveExportToDevice() async {
    final exportPath = await exportToJson();
    final fileName = p.basename(exportPath);

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Event Export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['ecbackup'],
    );

    if (outputPath == null) return null;

    final fileBytes = await File(exportPath).readAsBytes();
    await File(outputPath).writeAsBytes(fileBytes);
    return outputPath;
  }

  static Future<String?> saveFullExportToDevice() async {
    final exportPath = await exportAllData();
    final fileName = p.basename(exportPath);

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Full Export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['ecbackup'],
    );

    if (outputPath == null) return null;

    final fileBytes = await File(exportPath).readAsBytes();
    await File(outputPath).writeAsBytes(fileBytes);
    return outputPath;
  }

  // ==================== IMPORT ====================

  static Future<int> importFromJson(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    List<dynamic> eventList;

    if (_isZipFile(filePath)) {
      // New .ecbackup / .zip format
      final zipData = await _readZipFile(filePath);
      final exportType = zipData['exportType'] as String;
      final data = zipData['data'];

      if (exportType != 'events') {
        throw Exception(
            'This backup is a full data export. Please use "Import All Data" instead.');
      }

      if (data is List) {
        eventList = data;
      } else if (data is Map && data['tables'] != null && data['tables']['events'] != null) {
        eventList = data['tables']['events'] as List;
      } else {
        throw Exception(
            'Invalid data format: expected a list of events inside the backup');
      }
    } else {
      // Legacy .json format — backward compatibility
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        throw Exception('File is empty');
      }

      final decoded = jsonDecode(contents);
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

      if (kDebugMode) {
        debugPrint('Importing legacy .json file (deprecated format)');
      }
    }

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

    final backup = await DatabaseHelper.instance.getAllEventsSorted();

    try {
      await DatabaseHelper.instance.replaceAllEvents(events);
    } catch (e) {
      await DatabaseHelper.instance.replaceAllEvents(backup);
      throw Exception(
          'Import failed. Database restored from backup. Error: $e');
    }

    return events.length;
  }

  static Future<void> importAllData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    late final Map<String, dynamic> decoded;

    if (_isZipFile(filePath)) {
      // New .ecbackup / .zip format
      final zipData = await _readZipFile(filePath);
      final exportType = zipData['exportType'] as String;
      final rawData = zipData['data'];

      if (exportType != 'full') {
        throw Exception(
            'This backup is an events-only export. Please use "Import Events" instead.');
      }

      if (rawData is! Map) {
        throw Exception('Invalid export format: expected a map inside .ecbackup');
      }
      decoded = rawData.cast<String, dynamic>();
    } else {
      // Legacy .json format — backward compatibility
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        throw Exception('File is empty');
      }

      final raw = jsonDecode(contents);
      if (raw is! Map) {
        throw Exception('Invalid export format: expected a map');
      }
      decoded = raw.cast<String, dynamic>();

      if (kDebugMode) {
        debugPrint('Importing legacy .json file (deprecated format)');
      }
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

    final backup = await DatabaseHelper.instance.exportAllTables();

    try {
      await DatabaseHelper.instance.importAllTables(typedTables);
    } catch (e) {
      await DatabaseHelper.instance.importAllTables(backup);
      throw Exception(
          'Import failed. Database restored from backup. Error: $e');
    }
  }

  static Future<int> importEventsFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ecbackup', 'json'],
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

  static Future<void> importAllDataFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ecbackup', 'json'],
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

  // ==================== ATTENDANCE CSV EXPORT ====================

  /// Export attendance records to CSV file
  static Future<String> exportAttendanceToCsv(List<AttendanceRecord> records) async {
    final rows = <List<String>>[
      AttendanceRecord.csvHeaders,
      ...records.map((r) => r.toCsvRow()),
    ];
    final csvContent = _CsvHelper.encode(rows);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'attendance_report_$timestamp.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent, encoding: utf8);
    return file.path;
  }

  /// Export attendance from database and share via system share sheet
  static Future<void> exportAndShareAttendance(List<AttendanceRecord> records) async {
    final path = await exportAttendanceToCsv(records);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/csv')],
      subject: 'Attendance Report',
      text: 'Here is the attendance report.',
    );
  }

  /// Save attendance CSV to device via file picker
  static Future<String?> saveAttendanceToDevice(List<AttendanceRecord> records) async {
    final exportPath = await exportAttendanceToCsv(records);
    final fileName = p.basename(exportPath);

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Attendance Report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputPath == null) return null;

    final fileBytes = await File(exportPath).readAsBytes();
    await File(outputPath).writeAsBytes(fileBytes);
    return outputPath;
  }

  // ==================== TIMETABLE CSV EXPORT ====================

  /// Export timetable entries to CSV file
  static Future<String> exportTimetableToCsv(List<TimetableEntry> entries) async {
    final rows = <List<String>>[
      TimetableEntry.csvHeaders,
      ...entries.map((e) => e.toCsvRow()),
    ];
    final csvContent = _CsvHelper.encode(rows);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'timetable_export_$timestamp.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent, encoding: utf8);
    return file.path;
  }

  /// Export timetable from database and share via system share sheet
  static Future<void> exportAndShareTimetable(List<TimetableEntry> entries) async {
    final path = await exportTimetableToCsv(entries);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/csv')],
      subject: 'Timetable Export',
      text: 'Here is the timetable export.',
    );
  }

  /// Save timetable CSV to device via file picker
  static Future<String?> saveTimetableToDevice(List<TimetableEntry> entries) async {
    final exportPath = await exportTimetableToCsv(entries);
    final fileName = p.basename(exportPath);

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Timetable',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputPath == null) return null;

    final fileBytes = await File(exportPath).readAsBytes();
    await File(outputPath).writeAsBytes(fileBytes);
    return outputPath;
  }

  // ==================== PDF PLACEHOLDER EXPORT ====================

  /// Generate a text-based PDF placeholder report for attendance
  static Future<String> exportAttendanceToPdfPlaceholder(List<AttendanceRecord> records) async {
    return PdfPlaceholderService.generateTextReport(
      title: 'ATTENDANCE REPORT',
      subtitle: 'Event Countdown App',
      headers: AttendanceRecord.csvHeaders,
      rows: records.map((r) => r.toCsvRow()).toList(),
    );
  }

  /// Generate a text-based PDF placeholder report for timetable
  static Future<String> exportTimetableToPdfPlaceholder(List<TimetableEntry> entries) async {
    return PdfPlaceholderService.generateTextReport(
      title: 'TIMETABLE REPORT',
      subtitle: 'Event Countdown App',
      headers: TimetableEntry.csvHeaders,
      rows: entries.map((e) => e.toCsvRow()).toList(),
    );
  }

  /// Share attendance PDF placeholder via system share sheet
  static Future<void> shareAttendancePdfPlaceholder(List<AttendanceRecord> records) async {
    final path = await exportAttendanceToPdfPlaceholder(records);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/plain')],
      subject: 'Attendance Report (PDF Placeholder)',
      text: 'Here is the attendance report (text-based PDF placeholder).',
    );
  }

  /// Share timetable PDF placeholder via system share sheet
  static Future<void> shareTimetablePdfPlaceholder(List<TimetableEntry> entries) async {
    final path = await exportTimetableToPdfPlaceholder(entries);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/plain')],
      subject: 'Timetable Report (PDF Placeholder)',
      text: 'Here is the timetable report (text-based PDF placeholder).',
    );
  }

  // ==================== CSV IMPORT (BULK ENTRY) ====================

  /// Import attendance records from a CSV file
  static Future<List<AttendanceRecord>> importAttendanceFromCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final contents = await file.readAsString(encoding: utf8);
    if (contents.trim().isEmpty) {
      throw Exception('File is empty');
    }

    final rows = _CsvHelper.decode(contents);
    if (rows.isEmpty) {
      throw Exception('CSV file has no data rows');
    }

    // Skip header row if it matches expected headers
    var startIndex = 0;
    final firstRow = rows.first.map((c) => c.toLowerCase().trim()).toList();
    final expectedHeaders = AttendanceRecord.csvHeaders.map((h) => h.toLowerCase()).toList();
    if (_rowsMatchHeaders(firstRow, expectedHeaders)) {
      startIndex = 1;
    }

    final records = <AttendanceRecord>[];
    for (var i = startIndex; i < rows.length; i++) {
      try {
        final record = AttendanceRecord.fromCsvRow(rows[i]);
        records.add(record);
      } catch (e) {
        throw Exception('Error parsing attendance row ${i + 1}: $e');
      }
    }

    return records;
  }

  /// Import timetable entries from a CSV file
  static Future<List<TimetableEntry>> importTimetableFromCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final contents = await file.readAsString(encoding: utf8);
    if (contents.trim().isEmpty) {
      throw Exception('File is empty');
    }

    final rows = _CsvHelper.decode(contents);
    if (rows.isEmpty) {
      throw Exception('CSV file has no data rows');
    }

    // Skip header row if it matches expected headers
    var startIndex = 0;
    final firstRow = rows.first.map((c) => c.toLowerCase().trim()).toList();
    final expectedHeaders = TimetableEntry.csvHeaders.map((h) => h.toLowerCase()).toList();
    if (_rowsMatchHeaders(firstRow, expectedHeaders)) {
      startIndex = 1;
    }

    final entries = <TimetableEntry>[];
    for (var i = startIndex; i < rows.length; i++) {
      try {
        final entry = TimetableEntry.fromCsvRow(rows[i]);
        entries.add(entry);
      } catch (e) {
        throw Exception('Error parsing timetable row ${i + 1}: $e');
      }
    }

    return entries;
  }

  /// Pick and import attendance CSV from file picker
  static Future<List<AttendanceRecord>> importAttendanceFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
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

    return importAttendanceFromCsv(path);
  }

  /// Pick and import timetable CSV from file picker
  static Future<List<TimetableEntry>> importTimetableFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
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

    return importTimetableFromCsv(path);
  }

  static bool _rowsMatchHeaders(List<String> row, List<String> headers) {
    if (row.length < headers.length) return false;
    for (var i = 0; i < headers.length; i++) {
      if (row[i] != headers[i]) return false;
    }
    return true;
  }

  // ==================== MONTHLY AUTO-BACKUP ====================

  /// Trigger a manual backup (can be called from UI or Workmanager)
  static Future<String> triggerAutoBackup() async {
    return exportAllData();
  }

  /// Initialize the monthly auto-backup system
  static Future<void> initializeMonthlyAutoBackup() async {
    BackupWorkManager.initialize();
    await BackupWorkManager.registerMonthlyBackup();
  }

  /// Cancel monthly auto-backup
  static Future<void> cancelMonthlyAutoBackup() async {
    await BackupWorkManager.cancelMonthlyBackup();
  }
}
