 == null) {
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
      'manifest': manifest,
    };
  }

  static bool _isZipFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return ext == '.zip' || ext == '.ecbackup';
  }

  // ==================== INTERNAL EXPORT ====================

  /// Export only events to a ZIP .ecbackup file
  static Future<ExportResult> exportToJson() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final jsonList = events.map((e) => e.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'event_countdown_export_\$timestamp.ecbackup';

      final path = await _writeZipFile(
        exportType: 'events',
        dataJsonString: jsonString,
        fileName: fileName,
      );

      final file = File(path);
      final fileSize = await file.length();

      return ExportResult(
        success: true,
        filePath: path,
        eventCount: events.length,
        totalTableCount: 1,
        fileSizeBytes: fileSize,
        exportedAt: DateTime.now(),
        exportType: 'events',
        checksum: _computeChecksum(jsonString),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('exportToJson error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        errorMessage: 'Export failed: \$e',
        exportedAt: DateTime.now(),
        exportType: 'events',
      );
    }
  }

  /// Export ALL database tables to a ZIP .ecbackup file
  static Future<ExportResult> exportAllData() async {
    try {
      final allData = await DatabaseHelper.instance.exportAllTables();

      // Count events for metadata
      final eventCount = (allData['events'] ?? []).length;
      final totalRows = allData.values.fold<int>(0, (sum, rows) => sum + rows.length);

      final exportMap = {
        'exportVersion': 1,
        'appName': _kAppName,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'tables': allData,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'event_countdown_full_export_\$timestamp.ecbackup';

      final path = await _writeZipFile(
        exportType: 'full',
        dataJsonString: jsonString,
        fileName: fileName,
      );

      final file = File(path);
      final fileSize = await file.length();

      return ExportResult(
        success: true,
        filePath: path,
        eventCount: eventCount,
        totalTableCount: allData.length,
        fileSizeBytes: fileSize,
        exportedAt: DateTime.now(),
        exportType: 'full',
        checksum: _computeChecksum(jsonString),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('exportAllData error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        errorMessage: 'Full export failed: \$e',
        exportedAt: DateTime.now(),
        exportType: 'full',
      );
    }
  }

  // ==================== ENHANCED: EXPORT AS PLAIN JSON ====================

  /// Export events as a human-readable .json file (no ZIP, for advanced users)
  static Future<ExportResult> exportEventsAsPlainJson() async {
    try {
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      final jsonList = events.map((e) => e.toJson()).toList();

      final exportMap = {
        'appName': _kAppName,
        'appVersion': _kAppVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'eventCount': events.length,
        'events': jsonList,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'event_countdown_export_\$timestamp.json';
      final file = File('\${dir.path}/\$fileName');
      await file.writeAsString(jsonString, encoding: utf8);

      final fileSize = await file.length();

      return ExportResult(
        success: true,
        filePath: file.path,
        eventCount: events.length,
        totalTableCount: 1,
        fileSizeBytes: fileSize,
        exportedAt: DateTime.now(),
        exportType: 'events_plain_json',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('exportEventsAsPlainJson error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        errorMessage: 'Plain JSON export failed: \$e',
        exportedAt: DateTime.now(),
        exportType: 'events_plain_json',
      );
    }
  }

  // ==================== SHARE EXPORT (CRASH-FIXED) ====================

  /// Safely share events export with proper error handling
  static Future<ExportResult> exportAndShareEvents() async {
    final result = await exportToJson();
    if (!result.success || result.filePath == null) {
      return result;
    }

    try {
      final xFile = XFile(
        result.filePath!,
        mimeType: 'application/octet-stream',
        name: p.basename(result.filePath!),
      );

      await Share.shareXFiles(
        [xFile],
        subject: 'Event Countdown Export',
        text: 'Here is my Event Countdown export file.',
      );

      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('exportAndShareEvents error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        filePath: result.filePath,
        errorMessage: 'Sharing failed: \$e\n\nThe file was saved at: \${result.filePath}',
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: result.fileSizeBytes,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    }
  }

  /// Safely share full data export with proper error handling
  static Future<ExportResult> exportAndShareAllData() async {
    final result = await exportAllData();
    if (!result.success || result.filePath == null) {
      return result;
    }

    try {
      final xFile = XFile(
        result.filePath!,
        mimeType: 'application/octet-stream',
        name: p.basename(result.filePath!),
      );

      await Share.shareXFiles(
        [xFile],
        subject: 'Event Countdown Full Export',
        text: 'Here is my complete Event Countdown data export.',
      );

      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('exportAndShareAllData error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        filePath: result.filePath,
        errorMessage: 'Sharing failed: \$e\n\nThe file was saved at: \${result.filePath}',
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: result.fileSizeBytes,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    }
  }

  /// Legacy alias for backward compatibility
  static Future<ExportResult> shareExport() => exportAndShareEvents();
  static Future<ExportResult> shareFullExport() => exportAndShareAllData();

  // ==================== SAVE TO DEVICE (CRASH-FIXED) ====================

  /// Save events export to device with file picker
  static Future<ExportResult> saveExportToDevice() async {
    final result = await exportToJson();
    if (!result.success || result.filePath == null) {
      return result;
    }

    try {
      final fileName = p.basename(result.filePath!);

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Event Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['ecbackup'],
      );

      if (outputPath == null) {
        return ExportResult(
          success: false,
          filePath: result.filePath,
          errorMessage: 'Save cancelled by user',
          eventCount: result.eventCount,
          totalTableCount: result.totalTableCount,
          fileSizeBytes: result.fileSizeBytes,
          exportedAt: result.exportedAt,
          exportType: result.exportType,
          checksum: result.checksum,
        );
      }

      final fileBytes = await File(result.filePath!).readAsBytes();
      await File(outputPath).writeAsBytes(fileBytes);

      return ExportResult(
        success: true,
        filePath: outputPath,
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: fileBytes.length,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('saveExportToDevice error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        filePath: result.filePath,
        errorMessage: 'Save to device failed: \$e',
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: result.fileSizeBytes,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    }
  }

  /// Save full export to device with file picker
  static Future<ExportResult> saveFullExportToDevice() async {
    final result = await exportAllData();
    if (!result.success || result.filePath == null) {
      return result;
    }

    try {
      final fileName = p.basename(result.filePath!);

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Full Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['ecbackup'],
      );

      if (outputPath == null) {
        return ExportResult(
          success: false,
          filePath: result.filePath,
          errorMessage: 'Save cancelled by user',
          eventCount: result.eventCount,
          totalTableCount: result.totalTableCount,
          fileSizeBytes: result.fileSizeBytes,
          exportedAt: result.exportedAt,
          exportType: result.exportType,
          checksum: result.checksum,
        );
      }

      final fileBytes = await File(result.filePath!).readAsBytes();
      await File(outputPath).writeAsBytes(fileBytes);

      return ExportResult(
        success: true,
        filePath: outputPath,
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: fileBytes.length,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('saveFullExportToDevice error: \$e');
        debugPrint(stackTrace.toString());
      }
      return ExportResult(
        success: false,
        filePath: result.filePath,
        errorMessage: 'Save to device failed: \$e',
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: result.fileSizeBytes,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    }
  }

  // ==================== ENHANCED: SAVE TO DOWNLOADS ====================

  /// Copy a file to the Downloads folder (Android) or Documents (iOS)
  static Future<String?> _copyToDownloads(String sourcePath) async {
    if (Platform.isAndroid) {
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final fileName = p.basename(sourcePath);
          final destPath = '\${downloadsDir.path}/\$fileName';
          await File(sourcePath).copy(destPath);
          return destPath;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Could not copy to Downloads: \$e');
      }
    }
    return null;
  }

  /// Export and auto-save to Downloads folder
  static Future<ExportResult> exportAndSaveToDownloads() async {
    final result = await exportToJson();
    if (!result.success || result.filePath == null) {
      return result;
    }

    final downloadPath = await _copyToDownloads(result.filePath!);
    if (downloadPath != null) {
      return ExportResult(
        success: true,
        filePath: downloadPath,
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: result.fileSizeBytes,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    }

    return result;
  }

  /// Full export and auto-save to Downloads folder
  static Future<ExportResult> exportAllAndSaveToDownloads() async {
    final result = await exportAllData();
    if (!result.success || result.filePath == null) {
      return result;
    }

    final downloadPath = await _copyToDownloads(result.filePath!);
    if (downloadPath != null) {
      return ExportResult(
        success: true,
        filePath: downloadPath,
        eventCount: result.eventCount,
        totalTableCount: result.totalTableCount,
        fileSizeBytes: result.fileSizeBytes,
        exportedAt: result.exportedAt,
        exportType: result.exportType,
        checksum: result.checksum,
      );
    }

    return result;
  }

  // ==================== IMPORT PREVIEW (NEW) ====================

  /// Preview an import file without actually importing
  static Future<ImportPreview> previewImportFile(String filePath) async {
    final warnings = <String>[];

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: \$filePath');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty (0 bytes)');
      }

      late final Map<String, dynamic> decoded;
      String? exportType;
      String? checksum;
      bool checksumValid = false;

      if (_isZipFile(filePath)) {
        final zipData = await _readZipFile(filePath);
        exportType = zipData['exportType'] as String?;
        final manifest = zipData['manifest'] as Map<String, dynamic>?;
        checksum = manifest?['checksum'] as String?;
        decoded = zipData['data'] as Map<String, dynamic>;
      } else {
        final contents = await file.readAsString();
        if (contents.trim().isEmpty) {
          throw Exception('File is empty');
        }
        decoded = jsonDecode(contents) as Map<String, dynamic>;
        exportType = decoded['exportType'] as String?;
        if (exportType == null && decoded.containsKey('events')) {
          exportType = 'events';
        }
      }

      final appVersion = _safeString(decoded['appVersion'], 'unknown');
      final exportedAt = _safeDateTimeParse(decoded['exportedAt']);

      final tableRowCounts = <String, int>{};
      int totalRows = 0;

      if (decoded.containsKey('tables')) {
        final tables = decoded['tables'] as Map<String, dynamic>?;
        if (tables != null) {
          for (final entry in tables.entries) {
            final rows = entry.value;
            if (rows is List) {
              tableRowCounts[entry.key] = rows.length;
              totalRows += rows.length;
            }
          }
        }
      } else if (decoded.containsKey('events')) {
        final events = decoded['events'];
        if (events is List) {
          tableRowCounts['events'] = events.length;
          totalRows = events.length;
        }
      }

      // Validate checksum if available
      if (checksum != null) {
        try {
          final dataStr = jsonEncode(decoded);
          checksumValid = _computeChecksum(dataStr) == checksum;
        } catch (_) {
          checksumValid = false;
        }
      }

      // Check for potential issues
      if (!checksumValid && checksum != null) {
        warnings.add('Checksum mismatch - file may be corrupted');
      }
      if (tableRowCounts.isEmpty) {
        warnings.add('No data tables found in file');
      }
      if (decoded['exportVersion'] != null && decoded['exportVersion'] != 1 && decoded['exportVersion'] != 2) {
        warnings.add('Unknown export version: \${decoded['exportVersion']}');
      }

      return ImportPreview(
        exportType: exportType ?? 'unknown',
        appVersion: appVersion,
        exportedAt: exportedAt,
        tableRowCounts: tableRowCounts,
        totalRows: totalRows,
        checksum: checksum,
        checksumValid: checksumValid,
        warnings: warnings,
      );
    } catch (e) {
      return ImportPreview(
        exportType: 'error',
        appVersion: 'unknown',
        exportedAt: DateTime.now(),
        tableRowCounts: {},
        totalRows: 0,
        checksumValid: false,
        warnings: ['Error reading file: \$e'],
      );
    }
  }

  // ==================== IMPORT (CRASH-FIXED & ENHANCED) ====================

  /// Import events from a file with full error handling
  static Future<int> importFromJson(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: \$filePath');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('File is empty (0 bytes): \$filePath');
    }

    List<dynamic> eventList;

    if (_isZipFile(filePath)) {
      // New .ecbackup / .zip format
      final zipData = await _readZipFile(filePath);
      final exportType = zipData['exportType'] as String?;
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
      } else if (decoded is Map && decoded['events'] != null) {
        eventList = decoded['events'] as List;
      } else {
        throw Exception(
            'Invalid JSON format: expected a list of events or a comprehensive export');
      }

      if (kDebugMode) {
        debugPrint('Importing legacy .json file (deprecated format)');
      }
    }

    final events = <Event>[];
    final errors = <String>[];

    for (var i = 0; i < eventList.length; i++) {
      final item = eventList[i];
      if (item is! Map) {
        errors.add('Index \$i: expected a map, got \${item.runtimeType}');
        continue;
      }
      try {
        final event = Event.fromJson(Map<String, dynamic>.from(item));
        events.add(event);
      } catch (e) {
        errors.add('Index \$i: \$e');
      }
    }

    if (errors.isNotEmpty && events.isEmpty) {
      throw FormatException('All \${eventList.length} events failed to parse: \n\${errors.take(5).join('\n')}');
    }

    if (events.isEmpty) {
      throw Exception('No valid events found in file');
    }

    // Create backup before import
    List<Event> backup;
    try {
      backup = await DatabaseHelper.instance.getAllEventsSorted();
    } catch (e) {
      backup = [];
      if (kDebugMode) debugPrint('Could not create backup before import: \$e');
    }

    try {
      await DatabaseHelper.instance.replaceAllEvents(events);
    } catch (e) {
      // Restore backup
      if (backup.isNotEmpty) {
        try {
          await DatabaseHelper.instance.replaceAllEvents(backup);
        } catch (restoreError) {
          throw Exception(
              'Import failed AND backup restore failed. Database may be in an inconsistent state. Error: \$restoreError');
        }
      }
      throw Exception(
          'Import failed. Database restored from backup. Error: \$e');
    }

    return events.length;
  }

  /// Import all data from a file with full error handling
  static Future<void> importAllData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: \$filePath');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('File is empty (0 bytes): \$filePath');
    }

    late final Map<String, dynamic> decoded;

    if (_isZipFile(filePath)) {
      // New .ecbackup / .zip format
      final zipData = await _readZipFile(filePath);
      final exportType = zipData['exportType'] as String?;
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
      throw Exception('Unsupported export version: \$exportVersion');
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
            'Invalid data for table "\$key": expected a list, got \${value.runtimeType}');
      }
      typedTables[key] = value.cast<Map<String, dynamic>>();
    }

    // Validate events before importing
    if (typedTables.containsKey('events')) {
      final eventList = typedTables['events']!;
      final errors = <String>[];
      for (var i = 0; i < eventList.length; i++) {
        try {
          Event.fromJson(eventList[i]);
        } catch (e) {
          errors.add('Invalid event at index \$i: \$e');
        }
      }
      if (errors.isNotEmpty) {
        throw FormatException('Event validation failed:\n\${errors.take(10).join('\n')}');
      }
    }

    // Create backup before import
    Map<String, List<Map<String, dynamic>>> backup;
    try {
      backup = await DatabaseHelper.instance.exportAllTables();
    } catch (e) {
      backup = {};
      if (kDebugMode) debugPrint('Could not create backup before import: \$e');
    }

    try {
      await DatabaseHelper.instance.importAllTables(typedTables);
    } catch (e) {
      // Restore backup
      if (backup.isNotEmpty) {
        try {
          await DatabaseHelper.instance.importAllTables(backup);
        } catch (restoreError) {
          throw Exception(
              'Import failed AND backup restore failed. Database may be in an inconsistent state. Error: \$restoreError');
        }
      }
      throw Exception(
          'Import failed. Database restored from backup. Error: \$e');
    }
  }

  /// Pick and import events from file picker
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

  /// Pick and import all data from file picker
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
    final fileName = 'attendance_report_\$timestamp.csv';
    final file = File('\${dir.path}/\$fileName');
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
    final fileName = 'timetable_export_\$timestamp.csv';
    final file = File('\${dir.path}/\$fileName');
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
      throw Exception('File not found: \$filePath');
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
    final errors = <String>[];

    for (var i = startIndex; i < rows.length; i++) {
      try {
        final record = AttendanceRecord.fromCsvRow(rows[i]);
        records.add(record);
      } catch (e) {
        errors.add('Row \${i + 1}: \$e');
      }
    }

    if (errors.isNotEmpty && records.isEmpty) {
      throw FormatException('All rows failed to parse:\n\${errors.take(5).join('\n')}');
    }

    return records;
  }

  /// Import timetable entries from a CSV file
  static Future<List<TimetableEntry>> importTimetableFromCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: \$filePath');
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
    final errors = <String>[];

    for (var i = startIndex; i < rows.length; i++) {
      try {
        final entry = TimetableEntry.fromCsvRow(rows[i]);
        entries.add(entry);
      } catch (e) {
        errors.add('Row \${i + 1}: \$e');
      }
    }

    if (errors.isNotEmpty && entries.isEmpty) {
      throw FormatException('All rows failed to parse:\n\${errors.take(5).join('\n')}');
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
  static Future<ExportResult> triggerAutoBackup() async {
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
