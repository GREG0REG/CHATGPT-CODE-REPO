import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../main.dart';
import '../models/notification_history.dart';
import '../services/battery_service.dart';
import '../services/export_import_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';        // ← FIXED: was missing
import '../services/widget_service.dart';
import '../theme/app_themes.dart';
import 'widget_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Session 1-3 settings
  bool _smartFormat = false;
  bool _use24Hour = true;
  AppThemeOption _theme = AppThemeOption.defaultBlue;
  WidgetBackgroundType _bgType = WidgetBackgroundType.themeColor;  // ← This type comes from settings_service.dart import
  String? _imagePath;
  ThemeMode _themeMode = ThemeMode.system;
  Color _customColor = Colors.blue;
  bool _highContrast = false;
  bool _widgetProgressBar = false;
  bool _widgetPulseAnimation = false;

  // Session 4 settings
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  List<NotificationHistory> _notificationHistory = [];

  // Session 9 settings
  bool _batteryOptimization = true;
  bool _adaptiveRefresh = true;
  int _batteryLevel = 100;
  bool _isCharging = false;

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
    final mode = await s.getThemeMode();
    final custom = await s.getCustomColor();
    final hc = await s.getHighContrast();
    final progressBar = await s.getWidgetProgressBar();
    final pulseAnim = await s.getWidgetPulseAnimation();

    // Session 4
    final quietEnabled = await s.getQuietHoursEnabled();
    final quietStartMin = await s.getQuietHoursStart();
    final quietEndMin = await s.getQuietHoursEnd();

    // Session 9
    final batOpt = await s.getBatteryOptimizationEnabled();
    final adaptRefresh = await s.getAdaptiveRefreshEnabled();

    if (!mounted) return;
    setState(() {
      _smartFormat = smart;
      _use24Hour = use24;
      _theme = theme;
      _bgType = bgType;
      _imagePath = imagePath;
      _themeMode = mode;
      _customColor = custom ?? Colors.blue;
      _highContrast = hc;
      _widgetProgressBar = progressBar;
      _widgetPulseAnimation = pulseAnim;
      _quietHoursEnabled = quietEnabled;
      _quietStart = TimeOfDay(
        hour: quietStartMin ~/ 60,
        minute: quietStartMin % 60,
      );
      _quietEnd = TimeOfDay(
        hour: quietEndMin ~/ 60,
        minute: quietEndMin % 60,
      );
      _batteryOptimization = batOpt;
      _adaptiveRefresh = adaptRefresh;
      _loading = false;
    });

    _loadBatteryInfo();
    _loadHistory();
  }

  Future<void> _loadBatteryInfo() async {
    try {
      final level = await BatteryService.instance.getBatteryLevel();
      final charging = await BatteryService.instance.isCharging();
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _isCharging = charging;
        });
      }
    } catch (e) {
      // Ignore on unsupported platforms
    }
  }

  Future<void> _loadHistory() async {
    final history = await DatabaseHelper.instance.getNotificationHistory(limit: 20);
    if (mounted) setState(() => _notificationHistory = history);
  }

  // --- Session 1 callbacks (preserved) ---
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
    if (mounted) {
      EventCountdownAppState.of(context)?.updateTheme(option);
    }
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

  // --- Session 2 callbacks ---
  Future<void> _setThemeMode(ThemeMode mode) async {
    await SettingsService.instance.setThemeMode(mode);
    setState(() => _themeMode = mode);
    if (mounted) {
      EventCountdownAppState.of(context)?.updateThemeMode(mode);
    }
  }

  Future<void> _showColorPicker() async {
    final Color picked = await showColorPickerDialog(
      context,
      _customColor,
      title: const Text('Pick Custom Color'),
      showColorName: true,
      showColorValue: true,
      pickersEnabled: const {
        ColorPickerType.wheel: true,
        ColorPickerType.accent: true,
        ColorPickerType.primary: true,
      },
      actionButtons: const ColorPickerActionButtons(
        dialogOkButtonLabel: 'Save',
        dialogCancelButtonLabel: 'Cancel',
      ),
    );
    if (!mounted) return;
    await SettingsService.instance.setCustomColor(picked);
    setState(() => _customColor = picked);
    if (_theme == AppThemeOption.customHex) {
      await WidgetService.refreshWidget();
      if (mounted) {
        EventCountdownAppState.of(context)?.updateCustomColor(picked);
      }
    }
  }

  Future<void> _setHighContrast(bool value) async {
    await SettingsService.instance.setHighContrast(value);
    setState(() => _highContrast = value);
    if (mounted) {
      EventCountdownAppState.of(context)?.updateHighContrast(value);
    }
  }

  // --- Session 3 callbacks ---
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

  // ============================================
  // SESSION 4: Quiet Hours
  // ============================================
  Future<void> _setQuietHoursEnabled(bool value) async {
    await SettingsService.instance.setQuietHoursEnabled(value);
    setState(() => _quietHoursEnabled = value);
  }

  Future<void> _pickQuietStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietStart,
    );
    if (picked == null) return;
    await SettingsService.instance.setQuietHoursStart(picked.hour * 60 + picked.minute);
    setState(() => _quietStart = picked);
  }

  Future<void> _pickQuietEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietEnd,
    );
    if (picked == null) return;
    await SettingsService.instance.setQuietHoursEnd(picked.hour * 60 + picked.minute);
    setState(() => _quietEnd = picked);
  }

  Future<void> _clearHistory() async {
    await DatabaseHelper.instance.clearNotificationHistory();
    setState(() => _notificationHistory = []);
    _showSnack('History cleared');
  }

  // ============================================
  // SESSION 9: Battery & Performance
  // ============================================
  Future<void> _setBatteryOptimization(bool value) async {
    await SettingsService.instance.setBatteryOptimizationEnabled(value);
    setState(() => _batteryOptimization = value);
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

  // --- Export / Import (preserved) ---
  Future<void> _exportEvents() async {
    setState(() => _busy = true);
    try {
      final path = await ExportImportService.exportToJson();
      if (!mounted) return;

      final isDownloads = path.contains('/Download/');
      final message = isDownloads
          ? 'Exported to Downloads folder'
          : 'Exported to app storage';

      _showSnack('$message\nFile: ${path.split('/').last}');
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
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import events?'),
        content: Text(
          'Import ${result.files.single.name}?\n\n'
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
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
                // SESSION 2: THEME MODE
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
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (selected) {
                      if (selected.isNotEmpty) _setThemeMode(selected.first);
                    },
                  ),
                ),
                const Divider(),

                // SESSION 2: APP THEME
                const _SectionHeader('App Theme'),
                ...AppThemes.all.map((info) {
                  final isSelected = _theme == info.option;
                  return RadioListTile<AppThemeOption>(
                    title: Row(
                      children: [
                        Icon(info.icon, color: info.color, size: 20),
                        const SizedBox(width: 8),
                        Text(info.label),
                      ],
                    ),
                    secondary: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    value: info.option,
                    groupValue: _theme,
                    onChanged: (v) {
                      if (v != null) _setTheme(v);
                      if (v == AppThemeOption.customHex) {
                        _showColorPicker();
                      }
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
                    subtitle: Text('#${_customColor.value.toRadixString(16).substring(2).toUpperCase()}'),
                    trailing: TextButton(
                      onPressed: _showColorPicker,
                      child: const Text('Change'),
                    ),
                  ),
                ],

                const Divider(),

                // SESSION 2: HIGH CONTRAST
                SwitchListTile(
                  secondary: const Icon(Icons.contrast),
                  title: const Text('High Contrast'),
                  subtitle: const Text('Increase contrast for better accessibility'),
                  value: _highContrast,
                  onChanged: _setHighContrast,
                ),
                const Divider(),

                // SESSION 1: COUNTDOWN DISPLAY
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

                // SESSION 3: WIDGET ENHANCEMENTS
                const _SectionHeader('Widget Options'),
                SwitchListTile(
                  secondary: const Icon(Icons.linear_scale),
                  title: const Text('Show Progress Bar'),
                  subtitle: const Text('Display time elapsed percentage on widget'),
                  value: _widgetProgressBar,
                  onChanged: _setWidgetProgressBar,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.animation),
                  title: const Text('Pulse Animation'),
                  subtitle: const Text('Gentle pulse effect when event is under 24 hours'),
                  value: _widgetPulseAnimation,
                  onChanged: _setWidgetPulseAnimation,
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Advanced Widget Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WidgetSettingsScreen()),
                    );
                  },
                ),
                const Divider(),

                // ============================================
                // SESSION 4: QUIET HOURS
                // ============================================
                const _SectionHeader('Quiet Hours'),
                SwitchListTile(
                  secondary: const Icon(Icons.do_not_disturb_on),
                  title: const Text('Enable Quiet Hours'),
                  subtitle: const Text('Skip non-urgent notifications during set hours'),
                  value: _quietHoursEnabled,
                  onChanged: _setQuietHoursEnabled,
                ),
                if (_quietHoursEnabled) ...[
                  ListTile(
                    leading: const Icon(Icons.bedtime),
                    title: const Text('Start time'),
                    subtitle: Text('${_quietStart.hour.toString().padLeft(2, '0')}:${_quietStart.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickQuietStart,
                  ),
                  ListTile(
                    leading: const Icon(Icons.wb_sunny),
                    title: const Text('End time'),
                    subtitle: Text('${_quietEnd.hour.toString().padLeft(2, '0')}:${_quietEnd.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickQuietEnd,
                  ),
                ],
                const Divider(),

                // SESSION 4: NOTIFICATION HISTORY
                const _SectionHeader('Notification History'),
                if (_notificationHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No notifications sent yet.'),
                  )
                else
                  ..._notificationHistory.take(5).map((h) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(h.sentAtMillis);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(h.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${h.reminderType} • ${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'),
                    );
                  }),
                if (_notificationHistory.isNotEmpty)
                  TextButton(
                    onPressed: _clearHistory,
                    child: const Text('Clear History'),
                  ),
                const Divider(),

                // SESSION 1: WIDGET BACKGROUND
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

                // ============================================
                // SESSION 9: BATTERY & PERFORMANCE
                // ============================================
                const _SectionHeader('Battery & Performance'),
                ListTile(
                  leading: Icon(
                    _isCharging ? Icons.battery_charging_full : Icons.battery_full,
                    color: _batteryLevel < 20 ? Colors.red : null,
                  ),
                  title: const Text('Battery Status'),
                  subtitle: Text('$_batteryLevel%${_isCharging ? ' • Charging' : ''}'),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.battery_saver),
                  title: const Text('Battery Optimization'),
                  subtitle: const Text('Slow down refresh when battery is low'),
                  value: _batteryOptimization,
                  onChanged: _setBatteryOptimization,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.speed),
                  title: const Text('Adaptive Refresh'),
                  subtitle: const Text('Faster updates when events are imminent'),
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

                // SESSION 1: BACKUP
                const _SectionHeader('Backup'),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export events to JSON'),
                  subtitle: const Text('Saves to Downloads + opens share sheet'),
                  onTap: _exportEvents,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import events from JSON'),
                  subtitle: const Text('Pick a .json file from your device'),
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
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
