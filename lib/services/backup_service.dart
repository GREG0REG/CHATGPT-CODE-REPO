import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../database_helper.dart';
import '../models/event.dart';

const String kBackupTaskName = 'event_countdown_weekly_backup';

class BackupService {
  BackupService._();

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
    } catch (e) {
      return false;
    }
  }

  static Future<String?> findRecentBackup() async {
    try {
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
    } catch (e) {}
    return null;
  }

  static Future<String> createNamedBackup() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final jsonList = events.map((e) => e.toJson()).toList();
    final jsonString = JsonEncoder.withIndent('  ').convert(jsonList);

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'event_countdown_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final appFile = File('${dir.path}/$fileName');
    await appFile.writeAsString(jsonString);

    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (downloadsDir.existsSync()) {
        await appFile.copy('${downloadsDir.path}/$fileName');
      }
    } catch (e) {}

    return appFile.path;
  }
}
