import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';

import '../db/database_helper.dart';
import '../models/event.dart';

const String kBackupTaskName = 'event_countdown_weekly_backup';

class BackupService {
  BackupService._();

  static const String _kAppVersion = '1.0.0';
  static const String _kAppName = 'event_countdown';

  static Future<void> registerWeeklyBackup() async {
    await Workmanager().registerPeriodicTask(
      kBackupTaskName,
      kBackupTaskName,
      frequency: const Duration(days: 7),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  static Future<bool> executeBackup() async {
    try {
      final path = await createNamedBackup();
      return path.isNotEmpty;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('executeBackup error: $e');
        debugPrint(stackTrace.toString());
      }
      return false;
    }
  }

  static Future<String?> findRecentBackup() async {
    try {
      // Look for new .ecbackup files first
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        final ecFiles = downloadsDir
            .listSync()
            .whereType<File>()
            .where((f) =>
                f.path.contains('event_countdown_backup_') &&
                p.extension(f.path).toLowerCase() == '.ecbackup')
            .toList();
        if (ecFiles.isNotEmpty) {
          ecFiles.sort((a, b) => b.path.compareTo(a.path));
          return ecFiles.first.path;
        }

        // Fall back to legacy .json files
        final jsonFiles = downloadsDir
            .listSync()
            .whereType<File>()
            .where((f) =>
                f.path.contains('event_countdown_backup_') &&
                p.extension(f.path).toLowerCase() == '.json')
            .toList();
        if (jsonFiles.isNotEmpty) {
          jsonFiles.sort((a, b) => b.path.compareTo(a.path));
          return jsonFiles.first.path;
        }
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final ecFiles = docsDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.contains('event_countdown_backup_') &&
              p.extension(f.path).toLowerCase() == '.ecbackup')
          .toList();
      if (ecFiles.isNotEmpty) {
        ecFiles.sort((a, b) => b.path.compareTo(a.path));
        return ecFiles.first.path;
      }

      // Fall back to legacy .json files
      final jsonFiles = docsDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.contains('event_countdown_backup_') &&
              p.extension(f.path).toLowerCase() == '.json')
          .toList();
      if (jsonFiles.isNotEmpty) {
        jsonFiles.sort((a, b) => b.path.compareTo(a.path));
        return jsonFiles.first.path;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('findRecentBackup error: $e');
        debugPrint(stackTrace.toString());
      }
    }
    return null;
  }

  static String _computeChecksum(String dataJsonString) {
    final bytes = utf8.encode(dataJsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<String> createNamedBackup() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final manifest = {
      'exportVersion': 2,
      'appName': _kAppName,
      'appVersion': _kAppVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exportType': 'events',
      'checksum': _computeChecksum(jsonString),
      'eventCount': events.length,
    };

    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);
    final manifestBytes = utf8.encode(manifestJson);
    final dataBytes = utf8.encode(jsonString);

    final archive = Archive()
      ..addFile(ArchiveFile(
        'manifest.json',
        manifestBytes.length,
        manifestBytes,
      ))
      ..addFile(ArchiveFile(
        'data.json',
        dataBytes.length,
        dataBytes,
      ));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    if (encoded == null) {
      throw Exception('Failed to encode backup ZIP archive');
    }

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'event_countdown_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.ecbackup';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsBytes(encoded);

    // Verify file was written
    if (!await appFile.exists()) {
      throw Exception('Failed to write backup file');
    }
    final fileSize = await appFile.length();
    if (fileSize == 0) {
      throw Exception('Backup file was written but has 0 bytes');
    }

    // Try to copy to Downloads for easy access
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        await appFile.copy('${downloadsDir.path}/$fileName');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Could not copy to Downloads: $e');
    }

    return appFile.path;
  }

  /// Create a full database backup (all tables) with timestamp
  static Future<String> createFullBackup() async {
    final allData = await DatabaseHelper.instance.exportAllTables();

    final exportMap = {
      'exportVersion': 1,
      'appName': _kAppName,
      'appVersion': _kAppVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': allData,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);

    final manifest = {
      'exportVersion': 2,
      'appName': _kAppName,
      'appVersion': _kAppVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exportType': 'full',
      'checksum': _computeChecksum(jsonString),
      'tableCount': allData.length,
      'totalRows': allData.values.fold<int>(0, (sum, rows) => sum + rows.length),
    };

    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);
    final manifestBytes = utf8.encode(manifestJson);
    final dataBytes = utf8.encode(jsonString);

    final archive = Archive()
      ..addFile(ArchiveFile(
        'manifest.json',
        manifestBytes.length,
        manifestBytes,
      ))
      ..addFile(ArchiveFile(
        'data.json',
        dataBytes.length,
        dataBytes,
      ));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    if (encoded == null) {
      throw Exception('Failed to encode full backup ZIP archive');
    }

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'event_countdown_full_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.ecbackup';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsBytes(encoded);

    // Verify file was written
    if (!await appFile.exists()) {
      throw Exception('Failed to write full backup file');
    }
    final fileSize = await appFile.length();
    if (fileSize == 0) {
      throw Exception('Full backup file was written but has 0 bytes');
    }

    // Try to copy to Downloads
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        await appFile.copy('${downloadsDir.path}/$fileName');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Could not copy full backup to Downloads: $e');
    }

    return appFile.path;
  }
}
