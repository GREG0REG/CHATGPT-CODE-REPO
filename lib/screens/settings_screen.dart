import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../database_helper.dart';
import '../main.dart';
import '../models/notification_history.dart';
import '../services/battery_service.dart';
import '../services/export_import_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../theme/app_themes.dart';
import '../WIDGET/simple_color_picker.dart';
import 'widget_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smartFormat = false;
  bool _use24Hour = true;
  AppThemeOption _theme = AppThemeOption.auroraBorealis;
  String _bgType = 'themeColor';
  String? _imagePath;
  ThemeMode _themeMode = ThemeMode.system;
  Color _customColor = const Color(0xFF00BFA5);
  bool _highContrast = false;
  bool _widgetProgressBar = false;
  bool _widgetPulseAnimation = false;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  List<NotificationHistory> _notificationHistory = [];
  bool _adaptiveRefresh = true;
  bool _loading = true;
  bool _busy = false;
  bool _themesExpanded = false;

  String _batteryStatus = 'Unknown';
  bool _batteryLow = false;
  StreamSubscription<BatteryState>? _batterySub;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenToBattery();
  }

  @override
  void dispose() {
    _batterySub?.cancel();
    super.dispose();
  }

  void _listenToBattery() {
    _updateBatteryStatus();
    _batterySub = BatteryService.instance.onBatteryStateChanged.listen((_) {
      if (mounted) _updateBatteryStatus();
    });
  }

  Future<void> _updateBatteryStatus() async {
    final level = await BatteryService.instance.getBatteryLevel();
    final charging = await BatteryService.instance.isCharging();
    final low = await BatteryService.instance.isLowBattery();
    if (!mounted) return;
    setState(() {
      _batteryStatus = '${charging ? '⚡ Charging' : '🔋 On battery'} • $level%';
      _batteryLow = low;
    });
  }

  Future<void> _loadSettings() async {
    final s = SettingsService.instance;
    final smart = await s.getSmartFormatEnabled();
    final use24 = await s.getUse24HourFormat();
    final theme = await s.getSelectedTheme();
    final bgType = await s.getWidgetBackgroundType();
    final imagePath = await s.getWidgetImagePath();
    final mode = await s.getThemeMode();
    final custom = await s.getCustomColor();
    final hc = await s.getHighContrast();
    final progressBar = await s.getWidgetProgressBar();
    final pulseAnim = await s.getWidgetPulseAnimation();
    final quietEnabled = await s.getQuietHoursEnabled();
    final quietStartMin = await s.getQuietHoursStart();
    final quietEndMin = await s.getQuietHoursEnd();
    final adaptRefresh = await s.getAdaptiveRefreshEnabled();

    if (!mounted) return;

    setState(() {
      _smartFormat = smart;
      _use24Hour = use24;
      _theme = theme;
      _bgType = bgType;
      _imagePath = imagePath;
      _themeMode = mode;
      _customColor = custom ?? const Color(0xFF00BFA5);
      _highContrast = hc;
      _widgetProgressBar = progressBar;
      _widgetPulseAnimation = pulseAnim;
      _quietHoursEnabled = quietEnabled;
      _quietStart =
          TimeOfDay(hour: quietStartMin ~/ 60, minute: quietStartMin % 60);
      _quietEnd = TimeOfDay(hour: quietEndMin ~/ 60, minute: quietEndMin % 60);
      _adaptiveRefresh = adaptRefresh;
      _loading = false;
    });

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await DatabaseHelper.instance.getNotificationHistory(limit: 20);
    if (mounted) setState(() => _notificationHistory = history);
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
    if (mounted) EventCountdownAppState.of(context)?.updateTheme(option);
  }

  Future<void> _setBgType(String type) async {
    if (type == 'customImage' && _imagePath == null) {
      final picked = await _pickImage();
      if (!picked) return;
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

  Future<void> _setThemeMode(ThemeMode mode) async {
    await SettingsService.instance.setThemeMode(mode);
    setState(() => _themeMode = mode);
    if (mounted) EventCountdownAppState.of(context)?.updateThemeMode(mode);
  }

  Future<void> _showColorPicker() async {
    final Color? picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => SimpleColorPickerDialog(initialColor: _customColor),
    );

    if (!mounted) return;
    if (picked == null) return;

    await SettingsService.instance.setCustomColor(picked);
    setState(() => _customColor = picked);
    if (_theme == AppThemeOption.customHex) {
      await WidgetService.refreshWidget();
      if (mounted) EventCountdownAppState.of(context)?.updateCustomColor(picked);
    }
  }

  Future<void> _setHighContrast(bool value) async {
    await SettingsService.instance.setHighContrast(value);
    setState(() => _highContrast = value);
    if (mounted) EventCountdownAppState.of(context)?.updateHighContrast(value);
  }

  Future<void> _setWidgetProgressBar(bool value) async {
    await SettingsService.instance.setWidgetProgressBar(value);
    setState(() => _widgetProgressBar = value);
    await WidgetService.refreshWidget();
  }

  Future<void> _setWidgetPulseAnimation(bool value) async {
    await SettingsService.instance.setWidgetPulseAnimation(value);
    setState(() => _widgetPulseAnimation = value);
    await WidgetService.refreshWidget();
  }

  Future<void> _setQuietHoursEnabled(bool value) async {
    await SettingsService.instance.setQuietHoursEnabled(value);
    setState(() => _quietHoursEnabled = value);
  }

  Future<void> _pickQuietStart() async {
    final picked = await showTimePicker(context: context, initialTime: _quietStart);
    if (picked == null) return;
    await SettingsService.instance
        .setQuietHoursStart(picked.hour * 60 + picked.minute);
    setState(() => _quietStart = picked);
  }

  Future<void> _pickQuietEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _quietEnd);
    if (picked == null) return;
    await SettingsService.instance
        .setQuietHoursEnd(picked.hour * 60 + picked.minute);
    setState(() => _quietEnd = picked);
  }

  Future<void> _clearHistory() async {
    await DatabaseHelper.instance.clearNotificationHistory();
    setState(() => _notificationHistory = []);
    _showSnack('History cleared');
  }

  Future<void> _setAdaptiveRefresh(bool value) async {
    await SettingsService.instance.setAdaptiveRefreshEnabled(value);
    setState(() => _adaptiveRefresh = value);
  }

  Future<void> _runVacuum() async {
    setState(() => _busy = true);
    try {
      await DatabaseHelper.instance.vacuum();
      await SettingsService.instance.setLastVacuum(DateTime.now());
      _showSnack('Database optimized');
    } catch (e) {
      _showSnack('Optimization failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _exportEvents() async {
    setState(() => _busy = true);
    try {
      await ExportImportService.exportAndShareEvents();
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEventsToDevice() async {
    setState(() => _busy = true);
    try {
      final path = await ExportImportService.saveExportToDevice();
      if (path != null) {
        _showSnack('Saved to: ${path.split('/').last}');
      }
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportAllData() async {
    setState(() => _busy = true);
    try {
      await ExportImportService.exportAndShareAllData();
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAllDataToDevice() async {
    setState(() => _busy = true);
    try {
      final path = await ExportImportService.saveFullExportToDevice();
      if (path != null) {
        _showSnack('Saved to: ${path.split('/').last}');
      }
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importEvents() async {
    setState(() => _busy = true);
    try {
      final count = await ExportImportService.importEventsFromPicker();
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

  Future<void> _importAllData() async {
    setState(() => _busy = true);
    try {
      await ExportImportService.importAllDataFromPicker();
      final events = await DatabaseHelper.instance.getAllEventsSorted();
      await NotificationService.instance.rescheduleAll(events);
      await WidgetService.refreshWidget();
      _showSnack('All data imported successfully');
    } catch (e) {
      _showSnack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            ListView(
              children: [
                const _SectionHeader('Appearance'),
                ListTile(
                  leading: const Icon(Icons.brightness_auto),
                  title: const Text('Theme Mode'),
                  subtitle: Text(_themeModeLabel(_themeMode)),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode)),
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Auto'),
                          icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (selected) {
                      if (selected.isNotEmpty) _setThemeMode(selected.first);
                    },
                  ),
                ),
                const Divider(),
                // ── EXPANDABLE THEME SECTION ──
                _ExpandableThemeSection(
                  expanded: _themesExpanded,
                  onToggle: () => setState(() => _themesExpanded = !_themesExpanded),
                  currentTheme: _theme,
                  customColor: _customColor,
                  onThemeSelected: _setTheme,
                  onCustomColorTap: _showColorPicker,
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.contrast),
                  title: const Text('High Contrast'),
                  subtitle:
                      const Text('Increase contrast for better accessibility'),
                  value: _highContrast,
                  onChanged: _setHighContrast,
                ),
                const Divider(),
                const _SectionHeader('Countdown Display'),
                SwitchListTile(
                  title: const Text('Smart countdown format'),
                  subtitle: const Text(
                      'Shows days/hours/minutes until start, then time remaining until deadline.'),
                  value: _smartFormat,
                  onChanged: _setSmartFormat,
                ),
                SwitchListTile(
                  title: const Text('24-hour time'),
                  subtitle:
                      Text(_use24Hour ? '24-hour (e.g. 18:00)' : '12-hour (e.g. 6:00 PM)'),
                  value: _use24Hour,
                  onChanged: _setUse24Hour,
                ),
                const Divider(),
                const _SectionHeader('Widget Options'),
                SwitchListTile(
                  secondary: const Icon(Icons.linear_scale),
                  title: const Text('Show Progress Bar'),
                  subtitle:
                      const Text('Display time elapsed percentage on widget'),
                  value: _widgetProgressBar,
                  onChanged: _setWidgetProgressBar,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.animation),
                  title: const Text('Pulse Animation'),
                  subtitle:
                      const Text('Gentle pulse effect when event is under 24 hours'),
                  value: _widgetPulseAnimation,
                  onChanged: _setWidgetPulseAnimation,
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Advanced Widget Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WidgetSettingsScreen()));
                  },
                ),
                const Divider(),
                const _SectionHeader('Quiet Hours'),
                SwitchListTile(
                  secondary: const Icon(Icons.do_not_disturb_on),
                  title: const Text('Enable Quiet Hours'),
                  subtitle:
                      const Text('Skip non-urgent notifications during set hours'),
                  value: _quietHoursEnabled,
                  onChanged: _setQuietHoursEnabled,
                ),
                if (_quietHoursEnabled) ...[
                  ListTile(
                    leading: const Icon(Icons.bedtime),
                    title: const Text('Start time'),
                    subtitle: Text(
                        '${_quietStart.hour.toString().padLeft(2, '0')}:${_quietStart.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickQuietStart,
                  ),
                  ListTile(
                    leading: const Icon(Icons.wb_sunny),
                    title: const Text('End time'),
                    subtitle: Text(
                        '${_quietEnd.hour.toString().padLeft(2, '0')}:${_quietEnd.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickQuietEnd,
                  ),
                ],
                const Divider(),
                const _SectionHeader('Notification History'),
                if (_notificationHistory.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No notifications sent yet.'))
                else
                  ..._notificationHistory.take(5).map((h) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(h.sentAtMillis);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(h.eventTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${h.reminderType} • ${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'),
                    );
                  }),
                if (_notificationHistory.isNotEmpty)
                  TextButton(onPressed: _clearHistory, child: const Text('Clear History')),
                const Divider(),
                const _SectionHeader('Home Screen Widget Background'),
                RadioListTile<String>(
                  title: const Text('App theme color'),
                  subtitle: const Text('Default. Uses the theme color above.'),
                  value: 'themeColor',
                  groupValue: _bgType,
                  onChanged: (v) => v != null ? _setBgType(v) : null,
                ),
                RadioListTile<String>(
                  title: const Text('Custom image'),
                  subtitle: const Text(
                      'Pick a photo from your gallery (dark overlay applied for readability).'),
                  value: 'customImage',
                  groupValue: _bgType,
                  onChanged: (v) => v != null ? _setBgType(v) : null,
                ),
                if (_bgType == 'customImage') ...[
                  if (_imagePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_imagePath!),
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover)),
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
                const _SectionHeader('Performance'),
                SwitchListTile(
                  secondary: Icon(
                    Icons.speed,
                    color: _batteryLow ? Colors.orange : null,
                  ),
                  title: const Text('Adaptive Refresh'),
                  subtitle: Text(
                    _adaptiveRefresh
                        ? '$_batteryStatus${_batteryLow ? ' • Reduced mode active' : ''}'
                        : '$_batteryStatus • Always full speed',
                  ),
                  value: _adaptiveRefresh,
                  onChanged: _setAdaptiveRefresh,
                ),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Optimize Database'),
                  subtitle: const Text('Clean up and compact local storage'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _runVacuum,
                ),
                const Divider(),
                const _SectionHeader('Backup & Restore'),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share Events Export'),
                  subtitle: const Text('Send via WhatsApp, Gmail, Drive, etc. (.ecbackup)'),
                  onTap: _exportEvents,
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Save Events to Device'),
                  subtitle: const Text('Choose Downloads or any folder (.ecbackup)'),
                  onTap: _saveEventsToDevice,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Share Full Backup'),
                  subtitle: const Text('Everything: events, flashcards, notes, grades... (.ecbackup)'),
                  onTap: _exportAllData,
                ),
                ListTile(
                  leading: const Icon(Icons.save),
                  title: const Text('Save Full Backup to Device'),
                  subtitle: const Text('Choose Downloads or any folder (.ecbackup)'),
                  onTap: _saveAllDataToDevice,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Events'),
                  subtitle: const Text('Restore events from an .ecbackup file'),
                  onTap: _importEvents,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('Import All Data'),
                  subtitle: const Text('Restore full backup (events + study data) from .ecbackup'),
                  onTap: _importAllData,
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

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Always light';
      case ThemeMode.dark:
        return 'Always dark';
      case ThemeMode.system:
        return 'Follow system';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// EXPANDABLE THEME SECTION WIDGET
// ═══════════════════════════════════════════════════════════════

class _ExpandableThemeSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final AppThemeOption currentTheme;
  final Color customColor;
  final ValueChanged<AppThemeOption> onThemeSelected;
  final VoidCallback onCustomColorTap;

  const _ExpandableThemeSection({
    required this.expanded,
    required this.onToggle,
    required this.currentTheme,
    required this.customColor,
    required this.onThemeSelected,
    required this.onCustomColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.palette),
          title: const Text('App Theme'),
          subtitle: Text(_themeLabel(currentTheme)),
          trailing: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.expand_more, color: cs.primary),
          ),
          onTap: onToggle,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildThemeGrid(context),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildThemeGrid(BuildContext context) {
    final themes = AppThemes.all;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: themes.map((info) {
              final isSelected = currentTheme == info.option;
              return _ThemeChip(
                info: info,
                isSelected: isSelected,
                onTap: () {
                  onThemeSelected(info.option);
                  if (info.option == AppThemeOption.customHex) {
                    onCustomColorTap();
                  }
                },
              );
            }).toList(),
          ),
          if (currentTheme == AppThemeOption.customHex) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: customColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
              title: const Text('Custom Color'),
              subtitle: Text(
                '#${customColor.value.toRadixString(16).substring(2).toUpperCase()}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              trailing: TextButton(
                onPressed: onCustomColorTap,
                child: const Text('Change'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _themeLabel(AppThemeOption option) {
    final info = AppThemes.all.firstWhere(
      (t) => t.option == option,
      orElse: () => AppThemes.all.first,
    );
    return info.label;
  }
}

class _ThemeChip extends StatelessWidget {
  final ThemeInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 86,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: info.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              info.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
            color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
