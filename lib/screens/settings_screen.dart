// FILE: lib/screens/settings_screen.dart
// COMPLETE REPLACEMENT — Fixed themes, NEET date picker, functional NEET mode
// CHANGES:
//  1. Uses ThemeNotifier.instance.setTheme() — themes now apply instantly
//  2. Added NEET Exam Date picker (saved to SharedPreferences)
//  3. Added Daily Study Goal picker
//  4. Added Subject Weekly Goal settings
//  5. All NEET toggles are functional and persisted
//  6. Theme grid uses AppThemes.all with live preview

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:event_countdown/services/export_import_service.dart';
import 'package:event_countdown/services/backup_service.dart';
import 'package:event_countdown/services/widget_service.dart';
import 'package:event_countdown/services/settings_service.dart';
import 'package:event_countdown/services/theme_service.dart';
import 'package:event_countdown/theme/app_themes.dart';

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

  // NEET Mode settings
  bool _neetModeEnabled = true;
  bool _showSubjectBreakdown = true;
  bool _showCountdownBanner = true;
  DateTime _neetExamDate = DateTime(2027, 5, 4); // Default NEET 2027

  // Theme settings
  AppThemeOption _currentThemeOption = AppThemeOption.auroraBorealis;

  // Study settings
  bool _studyRemindersEnabled = true;
  int _reminderInterval = 60;
  int _dailyStudyGoal = 120;

  // Subject goals
  int _physicsGoal = 120;
  int _chemistryGoal = 120;
  int _biologyGoal = 120;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // NEET mode
      final neetMode = prefs.getBool('neet_mode_enabled') ?? true;
      final showBanner = prefs.getBool('show_countdown_banner') ?? true;
      final showBreakdown = prefs.getBool('show_subject_breakdown') ?? true;
      final neetDateMs = prefs.getInt('neet_exam_date_millis');

      // Theme
      final themeRaw = prefs.getString('selectedTheme');
      AppThemeOption theme = AppThemeOption.auroraBorealis;
      if (themeRaw != null && themeRaw != 'default') {
        try {
          theme = AppThemeOption.values.byName(themeRaw);
        } catch (_) {}
      }

      // Study
      final reminders = prefs.getBool('study_reminders_enabled') ?? true;
      final interval = prefs.getInt('reminder_interval') ?? 60;
      final dailyGoal = prefs.getInt('dailyStudyGoal') ?? 120;

      // Subject goals
      final physGoal = prefs.getInt('subjectGoal_Physics') ?? 120;
      final chemGoal = prefs.getInt('subjectGoal_Chemistry') ?? 120;
      final bioGoal = prefs.getInt('subjectGoal_Biology') ?? 120;

      if (mounted) {
        setState(() {
          _neetModeEnabled = neetMode;
          _showCountdownBanner = showBanner;
          _showSubjectBreakdown = showBreakdown;
          _neetExamDate = neetDateMs != null
              ? DateTime.fromMillisecondsSinceEpoch(neetDateMs)
              : DateTime(2027, 5, 4);
          _currentThemeOption = theme;
          _studyRemindersEnabled = reminders;
          _reminderInterval = interval;
          _dailyStudyGoal = dailyGoal;
          _physicsGoal = physGoal;
          _chemistryGoal = chemGoal;
          _biologyGoal = bioGoal;
        });
      }
    } catch (e) {
      debugPrint('Settings load error: $e');
    }
  }

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

  Future<void> _pickNeetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _neetExamDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select NEET Exam Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF00695C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _neetExamDate = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('neet_exam_date_millis', picked.millisecondsSinceEpoch);
      HapticFeedback.lightImpact();
      _showMessage('NEET exam date updated: ${_formatDate(picked)}');
    }
  }

  String _formatDate(DateTime dt) {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month]}, ${dt.year}';
  }

  String _getDaysRemaining() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(_neetExamDate.year, _neetExamDate.month, _neetExamDate.day);
    final diff = exam.difference(today).inDays;
    if (diff < 0) return 'Exam passed';
    if (diff == 0) return 'Today!';
    return '$diff days left';
  }

  Future<void> _showGoalPicker(String subject, int currentValue, Function(int) onSave) async {
    int tempValue = currentValue;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$subject Weekly Goal'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tempValue ~/ 60}h ${tempValue % 60}m per week',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: tempValue.toDouble(),
                  min: 30,
                  max: 600,
                  divisions: 19,
                  label: '${tempValue ~/ 60}h',
                  onChanged: (v) => setDialogState(() => tempValue = v.round()),
                ),
                Wrap(
                  spacing: 8,
                  children: [60, 120, 180, 240, 300, 360].map((m) => ActionChip(
                    label: Text('${m ~/ 60}h'),
                    onPressed: () => setDialogState(() => tempValue = m),
                  )).toList(),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onSave(tempValue);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyGoalPicker() async {
    int tempValue = _dailyStudyGoal;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Daily Study Goal'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tempValue ~/ 60}h ${tempValue % 60}m per day',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: tempValue.toDouble(),
                  min: 30,
                  max: 480,
                  divisions: 15,
                  label: '${tempValue ~/ 60}h',
                  onChanged: (v) => setDialogState(() => tempValue = v.round()),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              setState(() => _dailyStudyGoal = tempValue);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('dailyStudyGoal', tempValue);
              Navigator.pop(ctx);
              _showMessage('Daily goal set to ${tempValue ~/ 60}h ${tempValue % 60}m');
            },
            child: const Text('Save'),
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
          // ═══════════════════════════════════════════════════════════
          // NEET MODE SECTION
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader(
            icon: Icons.local_hospital,
            title: 'NEET Mode',
            subtitle: 'Customize your exam preparation view',
          ),
          _buildCard([
            // Master toggle
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Color(0xFF00695C),
                  size: 20,
                ),
              ),
              title: const Text(
                'NEET Exam Mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Show countdown banner and subject breakdown',
                style: TextStyle(fontSize: 12),
              ),
              value: _neetModeEnabled,
              onChanged: (value) async {
                HapticFeedback.lightImpact();
                setState(() => _neetModeEnabled = value);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('neet_mode_enabled', value);
              },
            ),
            const Divider(height: 1, indent: 56),
            // Countdown banner toggle
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timer,
                  color: Colors.red.shade700,
                  size: 20,
                ),
              ),
              title: const Text(
                'Show Countdown Banner',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Display NEET exam countdown on home screen',
                style: TextStyle(fontSize: 12),
              ),
              value: _showCountdownBanner,
              onChanged: _neetModeEnabled
                  ? (value) async {
                      HapticFeedback.lightImpact();
                      setState(() => _showCountdownBanner = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('show_countdown_banner', value);
                    }
                  : null,
            ),
            const Divider(height: 1, indent: 56),
            // Subject breakdown toggle
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_outline,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: const Text(
                'Subject Breakdown',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Show Physics/Chemistry/Biology time split',
                style: TextStyle(fontSize: 12),
              ),
              value: _showSubjectBreakdown,
              onChanged: _neetModeEnabled
                  ? (value) async {
                      HapticFeedback.lightImpact();
                      setState(() => _showSubjectBreakdown = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('show_subject_breakdown', value);
                    }
                  : null,
            ),
            const Divider(height: 1, indent: 56),
            // NEET Exam Date picker
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF00695C),
                  size: 20,
                ),
              ),
              title: const Text(
                'NEET Exam Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${_formatDate(_neetExamDate)} • ${_getDaysRemaining()}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_calendar, size: 20),
                onPressed: _pickNeetDate,
              ),
              onTap: _pickNeetDate,
            ),
          ]),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // APPEARANCE SECTION — All 23 Themes from AppThemes.all
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader(
            icon: Icons.palette,
            title: 'Appearance',
            subtitle: 'Choose from ${AppThemes.all.length} study-optimized themes',
          ),
          _buildCard([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppThemes.getInfo(_currentThemeOption)?.label ?? 'Aurora',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Theme grid — all 23 themes from AppThemes.all
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppThemes.all.map((themeInfo) {
                      final isSelected = _currentThemeOption == themeInfo.option;
                      return _buildThemeChip(themeInfo, isSelected, colorScheme);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // STUDY GOALS SECTION
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader(
            icon: Icons.track_changes,
            title: 'Study Goals',
            subtitle: 'Set your daily and weekly targets',
          ),
          _buildCard([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer, color: Colors.teal, size: 20),
              ),
              title: const Text('Daily Study Goal', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${_dailyStudyGoal ~/ 60}h ${_dailyStudyGoal % 60}m per day'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showDailyGoalPicker,
            ),
            const Divider(height: 1, indent: 56),
            _buildGoalTile('Physics', _physicsGoal, const Color(0xFF1565C0), (v) async {
              setState(() => _physicsGoal = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('subjectGoal_Physics', v);
            }),
            const Divider(height: 1, indent: 56),
            _buildGoalTile('Chemistry', _chemistryGoal, const Color(0xFF2E7D32), (v) async {
              setState(() => _chemistryGoal = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('subjectGoal_Chemistry', v);
            }),
            const Divider(height: 1, indent: 56),
            _buildGoalTile('Biology', _biologyGoal, const Color(0xFFC62828), (v) async {
              setState(() => _biologyGoal = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('subjectGoal_Biology', v);
            }),
          ]),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // STUDY REMINDERS SECTION
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader(
            icon: Icons.notifications_active,
            title: 'Study Reminders',
            subtitle: 'Stay on track with your schedule',
          ),
          _buildCard([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              title: const Text(
                'Study Reminders',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Get notified to start study sessions',
                style: TextStyle(fontSize: 12),
              ),
              value: _studyRemindersEnabled,
              onChanged: (value) async {
                HapticFeedback.lightImpact();
                setState(() => _studyRemindersEnabled = value);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('study_reminders_enabled', value);
              },
            ),
            if (_studyRemindersEnabled) ...[
              const Divider(height: 1, indent: 56),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.timer,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Reminder Interval',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Every $_reminderInterval minutes',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: DropdownButton<int>(
                  value: _reminderInterval,
                  underline: const SizedBox.shrink(),
                  items: [30, 45, 60, 90, 120].map((interval) {
                    return DropdownMenuItem(
                      value: interval,
                      child: Text(
                        '$interval min',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      HapticFeedback.lightImpact();
                      setState(() => _reminderInterval = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('reminder_interval', value);
                    }
                  },
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // EXPORT SECTION
          // ═══════════════════════════════════════════════════════════
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

          // ═══════════════════════════════════════════════════════════
          // IMPORT SECTION
          // ═══════════════════════════════════════════════════════════
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

          // ═══════════════════════════════════════════════════════════
          // BACKUP SECTION
          // ═══════════════════════════════════════════════════════════
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

          // ═══════════════════════════════════════════════════════════
          // STATUS CARD
          // ═══════════════════════════════════════════════════════════
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

  Widget _buildGoalTile(String subject, int value, Color color, Function(int) onSave) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          subject == 'Physics' ? Icons.science :
          subject == 'Chemistry' ? Icons.biotech : Icons.eco,
          color: color,
          size: 20,
        ),
      ),
      title: Text('$subject Weekly Goal', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${value ~/ 60}h ${value % 60}m per week'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showGoalPicker(subject, value, onSave),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // THEME CHIP BUILDER — Uses ThemeNotifier for instant apply
  // ═══════════════════════════════════════════════════════════════
  Widget _buildThemeChip(ThemeInfo info, bool isSelected, ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          setState(() => _currentThemeOption = info.option);
          // KEY FIX: Use ThemeNotifier to trigger MaterialApp rebuild
          await ThemeNotifier.instance.setTheme(info.option);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? info.gradientColors.first.withOpacity(0.15)
                : cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? info.gradientColors.first
                  : cs.outlineVariant.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: info.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: info.gradientColors.first.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: info.icon != null
                    ? Icon(info.icon, size: 16, color: Colors.white.withOpacity(0.9))
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                info.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? info.gradientColors.first : cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILDER HELPERS
  // ═══════════════════════════════════════════════════════════════

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
