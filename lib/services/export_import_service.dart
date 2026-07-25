import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../database_helper.dart';
import '../models/event.dart';

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
      throw Exception('Corrupted backup (checksum mismatch). The file may have been tampered with or is incomplete.');
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
}
