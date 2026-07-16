import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../db/database_helper.dart';
import 'export_import_service.dart';

const String kBackupTaskName = 'event_countdown_weekly_backup';

/// Handles weekly auto-backup and restore checks.
class BackupService {
  BackupService._();

  /// Registers the weekly backup WorkManager task.
  static Future<void> registerWeeklyBackup() async {
    await Workmanager().registerPeriodicTask(
      kBackupTaskName,
      kBackupTaskName,
      frequency: const Duration(days: 7),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Executes the backup. Called by WorkManager background task.
  static Future<bool> executeBackup() async {
    try {
      final path = await ExportImportService.exportToJson();
      return path.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a backup file exists in Downloads or app docs.
  /// Returns the most recent backup file path, or null.
  static Future<String?> findRecentBackup() async {
    try {
      // Check Downloads first
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        final files = downloadsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('event_countdown_backup_'))
            .toList();
        if (files.isNotEmpty) {
          files.sort((a, b) => b.path.compareTo(a.path));
          return files.first.path;
        }
      }

      // Check app documents
      final docsDir = await getApplicationDocumentsDirectory();
      final files = docsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('event_countdown_backup_'))
          .toList();
      if (files.isNotEmpty) {
        files.sort((a, b) => b.path.compareTo(a.path));
        return files.first.path;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  /// Creates a backup with the naming convention event_countdown_backup_YYYYMMDD.json
  static Future<String> createNamedBackup() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'event_countdown_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsString(jsonString);

    // Try to copy to Downloads
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        await appFile.copy('${downloadsDir.path}/$fileName');
      }
    } catch (e) {
      // Fallback to app docs only
    }

    return appFile.path;
  }
}
