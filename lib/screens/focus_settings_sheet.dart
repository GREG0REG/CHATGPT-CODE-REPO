// FILE: lib/screens/focus_settings_sheet.dart
// COMPLETE REPLACEMENT — NEET Edition v16
// FIXED: Exam date now defaults to May 2, 2027 (user's actual date)
// FIXED: All settings properly save and sync
// NEW: Preset preview cards with duration breakdown
// NEW: Daily goal visual indicator
// NEW: Reset to defaults option

import 'package:flutter/material.dart';
import '../services/focus_settings_service.dart';

class FocusSettingsSheet extends StatefulWidget {
  const FocusSettingsSheet({super.key});

  @override
  State<FocusSettingsSheet> createState() => _FocusSettingsSheetState();
}

class _FocusSettingsSheetState extends State<FocusSettingsSheet> {
  final _fs = FocusSettingsService.instance;

  int _customFocus = 90;
  int _customShort = 15;
  int _customLong = 30;
  int _customSessions = 3;
  int _dailyGoalMin = 360;
  int _dailyGoalPomos = 4;

  bool _autoStartBreak = false;
  bool _timerSound = true;
  bool _sessionNotes = false;
  bool _keepAwake = true;
  bool _showNeetCountdown = true;
  bool _distractionLog = true;
  bool _intensityRating = true;

  DateTime _neetExamDate = DateTime(2027, 5, 2);

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final focus = await _fs.getCustomFocusMinutes();
    final short = await _fs.getCustomShortBreakMinutes();
    final long = await _fs.getCustomLongBreakMinutes();
    final sessions = await _fs.getCustomSessionsBeforeLongBreak();
    final goalMin = await _fs.getDailyGoalMinutes();
    final goalPomos = await _fs.getDailyGoalPomodoros();
    final autoBreak = await _fs.getAutoStartBreak();
    final sound = await _fs.getTimerSoundEnabled();
    final notes = await _fs.getSessionNotesEnabled();
    final awake = await _fs.getKeepScreenAwake();
    final showNeet = await _fs.getShowNeetCountdown();
    final distract = await _fs.getDistractionLogEnabled();
    final intensity = await _fs.getIntensityRatingEnabled();
    final neetMillis = await _fs.getNeetExamDateMillis();

    if (!mounted) return;
    setState(() {
      _customFocus = focus;
      _customShort = short;
      _customLong = long;
      _customSessions = sessions;
      _dailyGoalMin = goalMin;
      _dailyGoalPomos = goalPomos;
      _autoStartBreak = autoBreak;
      _timerSound = sound;
      _sessionNotes = notes;
      _keepAwake = awake;
      _showNeetCountdown = showNeet;
      _distractionLog = distract;
      _intensityRating = intensity;
      _neetExamDate = DateTime.fromMillisecondsSinceEpoch(neetMillis);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _fs.setCustomFocusMinutes(_customFocus);
    await _fs.setCustomShortBreakMinutes(_customShort);
    await _fs.setCustomLongBreakMinutes(_customLong);
    await _fs.setCustomSessionsBeforeLongBreak(_customSessions);
    await _fs.setDailyGoalMinutes(_dailyGoalMin);
    await _fs.setDailyGoalPomodoros(_dailyGoalPomos);
    await _fs.setAutoStartBreak(_autoStartBreak);
    await _fs.setTimerSoundEnabled(_timerSound);
    await _fs.setSessionNotesEnabled(_sessionNotes);
    await _fs.setKeepScreenAwake(_keepAwake);
    await _fs.setShowNeetCountdown(_showNeetCountdown);
    await _fs.setDistractionLogEnabled(_distractionLog);
    await _fs.setIntensityRatingEnabled(_intensityRating);
    await _fs.setNeetExamDateMillis(_neetExamDate.millisecondsSinceEpoch);

    if (mounted) {
      Navigator.pop(context, true); // Return true to signal refresh needed
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text('All focus settings will be reset to NEET defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _customFocus = 90;
        _customShort = 15;
        _customLong = 30;
        _customSessions = 3;
        _dailyGoalMin = 360;
        _dailyGoalPomos = 4;
        _autoStartBreak = false;
        _timerSound = true;
        _sessionNotes = false;
        _keepAwake = true;
        _showNeetCountdown = true;
        _distractionLog = true;
        _intensityRating = true;
        _neetExamDate = DateTime(2027, 5, 2);
      });
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.psychology_alt, color: scheme.onPrimaryContainer, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Focus Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Customize your NEET study sessions',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _resetToDefaults,
                      child: const Text('Reset'),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // ── NEET Exam Date ──
                    _buildSectionTitle('NEET Exam Countdown', Icons.calendar_month),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickNeetDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: scheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exam Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.outline,
                                    ),
                                  ),
                                  Text(
                                    '${_neetExamDate.day} ${_monthName(_neetExamDate.month)} ${_neetExamDate.year}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit_calendar, color: scheme.outline, size: 18),
                          ],
                        ),
                      ),
                    ),
                    _buildSwitchTile(
                      'Show Countdown Banner',
                      'Display days until NEET on Focus screen',
                      _showNeetCountdown,
                      (v) => setState(() => _showNeetCountdown = v),
                    ),
                    const SizedBox(height: 16),

                    // ── Preset Preview Cards ──
                    _buildSectionTitle('Preset Preview', Icons.preview),
                    const SizedBox(height: 8),
                    _buildPresetPreviewCard('NEET Revision', '90 min focus • 15 min short • 30 min long • 3 sessions', scheme),
                    _buildPresetPreviewCard('NEET Deep', '120 min focus • 20 min short • 45 min long • 2 sessions', scheme),
                    _buildPresetPreviewCard('NEET Sprint', '60 min focus • 10 min short • 20 min long • 4 sessions', scheme),
                    const SizedBox(height: 16),

                    // ── Custom Preset ──
                    _buildSectionTitle('Custom Preset', Icons.tune),
                    const SizedBox(height: 8),
                    _buildDurationSlider(
                      'Focus Duration',
                      _customFocus,
                      15,
                      180,
                      (v) => setState(() => _customFocus = v),
                      Icons.hourglass_top,
                    ),
                    _buildDurationSlider(
                      'Short Break',
                      _customShort,
                      5,
                      30,
                      (v) => setState(() => _customShort = v),
                      Icons.coffee,
                    ),
                    _buildDurationSlider(
                      'Long Break',
                      _customLong,
                      10,
                      60,
                      (v) => setState(() => _customLong = v),
                      Icons.bedtime,
                    ),
                    _buildDurationSlider(
                      'Sessions Before Long Break',
                      _customSessions,
                      1,
                      8,
                      (v) => setState(() => _customSessions = v),
                      Icons.repeat,
                    ),
                    const SizedBox(height: 16),

                    // ── Daily Goals ──
                    _buildSectionTitle('Daily Goals', Icons.track_changes),
                    const SizedBox(height: 8),
                    _buildDurationSlider(
                      'Daily Target (minutes)',
                      _dailyGoalMin,
                      30,
                      720,
                      (v) => setState(() => _dailyGoalMin = v),
                      Icons.schedule,
                    ),
                    _buildDurationSlider(
                      'Daily Target (sessions)',
                      _dailyGoalPomos,
                      1,
                      12,
                      (v) => setState(() => _dailyGoalPomos = v),
                      Icons.local_fire_department,
                    ),
                    // Daily goal visual indicator
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'That\'s ${_dailyGoalMin ~/ 60}h ${_dailyGoalMin % 60}min across $_dailyGoalPomos sessions',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Features ──
                    _buildSectionTitle('Features', Icons.auto_awesome),
                    _buildSwitchTile(
                      'Distraction Log',
                      'Track distractions during focus sessions',
                      _distractionLog,
                      (v) => setState(() => _distractionLog = v),
                    ),
                    _buildSwitchTile(
                      'Session Intensity Rating',
                      'Rate focus quality after each session',
                      _intensityRating,
                      (v) => setState(() => _intensityRating = v),
                    ),
                    _buildSwitchTile(
                      'Session Notes',
                      'Add notes after completing a session',
                      _sessionNotes,
                      (v) => setState(() => _sessionNotes = v),
                    ),
                    _buildSwitchTile(
                      'Keep Screen Awake',
                      'Prevent screen from sleeping during focus',
                      _keepAwake,
                      (v) => setState(() => _keepAwake = v),
                    ),
                    _buildSwitchTile(
                      'Timer Sound',
                      'Play sound when timer completes',
                      _timerSound,
                      (v) => setState(() => _timerSound = v),
                    ),
                    _buildSwitchTile(
                      'Auto-start Break',
                      'Automatically start break after focus',
                      _autoStartBreak,
                      (v) => setState(() => _autoStartBreak = v),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetPreviewCard(String title, String subtitle, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: title.contains('Revision') ? const Color(0xFF667EEA)
                  : title.contains('Deep') ? const Color(0xFF764BA2)
                  : const Color(0xFFFF6B6B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSlider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.outline),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
            activeColor: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: scheme.outline,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: scheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month];
  }
}
