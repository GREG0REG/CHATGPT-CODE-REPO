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
  WidgetBackgroundType _bgType = WidgetBackgroundType.themeColor;
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

  // Battery state for live UI updates
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

  /// Listen to battery state changes for live UI updates in SettingsScreen.
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

  Future<void> _setBgType(WidgetBackgroundType type) async {
    if (type == WidgetBackgroundType.customImage && _imagePath == null) {
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

  // ==================== BACKUP & RESTORE (FIXED) ====================

  /// Exports events via system share sheet — user picks Downloads, Drive, email, etc.
  /// The file survives app storage clear because it's saved to a location the user chose.
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

  /// Exports ALL data (events, flashcards, notes, grades, etc.) via share sheet.
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

  /// Imports events from a JSON file picked by the user.
  /// The service handles file picker, validation, and backup/rollback.
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

  /// Imports full backup (all tables) from a JSON file picked by the user.
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
                const _SectionHeader('App Theme'),
                ...AppThemes.all.map((info) {
                  final isSelected = _theme == info.option;
                  return RadioListTile<AppThemeOption>(
                    title: Row(children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: info.gradientColors),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(info.label)
                    ]),
                    secondary: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    value: info.option,
                    groupValue: _theme,
                    onChanged: (v) {
                      if (v != null) _setTheme(v);
                      if (v == AppThemeOption.customHex) _showColorPicker();
                    },
                  );
                }),
                if (_theme == AppThemeOption.customHex) ...[
                  ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _customColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    title: const Text('Custom Color'),
                    subtitle: Text(
                        '#${_customColor.value.toRadixString(16).substring(2).toUpperCase()}'),
                    trailing:
                        TextButton(onPressed: _showColorPicker, child: const Text('Change')),
                  ),
                ],
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
                RadioListTile<WidgetBackgroundType>(
                  title: const Text('App theme color'),
                  subtitle: const Text('Default. Uses the theme color above.'),
                  value: WidgetBackgroundType.themeColor,
                  groupValue: _bgType,
                  onChanged: (v) => v != null ? _setBgType(v) : null,
                ),
                RadioListTile<WidgetBackgroundType>(
                  title: const Text('Custom image'),
                  subtitle: const Text(
                      'Pick a photo from your gallery (dark overlay applied for readability).'),
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
                // FIXED: BatteryService integration — live battery status in subtitle
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
                // ==================== BACKUP & RESTORE UI (FIXED) ====================
                const _SectionHeader('Backup & Restore'),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export Events'),
                  subtitle: const Text('Share via Downloads, email, Drive, etc.'),
                  onTap: _exportEvents,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Export All Data'),
                  subtitle: const Text('Everything: events, flashcards, notes, grades...'),
                  onTap: _exportAllData,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Events'),
                  subtitle: const Text('Restore events from a JSON file'),
                  onTap: _importEvents,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('Import All Data'),
                  subtitle: const Text('Restore full backup (events + study data)'),
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
