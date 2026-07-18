import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/focus_settings_service.dart';

/// Bottom sheet for all Pomodoro / Focus settings.
/// Replaces the old "Pomodoro & Goals" section in SettingsScreen.
class FocusSettingsSheet extends StatefulWidget {
  const FocusSettingsSheet({super.key});

  @override
  State<FocusSettingsSheet> createState() => _FocusSettingsSheetState();
}

class _FocusSettingsSheetState extends State<FocusSettingsSheet> {
  final _fs = FocusSettingsService.instance;

  bool _loading = true;

  String _preset = 'classic';
  int _customFocus = 25;
  int _customShortBreak = 5;
  int _customLongBreak = 15;
  int _customSessions = 4;

  int _dailyGoalMinutes = 120;
  int _dailyGoalPomodoros = 4;

  bool _autoStartBreak = false;
  bool _timerSound = true;
  bool _sessionNotes = false;
  bool _keepScreenAwake = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final preset = await _fs.getDefaultPreset();
    final cFocus = await _fs.getCustomFocusMinutes();
    final cShort = await _fs.getCustomShortBreakMinutes();
    final cLong = await _fs.getCustomLongBreakMinutes();
    final cSess = await _fs.getCustomSessionsBeforeLongBreak();

    final dMin = await _fs.getDailyGoalMinutes();
    final dPomo = await _fs.getDailyGoalPomodoros();

    final autoBreak = await _fs.getAutoStartBreak();
    final tSound = await _fs.getTimerSoundEnabled();
    final sNotes = await _fs.getSessionNotesEnabled();
    final awake = await _fs.getKeepScreenAwake();

    if (mounted) {
      setState(() {
        _preset = preset;
        _customFocus = cFocus;
        _customShortBreak = cShort;
        _customLongBreak = cLong;
        _customSessions = cSess;
        _dailyGoalMinutes = dMin;
        _dailyGoalPomodoros = dPomo;
        _autoStartBreak = autoBreak;
        _timerSound = tSound;
        _sessionNotes = sNotes;
        _keepScreenAwake = awake;
        _loading = false;
      });
    }
  }

  Future<void> _setPreset(String v) async {
    await _fs.setDefaultPreset(v);
    setState(() => _preset = v);
  }

  Future<void> _setCustomFocus(int v) async {
    await _fs.setCustomFocusMinutes(v);
    setState(() => _customFocus = v);
  }

  Future<void> _setCustomShortBreak(int v) async {
    await _fs.setCustomShortBreakMinutes(v);
    setState(() => _customShortBreak = v);
  }

  Future<void> _setCustomLongBreak(int v) async {
    await _fs.setCustomLongBreakMinutes(v);
    setState(() => _customLongBreak = v);
  }

  Future<void> _setCustomSessions(int v) async {
    await _fs.setCustomSessionsBeforeLongBreak(v);
    setState(() => _customSessions = v);
  }

  Future<void> _setDailyGoalMinutes(int v) async {
    await _fs.setDailyGoalMinutes(v);
    setState(() => _dailyGoalMinutes = v);
  }

  Future<void> _setDailyGoalPomodoros(int v) async {
    await _fs.setDailyGoalPomodoros(v);
    setState(() => _dailyGoalPomodoros = v);
  }

  Future<void> _setAutoStartBreak(bool v) async {
    await _fs.setAutoStartBreak(v);
    setState(() => _autoStartBreak = v);
  }

  Future<void> _setTimerSound(bool v) async {
    await _fs.setTimerSoundEnabled(v);
    setState(() => _timerSound = v);
  }

  Future<void> _setSessionNotes(bool v) async {
    await _fs.setSessionNotesEnabled(v);
    setState(() => _sessionNotes = v);
  }

  Future<void> _setKeepScreenAwake(bool v) async {
    await _fs.setKeepScreenAwake(v);
    setState(() => _keepScreenAwake = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Focus Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // ── Preset ──
                    _sectionHeader('Timer Preset'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'classic', label: Text('Classic')),
                          ButtonSegment(value: 'deepWork', label: Text('Deep')),
                          ButtonSegment(value: 'examCrunch', label: Text('Exam')),
                          ButtonSegment(value: 'custom', label: Text('Custom')),
                        ],
                        selected: {_preset},
                        onSelectionChanged: (sel) {
                          if (sel.isNotEmpty) _setPreset(sel.first);
                        },
                      ),
                    ),

                    // Custom sliders
                    if (_preset == 'custom') ...[
                      const SizedBox(height: 16),
                      _sliderTile(
                        label: 'Focus duration',
                        value: _customFocus,
                        min: 5,
                        max: 120,
                        divisions: 23,
                        suffix: 'min',
                        onChanged: _setCustomFocus,
                      ),
                      _sliderTile(
                        label: 'Short break',
                        value: _customShortBreak,
                        min: 1,
                        max: 30,
                        divisions: 29,
                        suffix: 'min',
                        onChanged: _setCustomShortBreak,
                      ),
                      _sliderTile(
                        label: 'Long break',
                        value: _customLongBreak,
                        min: 5,
                        max: 60,
                        divisions: 11,
                        suffix: 'min',
                        onChanged: _setCustomLongBreak,
                      ),
                      _sliderTile(
                        label: 'Sessions before long break',
                        value: _customSessions,
                        min: 1,
                        max: 8,
                        divisions: 7,
                        suffix: '',
                        onChanged: _setCustomSessions,
                      ),
                    ],

                    const Divider(height: 32),

                    // ── Daily Goal ──
                    _sectionHeader('Daily Goal'),
                    _sliderTile(
                      label: 'Target minutes',
                      value: _dailyGoalMinutes,
                      min: 30,
                      max: 480,
                      divisions: 15,
                      suffix: 'min',
                      onChanged: _setDailyGoalMinutes,
                    ),
                    _sliderTile(
                      label: 'Target sessions',
                      value: _dailyGoalPomodoros,
                      min: 1,
                      max: 16,
                      divisions: 15,
                      suffix: 'sessions',
                      onChanged: _setDailyGoalPomodoros,
                    ),

                    const Divider(height: 32),

                    // ── Toggles ──
                    _sectionHeader('Behavior'),
                    SwitchListTile(
                      title: const Text('Auto-start Break'),
                      subtitle: const Text('Automatically begin break after focus ends'),
                      value: _autoStartBreak,
                      onChanged: _setAutoStartBreak,
                    ),
                    SwitchListTile(
                      title: const Text('Timer Sound'),
                      subtitle: const Text('Play sound when timer completes'),
                      value: _timerSound,
                      onChanged: _setTimerSound,
                    ),
                    SwitchListTile(
                      title: const Text('Session Notes'),
                      subtitle: const Text('Prompt for a note after each focus session'),
                      value: _sessionNotes,
                      onChanged: _setSessionNotes,
                    ),
                    SwitchListTile(
                      title: const Text('Keep Screen Awake'),
                      subtitle: const Text('Prevent screen from sleeping during focus'),
                      value: _keepScreenAwake,
                      onChanged: _setKeepScreenAwake,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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

  Widget _sliderTile({
    required String label,
    required int value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
              Text(
                '$value $suffix',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
