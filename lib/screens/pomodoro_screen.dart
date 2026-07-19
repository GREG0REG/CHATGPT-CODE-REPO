import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../database_helper.dart';
import '../main.dart';
import '../models/event.dart';
import '../models/study_subject.dart';
import '../services/focus_settings_service.dart';
import '../services/pomodoro_service.dart';
import '../services/widget_service.dart';
import '../theme/app_themes.dart';
import '../WIDGET/subject_picker_sheet.dart';
import 'focus_settings_sheet.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  late final PomodoroService _service;
  late final AnimationController _pulseController;

  PomodoroPreset _selectedPreset = PomodoroPreset.classic;
  String? _selectedSubject;
  StudySubject? _selectedStudySubject;
  int? _selectedEventId;

  // Custom duration values (loaded from FocusSettings, no longer shown as sliders)
  int _customFocus = 25;
  int _customShortBreak = 5;
  int _customLongBreak = 15;
  int _customSessions = 4;

  // Daily goal progress
  int _dailyGoalMinutes = 120;
  int _todayMinutes = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = PomodoroService.instance;
    _service.init();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadSettings();

    // Listen to service changes
    _service.phaseNotifier.addListener(_onServiceUpdate);
    _service.remainingSecondsNotifier.addListener(_onServiceUpdate);
    _service.completedSessionsNotifier.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
    _checkSessionNote();
    _updateWakelock();
    _updateDailyProgress();
    WidgetService.refreshPomodoroWidget();
  }

  Future<void> _loadSettings() async {
    final fs = FocusSettingsService.instance;
    final presetName = await fs.getDefaultPreset();
    final customFocus = await fs.getCustomFocusMinutes();
    final customShort = await fs.getCustomShortBreakMinutes();
    final customLong = await fs.getCustomLongBreakMinutes();
    final customSess = await fs.getCustomSessionsBeforeLongBreak();
    final goalMin = await fs.getDailyGoalMinutes();

    // Restore last subject
    final lastName = await fs.getLastSubjectName();
    StudySubject? lastSubject;
    if (lastName != null) {
      final subjects = await DatabaseHelper.instance.getAllStudySubjects();
      lastSubject = subjects.where((s) => s.name == lastName).firstOrNull;
    }

    _selectedPreset = PomodoroPreset.all.firstWhere(
      (p) => p.name.toLowerCase() == presetName.toLowerCase(),
      orElse: () => PomodoroPreset.classic,
    );

    if (!mounted) return;
    setState(() {
      _customFocus = customFocus;
      _customShortBreak = customShort;
      _customLongBreak = customLong;
      _customSessions = customSess;
      _dailyGoalMinutes = goalMin;
      _selectedSubject = lastName;
      _selectedStudySubject = lastSubject;
      _loading = false;
    });

    _updateDailyProgress();
    _updateWakelock();
  }

  Future<void> _updateDailyProgress() async {
    final today = await DatabaseHelper.instance.getTodayStudyMinutes();
    if (mounted) setState(() => _todayMinutes = today);
  }

  void _updateWakelock() {
    final isRunning = _service.isRunning;
    if (isRunning) {
      FocusSettingsService.instance.getKeepScreenAwake().then((keepAwake) {
        if (keepAwake) WakelockPlus.enable();
      });
    } else {
      WakelockPlus.disable();
    }
  }

  void _checkSessionNote() {
    if (_service.pendingSessionNoteId != null && mounted) {
      _showSessionNoteSheet(_service.pendingSessionNoteId!);
    }
  }

  Future<void> _showSessionNoteSheet(int sessionId) async {
    final controller = TextEditingController();
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Session Note',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What did you accomplish in this focus session?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Solved 5 calculus problems...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();
    _service.dismissSessionNote();

    if (note != null && note.isNotEmpty) {
      await DatabaseHelper.instance.updateSessionNote(sessionId, note);
    }
  }

  Future<void> _openSubjectPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SubjectPickerSheet(
        selectedSubjectName: _selectedSubject,
        onSubjectSelected: (name) {
          setState(() {
            _selectedSubject = name;
            if (name != null) {
              DatabaseHelper.instance.getAllStudySubjects().then((subjects) {
                final match = subjects.where((s) => s.name == name).firstOrNull;
                setState(() => _selectedStudySubject = match);
              });
            } else {
              _selectedStudySubject = null;
            }
          });
        },
      ),
    );
  }

  Future<void> _openFocusSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const FocusSettingsSheet(),
    );
    // Reload settings after sheet closes
    await _loadSettings();
  }

  Future<void> _handleStart() async {
    HapticFeedback.mediumImpact();
    PomodoroPreset preset = _selectedPreset;
    if (_selectedPreset.name == 'Custom') {
      preset = PomodoroPreset(
        name: 'Custom',
        focusMinutes: _customFocus,
        shortBreakMinutes: _customShortBreak,
        longBreakMinutes: _customLongBreak,
        sessionsBeforeLongBreak: _customSessions,
      );
    }
    await _service.start(
      preset: preset,
      subjectTag: _selectedSubject,
      eventId: _selectedEventId,
    );
  }

  Color _phaseColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_service.phase) {
      case PomodoroPhase.focusing:
        return scheme.primary;
      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        return Colors.green;
      case PomodoroPhase.paused:
        return Colors.orange;
      case PomodoroPhase.idle:
        return scheme.primary;
    }
  }

  String _phaseLabel() {
    switch (_service.phase) {
      case PomodoroPhase.focusing:
        return 'Focusing';
      case PomodoroPhase.shortBreak:
        return 'Short Break';
      case PomodoroPhase.longBreak:
        return 'Long Break';
      case PomodoroPhase.paused:
        return 'Paused';
      case PomodoroPhase.idle:
        return 'Ready to Focus';
    }
  }

  double _progressValue() {
    if (_service.phase == PomodoroPhase.idle) return 1.0;
    final total = _service.preset.focusMinutes * 60;
    if (total <= 0) return 1.0;
    return (_service.remainingSeconds / total).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _service.phaseNotifier.removeListener(_onServiceUpdate);
    _service.remainingSecondsNotifier.removeListener(_onServiceUpdate);
    _service.completedSessionsNotifier.removeListener(_onServiceUpdate);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = AppThemes.gradientColorsFor(
      EventCountdownAppState.of(context)?.theme ?? AppThemeOption.auroraBorealis,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Focus',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          // Settings gear
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openFocusSettings,
            tooltip: 'Focus settings',
          ),
          if (_service.completedFocusSessions > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_service.completedFocusSessions}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: gradientColors != null && gradientColors.length >= 2
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          gradientColors[0].withOpacity(0.15),
                          gradientColors[1].withOpacity(0.15),
                        ]
                      : [
                          gradientColors[0].withOpacity(0.08),
                          gradientColors[1].withOpacity(0.08),
                        ],
                )
              : null,
          color: gradientColors == null ? scheme.surface : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ── Subject Selector (tappable card) ──
              if (_service.phase == PomodoroPhase.idle) ...[
                _buildSubjectSelector(scheme),
                const SizedBox(height: 16),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_outline,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _service.subjectTag ?? 'General Study',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Daily Goal Progress ──
              if (_service.phase == PomodoroPhase.idle || _service.phase == PomodoroPhase.paused) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Goal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.outline,
                            ),
                          ),
                          Text(
                            '$_todayMinutes / $_dailyGoalMinutes min',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _dailyGoalMinutes > 0
                              ? (_todayMinutes / _dailyGoalMinutes).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 6,
                          backgroundColor: scheme.outlineVariant.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Preset Pills (only when idle) ──
              if (_service.phase == PomodoroPhase.idle) _buildPresets(scheme),

              const Spacer(),

              // ── Timer Display ──
              _buildTimerDisplay(scheme),

              const Spacer(),

              // ── Controls ──
              _buildControls(scheme),

              const SizedBox(height: 32),

              // ── Phase Label ──
              Text(
                _phaseLabel(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSelector(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: InkWell(
        onTap: _openSubjectPicker,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _selectedStudySubject?.color ?? scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedSubject ?? 'Select subject (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _selectedSubject != null
                        ? scheme.onSurface
                        : scheme.outline,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more,
                color: scheme.outline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresets(ColorScheme scheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: PomodoroPreset.all.map((preset) {
          final isSelected = _selectedPreset.name == preset.name;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(preset.name),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedPreset = preset),
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected ? scheme.primary : Colors.transparent,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimerDisplay(ColorScheme scheme) {
    final isRunning = _service.isRunning;
    final progress = _progressValue();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = (_service.phase == PomodoroPhase.focusing &&
                _service.remainingSeconds < 60)
            ? 1.0 + (_pulseController.value * 0.03)
            : 1.0;

        return Transform.scale(
          scale: pulseScale,
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: scheme.outlineVariant.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                  ),
                ),
                // Progress ring
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(_phaseColor(context)),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Glass center
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: scheme.surface.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outlineVariant.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _service.formattedTime,
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2,
                              color: scheme.onSurface,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          if (_service.phase != PomodoroPhase.idle) ...[
                            const SizedBox(height: 4),
                            Text(
                              _service.phase == PomodoroPhase.paused
                                  ? 'Paused'
                                  : 'Session ${_service.completedFocusSessions + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(ColorScheme scheme) {
    final phase = _service.phase;

    if (phase == PomodoroPhase.idle) {
      return _buildPillButton(
        onTap: _handleStart,
        color: scheme.primary,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              'Start Focus',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (phase == PomodoroPhase.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCircleButton(
            onTap: () => _service.stop(),
            icon: Icons.stop_rounded,
            color: scheme.error,
          ),
          const SizedBox(width: 24),
          _buildPillButton(
            onTap: () => _service.resume(),
            color: scheme.primary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 6),
                Text(
                  'Resume',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Running (focus or break)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(
          onTap: () => _service.pause(),
          icon: Icons.pause_rounded,
          color: scheme.secondaryContainer,
          iconColor: scheme.onSecondaryContainer,
        ),
        const SizedBox(width: 24),
        _buildCircleButton(
          onTap: () => _service.stop(),
          icon: Icons.stop_rounded,
          color: scheme.errorContainer,
          iconColor: scheme.onErrorContainer,
        ),
        if (phase == PomodoroPhase.shortBreak ||
            phase == PomodoroPhase.longBreak) ...[
          const SizedBox(width: 24),
          _buildCircleButton(
            onTap: () => _service.skipBreak(),
            icon: Icons.skip_next_rounded,
            color: scheme.tertiaryContainer,
            iconColor: scheme.onTertiaryContainer,
          ),
        ],
      ],
    );
  }

  Widget _buildPillButton({
    required VoidCallback onTap,
    required Color color,
    required Widget child,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(32),
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    Color? iconColor,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor ?? Colors.white, size: 28),
        ),
      ),
    );
  }
}
