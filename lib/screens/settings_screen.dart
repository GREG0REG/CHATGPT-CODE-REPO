import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/export_import_service.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastMessage;
  bool _lastMessageIsError = false;

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _lastMessage = message;
      _lastMessageIsError = isError;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 4),
        action: isError
            ? null
            : SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
      ),
    );
  }

  Future<void> _handleExport(Future<ExportResult> Function() exportFn, String label) async {
    setState(() => _isExporting = true);
    try {
      final result = await exportFn();
      if (result.success) {
        _showMessage(
          '$label successful!\n'
          'Events: ${result.eventCount} | '
          'Size: ${result.fileSizeReadable}',
        );
      } else {
        _showMessage(result.errorMessage ?? '$label failed', isError: true);
      }
    } catch (e) {
      _showMessage('$label error: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport(Future<int> Function() importFn, String label) async {
    setState(() => _isImporting = true);
    try {
      final count = await importFn();
      _showMessage('$label successful! Imported $count events.');
    } catch (e) {
      _showMessage('$label failed: $e', isError: true);
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _previewAndImport() async {
    setState(() => _isImporting = true);
    try {
      // First pick the file
      final result = await ExportImportService.importEventsFromPicker();
      // If we get here, import was successful
      _showMessage('Import successful! Imported events.');
    } catch (e) {
      _showMessage('Import failed: $e', isError: true);
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _showExportPreview(Future<ExportResult> Function() exportFn, String title) async {
    setState(() => _isExporting = true);
    try {
      final result = await exportFn();
      if (!result.success) {
        _showMessage(result.errorMessage ?? 'Export failed', isError: true);
        setState(() => _isExporting = false);
        return;
      }

      if (!mounted) return;

      // Show preview dialog
      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Export Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreviewRow('Type', result.exportType.toUpperCase()),
              _buildPreviewRow('Events', '${result.eventCount}'),
              _buildPreviewRow('Tables', '${result.totalTableCount}'),
              _buildPreviewRow('Size', result.fileSizeReadable),
              _buildPreviewRow('Path', p.basename(result.filePath ?? 'Unknown')),
              if (result.checksum != null)
                _buildPreviewRow('Checksum', 'Verified'),
              const SizedBox(height: 12),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );

      if (shouldShare == true && result.filePath != null) {
        try {
          final xFile = XFile(
            result.filePath!,
            mimeType: 'application/octet-stream',
            name: p.basename(result.filePath!),
          );
          await Share.shareXFiles(
            [xFile],
            subject: 'StudyFlow Export',
            text: 'Here is my StudyFlow export file.',
          );
        } catch (e) {
          _showMessage('Sharing failed: $e', isError: true);
        }
      }
    } catch (e) {
      _showMessage('Export error: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Export Section
          _buildSectionHeader('Export Data'),
          _buildExportTile(
            icon: Icons.event_note,
            title: 'Export Events Only',
            subtitle: 'Share your events as .ecbackup file',
            onTap: () => _showExportPreview(
              () => ExportImportService.exportAndShareEvents(),
              'Events Export',
            ),
            isLoading: _isExporting,
          ),
          _buildExportTile(
            icon: Icons.backup,
            title: 'Export All Data',
            subtitle: 'Full backup including all tables',
            onTap: () => _showExportPreview(
              () => ExportImportService.exportAndShareAllData(),
              'Full Export',
            ),
            isLoading: _isExporting,
          ),
          _buildExportTile(
            icon: Icons.download,
            title: 'Save to Downloads',
            subtitle: 'Export events to Downloads folder',
            onTap: () => _handleExport(
              () => ExportImportService.exportAndSaveToDownloads(),
              'Save to Downloads',
            ),
            isLoading: _isExporting,
          ),
          _buildExportTile(
            icon: Icons.code,
            title: 'Export as Plain JSON',
            subtitle: 'Human-readable JSON format',
            onTap: () => _handleExport(
              () => ExportImportService.exportEventsAsPlainJson(),
              'Plain JSON Export',
            ),
            isLoading: _isExporting,
          ),
          _buildExportTile(
            icon: Icons.save_alt,
            title: 'Save Export to Device',
            subtitle: 'Choose where to save the .ecbackup file',
            onTap: () => _handleExport(
              () => ExportImportService.saveExportToDevice(),
              'Save to Device',
            ),
            isLoading: _isExporting,
          ),

          const Divider(),

          // Import Section
          _buildSectionHeader('Import Data'),
          _buildExportTile(
            icon: Icons.upload_file,
            title: 'Import Events',
            subtitle: 'Restore events from .ecbackup or .json',
            onTap: _previewAndImport,
            isLoading: _isImporting,
          ),
          _buildExportTile(
            icon: Icons.restore,
            title: 'Import All Data',
            subtitle: 'Restore full backup (replaces everything)',
            onTap: () async {
              setState(() => _isImporting = true);
              try {
                await ExportImportService.importAllDataFromPicker();
                _showMessage('Full import successful!');
              } catch (e) {
                _showMessage('Full import failed: $e', isError: true);
              } finally {
                setState(() => _isImporting = false);
              }
            },
            isLoading: _isImporting,
          ),

          const Divider(),

          // Backup Section
          _buildSectionHeader('Auto Backup'),
          _buildExportTile(
            icon: Icons.auto_fix_high,
            title: 'Create Backup Now',
            subtitle: 'Manual full database backup',
            onTap: () async {
              setState(() => _isExporting = true);
              try {
                final path = await BackupService.createFullBackup();
                _showMessage('Backup created: ${p.basename(path)}');
              } catch (e) {
                _showMessage('Backup failed: $e', isError: true);
              } finally {
                setState(() => _isExporting = false);
              }
            },
            isLoading: _isExporting,
          ),
          _buildExportTile(
            icon: Icons.find_in_page,
            title: 'Find Recent Backup',
            subtitle: 'Locate the most recent backup file',
            onTap: () async {
              final path = await BackupService.findRecentBackup();
              if (path != null) {
                _showMessage('Found: ${p.basename(path)}');
              } else {
                _showMessage('No recent backup found', isError: true);
              }
            },
          ),

          const Divider(),

          // Status
          if (_lastMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastMessageIsError
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastMessageIsError
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastMessageIsError ? Icons.error : Icons.info,
                      color: _lastMessageIsError
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastMessage!,
                        style: TextStyle(
                          color: _lastMessageIsError
                              ? Colors.red.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildExportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return ListTile(
      leading: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      enabled: !isLoading && !_isExporting && !_isImporting,
      onTap: onTap,
    );
  }
}
