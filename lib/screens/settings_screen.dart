import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:event_countdown/services/export_import_service.dart';
import 'package:event_countdown/services/backup_service.dart';

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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
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
      await ExportImportService.importEventsFromPicker();
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

      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
              ),
              const SizedBox(width: 12),
              const Text('Export Complete', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildPreviewRow('Type', result.exportType?.toUpperCase() ?? 'UNKNOWN'),
                    _buildPreviewRow('Events', '${result.eventCount ?? 0}'),
                    _buildPreviewRow('Tables', '${result.totalTableCount ?? 0}'),
                    _buildPreviewRow('Size', result.fileSizeReadable),
                    _buildPreviewRow('Path', p.basename(result.filePath ?? 'Unknown')),
                    if (result.checksum != null)
                      _buildPreviewRow('Checksum', 'Verified', isSuccess: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What would you like to do?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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

  Widget _buildPreviewRow(String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSuccess ? Colors.green.shade700 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSuccess)
                  Icon(Icons.verified, color: Colors.green.shade600, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Export Section
          _buildSectionHeader(
            icon: Icons.upload_rounded,
            title: 'Export Data',
            subtitle: 'Backup and share your events',
          ),
          _buildCard([
            _buildActionTile(
              icon: Icons.event_note,
              color: Colors.blue,
              title: 'Export Events Only',
              subtitle: 'Share your events as .ecbackup file',
              onTap: () => _showExportPreview(
                () => ExportImportService.exportAndShareEvents(),
                'Events Export',
              ),
              isLoading: _isExporting,
            ),
            const Divider(height: 1, indent: 56),
            _buildActionTile(
              icon: Icons.backup,
              color: Colors.indigo,
              title: 'Export All Data',
              subtitle: 'Full backup including all tables',
              onTap: () => _showExportPreview(
                () => ExportImportService.exportAndShareAllData(),
                'Full Export',
              ),
              isLoading: _isExporting,
            ),
            const Divider(height: 1, indent: 56),
            _buildActionTile(
              icon: Icons.download,
              color: Colors.teal,
              title: 'Save to Downloads',
              subtitle: 'Export events to Downloads folder',
              onTap: () => _handleExport(
                () => ExportImportService.exportAndSaveToDownloads(),
                'Save to Downloads',
              ),
              isLoading: _isExporting,
            ),
            const Divider(height: 1, indent: 56),
            _buildActionTile(
              icon: Icons.code,
              color: Colors.orange,
              title: 'Export as Plain JSON',
              subtitle: 'Human-readable JSON format',
              onTap: () => _handleExport(
                () => ExportImportService.exportEventsAsPlainJson(),
                'Plain JSON Export',
              ),
              isLoading: _isExporting,
            ),
            const Divider(height: 1, indent: 56),
            _buildActionTile(
              icon: Icons.save_alt,
              color: Colors.purple,
              title: 'Save Export to Device',
              subtitle: 'Choose where to save the .ecbackup file',
              onTap: () => _handleExport(
                () => ExportImportService.saveExportToDevice(),
                'Save to Device',
              ),
              isLoading: _isExporting,
            ),
          ]),

          const SizedBox(height: 16),

          // Import Section
          _buildSectionHeader(
            icon: Icons.download_rounded,
            title: 'Import Data',
            subtitle: 'Restore from backup files',
          ),
          _buildCard([
            _buildActionTile(
              icon: Icons.upload_file,
              color: Colors.green,
              title: 'Import Events',
              subtitle: 'Restore events from .ecbackup or .json',
              onTap: _previewAndImport,
              isLoading: _isImporting,
            ),
            const Divider(height: 1, indent: 56),
            _buildActionTile(
              icon: Icons.restore,
              color: Colors.red,
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
          ]),

          const SizedBox(height: 16),

          // Backup Section
          _buildSectionHeader(
            icon: Icons.auto_fix_high,
            title: 'Auto Backup',
            subtitle: 'Manual backup management',
          ),
          _buildCard([
            _buildActionTile(
              icon: Icons.cloud_upload,
              color: Colors.cyan,
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
            const Divider(height: 1, indent: 56),
            _buildActionTile(
              icon: Icons.find_in_page,
              color: Colors.amber,
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
          ]),

          const SizedBox(height: 24),

          // Status Card
          if (_lastMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastMessageIsError
                      ? colorScheme.errorContainer
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastMessageIsError
                        ? colorScheme.error
                        : Colors.green.shade200,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_lastMessageIsError ? Colors.red : Colors.green)
                          .withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _lastMessageIsError
                            ? colorScheme.error.withOpacity(0.1)
                            : Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _lastMessageIsError ? Icons.error_outline : Icons.check_circle_outline,
                        color: _lastMessageIsError
                            ? colorScheme.error
                            : Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastMessage!,
                        style: TextStyle(
                          color: _lastMessageIsError
                              ? colorScheme.onErrorContainer
                              : Colors.green.shade900,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final isDisabled = isLoading || _isExporting || _isImporting;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              )
            : Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDisabled ? Colors.grey.shade500 : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDisabled ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: isLoading
          ? const SizedBox.shrink()
          : Icon(
              Icons.chevron_right,
              color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade400,
              size: 20,
            ),
      enabled: !isDisabled,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
