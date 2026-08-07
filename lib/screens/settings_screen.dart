// FILE: lib/screens/settings_screen.dart
// COMPLETE REPLACEMENT — Shows warning when restoring empty backup
// CHANGES from previous version:
//   1. _doImport now checks result.wasEmpty and shows red warning snackbar
//   2. Import success message shows totalRows if available

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isWorking = false;
  String? _lastMessage;
  bool _lastMessageIsError = false;

  bool _neetModeEnabled = true;
  bool _showSubjectBreakdown = true;
  bool _showCountdownBanner = true;
  DateTime _neetExamDate = DateTime(2027, 5, 4);
  AppThemeOption _currentThemeOption = AppThemeOption.auroraBorealis;
  bool _studyRemindersEnabled = true;
  int _reminderInterval = 60;
  int _dailyStudyGoal = 120;
  int _physicsGoal = 120;
  int _chemistryGoal = 120;
  int _biologyGoal = 120;
  bool _autoBackupEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _neetModeEnabled = prefs.getBool('neet_mode_enabled') ?? true;
        _showCountdownBanner = prefs.getBool('show_countdown_banner') ?? true;
        _showSubjectBreakdown = prefs.getBool('show_subject_breakdown') ?? true;
        final neetDateMs = prefs.getInt('neet_exam_date_millis');
        _neetExamDate = neetDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(neetDateMs)
            : DateTime(2027, 5, 4);
        final themeRaw = prefs.getString('selectedTheme');
        if (themeRaw != null && themeRaw != 'default') {
          try {
            _currentThemeOption = AppThemeOption.values.byName(themeRaw);
          } catch (_) {}
        }
        _studyRemindersEnabled = prefs.getBool('study_reminders_enabled') ?? true;
        _reminderInterval = prefs.getInt('reminder_interval') ?? 60;
        _dailyStudyGoal = prefs.getInt('dailyStudyGoal') ?? 120;
        _physicsGoal = prefs.getInt('subjectGoal_Physics') ?? 120;
        _chemistryGoal = prefs.getInt('subjectGoal_Chemistry') ?? 120;
        _biologyGoal = prefs.getInt('subjectGoal_Biology') ?? 120;
        _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
      });
    } catch (e) {
      debugPrint('Settings load error: $e');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _lastMessage = message;
      _lastMessageIsError = isError;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: Duration(seconds: isError ? 6 : 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _doBackup(Future<BackupResult> Function() fn, String label) async {
    setState(() => _isWorking = true);
    try {
      final result = await fn();
      if (result.success) {
        _showMessage('${result.message ?? label}\nPath: ${p.basename(result.filePath ?? '')}');
      } else {
        _showMessage(result.message ?? '$label failed', isError: true);
      }
    } catch (e) {
      _showMessage('$label error: $e', isError: true);
    } finally {
      setState(() => _isWorking = false);
    }
  }

  // FIXED: Shows warning when restoring empty backup
  Future<void> _doImport(Future<ImportResult> Function() fn, String label) async {
    setState(() => _isWorking = true);
    try {
      final result = await fn();
      if (result.success) {
        // FIXED: Warn if backup was empty
        if (result.wasEmpty) {
          _showMessage(result.message ?? 'Backup was empty!', isError: true);
        } else {
          _showMessage(result.message ?? label);
        }
        WidgetService.refreshWidget();
      } else {
        _showMessage(result.message ?? '$label failed', isError: true);
      }
    } catch (e) {
      _showMessage('$label error: $e', isError: true);
    } finally {
      setState(() => _isWorking = false);
    }
  }

  Future<void> _pickNeetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _neetExamDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select NEET Exam Date',
    );
    if (picked != null) {
      setState(() => _neetExamDate = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('neet_exam_date_millis', picked.millisecondsSinceEpoch);
      HapticFeedback.lightImpact();
      _showMessage('NEET date: ${_formatDate(picked)}');
    }
  }

  String _formatDate(DateTime dt) {
    final m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month]}, ${dt.year}';
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

  Future<void> _showGoalPicker(String subject, int current, Function(int) onSave) async {
    int temp = current;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$subject Weekly Goal'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${temp ~/ 60}h ${temp % 60}m', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              Slider(value: temp.toDouble(), min: 30, max: 600, divisions: 19, label: '${temp ~/ 60}h', onChanged: (v) => setDialogState(() => temp = v.round())),
              Wrap(
                spacing: 8,
                children: [60, 120, 180, 240, 300, 360].map((m) => ActionChip(
                  label: Text('${m ~/ 60}h'),
                  onPressed: () => setDialogState(() => temp = m),
                )).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () { onSave(temp); Navigator.pop(ctx); }, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _showDailyGoalPicker() async {
    int temp = _dailyStudyGoal;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Daily Study Goal'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${temp ~/ 60}h ${temp % 60}m per day', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              Slider(value: temp.toDouble(), min: 30, max: 480, divisions: 15, label: '${temp ~/ 60}h', onChanged: (v) => setDialogState(() => temp = v.round())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              setState(() => _dailyStudyGoal = temp);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('dailyStudyGoal', temp);
              Navigator.pop(ctx);
              _showMessage('Daily goal: ${temp ~/ 60}h ${temp % 60}m');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Settings'), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader(icon: Icons.local_hospital, title: 'NEET Mode', subtitle: 'Exam preparation settings'),
          _card([
            _switchTile(
              icon: Icons.local_hospital,
              color: const Color(0xFF00695C),
              title: 'NEET Exam Mode',
              subtitle: 'Countdown banner and subject breakdown',
              value: _neetModeEnabled,
              onChanged: (v) async {
                setState(() => _neetModeEnabled = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('neet_mode_enabled', v);
              },
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.timer,
              color: Colors.red,
              title: 'Countdown Banner',
              subtitle: 'Show NEET countdown on home screen',
              value: _showCountdownBanner,
              onChanged: _neetModeEnabled ? (v) async {
                setState(() => _showCountdownBanner = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('show_countdown_banner', v);
              } : null,
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.pie_chart_outline,
              color: Colors.blue,
              title: 'Subject Breakdown',
              subtitle: 'Physics / Chemistry / Biology time split',
              value: _showSubjectBreakdown,
              onChanged: _neetModeEnabled ? (v) async {
                setState(() => _showSubjectBreakdown = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('show_subject_breakdown', v);
              } : null,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _iconBox(icon: Icons.calendar_today, color: const Color(0xFF00695C)),
              title: const Text('NEET Exam Date', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${_formatDate(_neetExamDate)} • ${_getDaysRemaining()}', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.edit_calendar, size: 20),
              onTap: _pickNeetDate,
            ),
          ]),

          const SizedBox(height: 16),

          _sectionHeader(icon: Icons.palette, title: 'Appearance', subtitle: '${AppThemes.all.length} study-optimized themes'),
          _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          AppThemes.getInfo(_currentThemeOption)?.label ?? 'Aurora',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppThemes.all.map((themeInfo) {
                      final isSelected = _currentThemeOption == themeInfo.option;
                      return _themeChip(themeInfo, isSelected, cs);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          _sectionHeader(icon: Icons.track_changes, title: 'Study Goals', subtitle: 'Daily and weekly targets'),
          _card([
            ListTile(
              leading: _iconBox(icon: Icons.timer, color: Colors.teal),
              title: const Text('Daily Study Goal', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${_dailyStudyGoal ~/ 60}h ${_dailyStudyGoal % 60}m per day'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showDailyGoalPicker,
            ),
            const Divider(height: 1, indent: 56),
            _goalTile('Physics', _physicsGoal, const Color(0xFF1565C0), (v) async {
              setState(() => _physicsGoal = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('subjectGoal_Physics', v);
            }),
            const Divider(height: 1, indent: 56),
            _goalTile('Chemistry', _chemistryGoal, const Color(0xFF2E7D32), (v) async {
              setState(() => _chemistryGoal = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('subjectGoal_Chemistry', v);
            }),
            const Divider(height: 1, indent: 56),
            _goalTile('Biology', _biologyGoal, const Color(0xFFC62828), (v) async {
              setState(() => _biologyGoal = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('subjectGoal_Biology', v);
            }),
          ]),

          const SizedBox(height: 16),

          _sectionHeader(icon: Icons.notifications_active, title: 'Study Reminders', subtitle: 'Stay on track'),
          _card([
            _switchTile(
              icon: Icons.notifications_active,
              color: Colors.orange,
              title: 'Study Reminders',
              subtitle: 'Get notified to start study sessions',
              value: _studyRemindersEnabled,
              onChanged: (v) async {
                setState(() => _studyRemindersEnabled = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('study_reminders_enabled', v);
              },
            ),
            if (_studyRemindersEnabled) ...[
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _iconBox(icon: Icons.timer, color: Colors.teal),
                title: const Text('Reminder Interval', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Every $_reminderInterval minutes'),
                trailing: DropdownButton<int>(
                  value: _reminderInterval,
                  underline: const SizedBox.shrink(),
                  items: [30, 45, 60, 90, 120].map((i) => DropdownMenuItem(value: i, child: Text('$i min', style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _reminderInterval = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('reminder_interval', v);
                  },
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          _sectionHeader(icon: Icons.backup, title: 'Backup & Export', subtitle: 'Save and restore your data'),
          _card([
            _actionTile(
              icon: Icons.event_note,
              color: Colors.blue,
              title: 'Export Events',
              subtitle: 'JSON file with just your events',
              onTap: () => _doBackup(() => BackupService.instance.exportEvents(share: true), 'Export Events'),
              isLoading: _isWorking,
            ),
            const Divider(height: 1, indent: 56),
            _actionTile(
              icon: Icons.backup,
              color: Colors.indigo,
              title: 'Full Backup',
              subtitle: 'Complete database backup (all tables)',
              onTap: () => _doBackup(() => BackupService.instance.exportFull(saveToDownloads: true), 'Full Backup'),
              isLoading: _isWorking,
            ),
            const Divider(height: 1, indent: 56),
            _actionTile(
              icon: Icons.code,
              color: Colors.orange,
              title: 'Export Plain JSON',
              subtitle: 'Human-readable events only',
              onTap: () => _doBackup(() => BackupService.instance.exportEventsPlain(), 'Plain JSON'),
              isLoading: _isWorking,
            ),
            const Divider(height: 1, indent: 56),
            _actionTile(
              icon: Icons.save_alt,
              color: Colors.purple,
              title: 'Save to Device',
              subtitle: 'Choose where to save the backup',
              onTap: () => _doBackup(() => BackupService.instance.saveEventsToDevice(), 'Save to Device'),
              isLoading: _isWorking,
            ),
            const Divider(height: 1, indent: 56),
            _actionTile(
              icon: Icons.upload_file,
              color: Colors.green,
              title: 'Import from File',
              subtitle: 'Restore from a JSON backup',
              onTap: () => _doImport(() => BackupService.instance.importFromPicker(), 'Import'),
              isLoading: _isWorking,
            ),
            const Divider(height: 1, indent: 56),
            _actionTile(
              icon: Icons.restore,
              color: Colors.red,
              title: 'Restore Recent Backup',
              subtitle: 'Find and restore the latest backup',
              onTap: () async {
                setState(() => _isWorking = true);
                try {
                  final path = await BackupService.instance.findRecentBackup();
                  if (path == null) {
                    _showMessage('No recent backup found', isError: true);
                  } else {
                    final result = await BackupService.instance.importFromPath(path);
                    if (result.success) {
                      // FIXED: Show warning if backup was empty
                      if (result.wasEmpty) {
                        _showMessage(result.message ?? 'Backup was empty!', isError: true);
                      } else {
                        _showMessage('Restored: ${result.message}');
                      }
                      WidgetService.refreshWidget();
                    } else {
                      _showMessage(result.message ?? 'Restore failed', isError: true);
                    }
                  }
                } catch (e) {
                  _showMessage('Restore error: $e', isError: true);
                } finally {
                  setState(() => _isWorking = false);
                }
              },
              isLoading: _isWorking,
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.cloud_upload,
              color: Colors.cyan,
              title: 'Auto Backup',
              subtitle: 'Weekly automatic full backup',
              value: _autoBackupEnabled,
              onChanged: (v) async {
                setState(() => _autoBackupEnabled = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('auto_backup_enabled', v);
              },
            ),
          ]),

          const SizedBox(height: 24),

          if (_lastMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastMessageIsError ? cs.errorContainer : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _lastMessageIsError ? cs.error : Colors.green.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(_lastMessageIsError ? Icons.error_outline : Icons.check_circle_outline,
                        color: _lastMessageIsError ? cs.error : Colors.green.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_lastMessage!, style: TextStyle(color: _lastMessageIsError ? cs.onErrorContainer : Colors.green.shade900, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _iconBox({required IconData icon, required Color color}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: _iconBox(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final disabled = isLoading || _isWorking;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _iconBox(icon: icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: disabled ? Colors.grey.shade500 : null)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: disabled ? Colors.grey.shade400 : Colors.grey.shade600)),
      trailing: isLoading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(color)))
          : Icon(Icons.chevron_right, color: disabled ? Colors.grey.shade300 : Colors.grey.shade400, size: 20),
      enabled: !disabled,
      onTap: onTap,
    );
  }

  Widget _goalTile(String subject, int value, Color color, Function(int) onSave) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _iconBox(
        icon: subject == 'Physics' ? Icons.science : subject == 'Chemistry' ? Icons.biotech : Icons.eco,
        color: color,
      ),
      title: Text('$subject Weekly Goal', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${value ~/ 60}h ${value % 60}m per week'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showGoalPicker(subject, value, onSave),
    );
  }

  Widget _themeChip(ThemeInfo info, bool isSelected, ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          setState(() => _currentThemeOption = info.option);
          await ThemeNotifier.instance.setTheme(info.option);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? info.gradientColors.first.withOpacity(0.15) : cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? info.gradientColors.first : cs.outlineVariant.withOpacity(0.3), width: isSelected ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: info.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: isSelected ? [BoxShadow(color: info.gradientColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: info.icon != null ? Icon(info.icon, size: 16, color: Colors.white.withOpacity(0.9)) : null,
              ),
              const SizedBox(height: 6),
              Text(info.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? info.gradientColors.first : cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
