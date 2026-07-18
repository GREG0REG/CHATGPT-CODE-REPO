import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../main.dart';
import '../models/event.dart';
import '../services/pomodoro_service.dart';
import '../theme/app_themes.dart';

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
  int? _selectedEventId;
  List<String> _subjects = [];
  bool _loadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _service = PomodoroService.instance;
    _service.init();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadSubjects();

    // Listen to service changes
    _service.phaseNotifier.addListener(_onServiceUpdate);
    _service.remainingSecondsNotifier.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSubjects() async {
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final set = <String>{};
    for (final e in events) {
      if (e.subjectTag != null && e.subjectTag!.trim().isNotEmpty) {
        set.add(e.subjectTag!.trim());
      }
    }
    if (mounted) {
      setState(() {
        _subjects = set.toList()..sort();
        _loadingSubjects = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _service.phaseNotifier.removeListener(_onServiceUpdate);
    _service.remainingSecondsNotifier.removeListener(_onServiceUpdate);
    super.dispose();
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

  Future<void> _handleStart() async {
    HapticFeedback.mediumImpact();
    await _service.start(
      preset: _selectedPreset,
      subjectTag: _selectedSubject,
      eventId: _selectedEventId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = AppThemes.gradientColorsFor(
      EventCountdownAppState.of(context)?.theme ?? AppThemeOption.defaultBlue,
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

              // ── Subject Selector ──
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
    if (_loadingSubjects) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedSubject,
            hint: const Text('Select subject (optional)'),
            icon: const Icon(Icons.expand_more),
            borderRadius: BorderRadius.circular(12),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('General Study'),
              ),
              ..._subjects.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  )),
            ],
            onChanged: (v) => setState(() => _selectedSubject = v),
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
                    valueColor: AlwaysStoppedAnimation(Colors.transparent),
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
