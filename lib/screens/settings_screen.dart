import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../main.dart';
import '../services/export_import_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../theme/app_themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smartFormat = false;
  bool _use24Hour = true;
  AppThemeOption _theme = AppThemeOption.defaultBlue;
  WidgetBackgroundType _bgType = WidgetBackgroundType.themeColor;
  String? _imagePath;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = SettingsService.instance;
    final smart = await s.getSmartFormatEnabled();
    final use24 = await s.getUse24HourFormat();
    final theme = await s.getSelectedTheme();
    final bgType = await s.getWidgetBackgroundType();
    final imagePath = await s.getWidgetImagePath();
    if (!mounted) return;
    setState(() {
      _smartFormat = smart;
      _use24Hour = use24;
      _theme = theme;
      _bgType = bgType;
      _imagePath = imagePath;
      _loading = false;
    });
  }

  Future<void> _setSmartFormat(bool value) async {
    await SettingsService.instance.setSmartFormatEnabled(value);
    setState(() => _smartFormat = value);
    await WidgetService.refreshWidget();
  }

  Future<void> _setUse24Hour(bool value) async {
    await SettingsService.instance.setUse24HourFormat(value);
    setState(() => _use24Hour = value);
  }

  Future<void> _setTheme(AppThemeOption option) async {
    await SettingsService.instance.setSelectedTheme(option);
    setState(() => _theme = option);
    await WidgetService.refreshWidget();
    // Rebuild the whole app immediately with the new theme colors.
    if (mounted) {
      EventCountdownAppState.of(context)?.updateTheme(option);
    }
  }

  Future<void> _setBgType(WidgetBackgroundType type) async {
    if (type == WidgetBackgroundType.customImage && _imagePath == null) {
      // Prompt to pick an image right away since one is required for this mode.
      final picked = await _pickImage();
      if (!picked) return; // user cancelled - stay on theme color
    }
    await SettingsService.instance.setWidgetBackgroundType(type);
    setState(() => _bgType = type);
    await WidgetService.refreshWidget();
  }

  Future<bool> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return false;
    await SettingsService.instance.setWidgetImagePath(xfile.path);
    setState(() => _imagePath = xfile.path);
    await WidgetService.refreshWidget();
    return true;
  }

  Future<void> _exportEvents() async {
    setState(() => _busy = true);
    try {
      final path = await ExportImportService.exportToJson();
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'Event Countdown export');
      _showSnack('Exported to $path');
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importEvents() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import events?'),
        content: const Text(
          'This will replace ALL current events with the ones in the '
          'selected file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final count =
          await ExportImportService.importFromJson(result.files.single.path!);
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      await NotificationService.instance.rescheduleAll(events);
      await WidgetService.refreshWidget();
      _showSnack('Imported $count event(s)');
    } catch (e) {
      _showSnack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            ListView(
              children: [
                const _SectionHeader('Countdown Display'),
                SwitchListTile(
                  title: const Text('Smart countdown format'),
                  subtitle: const Text(
                    'Shows days/hours/minutes until start, then time '
                    'remaining until deadline. When off, always shows '
                    '"X days left".',
                  ),
                  value: _smartFormat,
                  onChanged: _setSmartFormat,
                ),
                SwitchListTile(
                  title: const Text('24-hour time'),
                  subtitle: Text(_use24Hour ? '24-hour (e.g. 18:00)' : '12-hour (e.g. 6:00 PM)'),
                  value: _use24Hour,
                  onChanged: _setUse24Hour,
                ),
                const Divider(),
                const _SectionHeader('Theme'),
                ...AppThemes.all.map(
                  (info) => RadioListTile<AppThemeOption>(
                    title: Text(info.label),
                    secondary: CircleAvatar(backgroundColor: info.color, radius: 14),
                    value: info.option,
                    groupValue: _theme,
                    onChanged: (v) => v != null ? _setTheme(v) : null,
                  ),
                ),
                const Divider(),
                const _SectionHeader('Home Screen Widget Background'),
                RadioListTile<WidgetBackgroundType>(
                  title: const Text('App theme color'),
                  subtitle: const Text('Default. Uses the theme color above.'),
                  value: WidgetBackgroundType.themeColor,
                  groupValue: _bgType,
                  onChanged: (v) => v != null ? _setBgType(v) : null,
                ),
                RadioListTile<WidgetBackgroundType>(
                  title: const Text('Custom image'),
                  subtitle: const Text('Pick a photo from your gallery (dark overlay applied for readability).'),
                  value: WidgetBackgroundType.customImage,
                  groupValue: _bgType,
                  onChanged: (v) => v != null ? _setBgType(v) : null,
                ),
                if (_bgType == WidgetBackgroundType.customImage) ...[
                  if (_imagePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePath!),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Pick custom widget image'),
                    ),
                  ),
                ],
                const Divider(),
                const _SectionHeader('Backup'),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export events to JSON'),
                  onTap: _exportEvents,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import events from JSON'),
                  onTap: _importEvents,
                ),
                const SizedBox(height: 24),
              ],
            ),
            if (_busy) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
