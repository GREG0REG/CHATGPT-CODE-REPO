// FILE: lib/screens/pomodoro_screen.dart
// COMPLETE REPLACEMENT — NEET Edition v15
// Redesigned: NEET countdown banner, distraction counter, intensity rating,
// topic tag picker, subject-wise daily goals, enhanced timer UI

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
import 'main_screen.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PomodoroService _service;
  late final AnimationController _pulseController;
  late final AnimationController _breathController;

  PomodoroPreset _selectedPreset = PomodoroPreset.neetRevision;
  String? _selectedSubject;
  StudySubject? _selectedStudySubject;
  int? _selectedEventId;
  String? _topicTag;

  int _customFocus = 90;
  int _customShortBreak = 15;
  int _customLongBreak = 30;
  int _customSessions = 3;

  int _dailyGoalMinutes = 360;
  int _todayMinutes = 0;
  int _todayPomodoros = 0;

  bool _loading = true;
  bool _showIntensitySheet = false;

  // Subject-wise daily tracking
  final Map<String, int> _subjectTodayMinutes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _service = PomodoroService.instance;
    _service.init();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _loadSettings();

    _service.phaseNotifier.addListener(_onServiceUpdate);
    _service.remainingSecondsNotifier.addListener(_onServiceUpdate);
    _service.completedSessionsNotifier.addListener(_onServiceUpdate);
    _service.distractionCountNotifier.addListener(_onServiceUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 App lifecycle: $state');

    if (state == AppLifecycleState.resumed) {
      _service.recalculateFromEndTime();
      _updateDailyProgress();
    }
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

    final lastName = await fs.getLastSubjectName();
    StudySubject? lastSubject;
    if (lastName != null) {
      final subjects = await DatabaseHelper.instance.getAllStudySubjects();
      lastSubject = subjects.where((s) => s.name == lastName).firstOrNull;
    }

    _selectedPreset = PomodoroPreset.all.firstWhere(
      (p) => p.name.toLowerCase() == presetName.toLowerCase(),
      orElse: () => PomodoroPreset.neetRevision,
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
    final goal = await DatabaseHelper.instance.getTodayDailyGoal();

    // Get subject-wise breakdown
    final sessions = await DatabaseHelper.instance.getStudySessions(limit: 50);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    final Map<String, int> subjectMinutes = {};
    int pomodoroCount = 0;
    for (final s in sessions) {
      if (s.completedAtMillis >= startOfDay && s.completedAtMillis < endOfDay) {
        final subj = s.subjectTag ?? 'General';
        subjectMinutes[subj] = (subjectMinutes[subj] ?? 0) + s.durationMinutes;
        if (s.sessionType.contains('neet') || s.sessionType == 'pomodoro') {
          pomodoroCount++;
        }
      }
    }

    if (mounted) {
      setState(() {
        _todayMinutes = today;
        _todayPomodoros = pomodoroCount;
        _subjectTodayMinutes.clear();
        _subjectTodayMinutes.addAll(subjectMinutes);
      });
    }
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
    // CRITICAL FIX: Use consumePendingSessionNote() to prevent spam
    final sessionId = _service.consumePendingSessionNote();
    if (sessionId != null && mounted) {
      _showIntensityRatingSheet(sessionId);
    }
  }

  Future<void> _showIntensityRatingSheet(int sessionId) async {
    int selectedRating = 3;
    final noteController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                      const SizedBox(height: 20),
                      Text(
                        'Session Complete! 🔥',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How focused were you?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(ctx).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starNum = index + 1;
                          return IconButton(
                            onPressed: () => setModalState(() => selectedRating = starNum),
                            icon: Icon(
                              starNum <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: starNum <= selectedRating ? Colors.amber : Theme.of(ctx).colorScheme.outline,
                              size: 36,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          selectedRating == 1 ? 'Distracted' :
                          selectedRating == 2 ? 'Low Focus' :
                          selectedRating == 3 ? 'Moderate' :
                          selectedRating == 4 ? 'High Focus' : 'Flow State',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'What did you accomplish? (optional)',
                          prefixIcon: const Icon(Icons.edit_note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, {
                            'rating': selectedRating,
                            'note': noteController.text.trim(),
                          }),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Save Session', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    _service.dismissSessionNote();

    if (result != null) {
      _service.setIntensityRating(result['rating'] as int);
      final note = result['note'] as String;
      if (note.isNotEmpty) {
        await DatabaseHelper.instance.updateSessionNote(sessionId, note);
      }
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

  Future<void> _openTopicPicker() async {
    final topics = {
      'Physics': ['Mechanics', 'Electrodynamics', 'Modern Physics', 'Thermodynamics', 'Optics', 'Waves'],
      'Chemistry': ['Organic', 'Inorganic', 'Physical', 'Coordination', 'Environmental'],
      'Biology': ['Zoology', 'Botany', 'Human Physiology', 'Genetics', 'Ecology', 'Cell Biology'],
      'General': ['Revision', 'Mock Test', 'Previous Year', 'Formula Sheet', 'Notes Making'],
    };

    final subjectKey = _selectedSubject ?? 'General';
    final topicList = topics[subjectKey] ?? topics['General']!;

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Topic',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'for $subjectKey',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topicList.map((topic) {
                    final isSelected = _topicTag == topic;
                    return ActionChip(
                      label: Text(topic),
                      onPressed: () => Navigator.pop(ctx, topic),
                      backgroundColor: isSelected
                          ? Theme.of(ctx).colorScheme.primaryContainer
                          : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(ctx).colorScheme.primary
                            : Colors.transparent,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _topicTag = selected);
    }
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
      topicTag: _topicTag,
      eventId: _selectedEventId,
    );
  }

  Color _phaseColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_service.phase) {
      case PomodoroPhase.focusing:
        return const Color(0xFF5B6EF5); // Deep indigo for NEET focus
      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        return const Color(0xFF00C9A7); // Teal for breaks
      case PomodoroPhase.paused:
        return const Color(0xFFFFA726); // Orange for paused
      case PomodoroPhase.idle:
        return scheme.primary;
    }
  }

  String _phaseLabel() {
    switch (_service.phase) {
      case PomodoroPhase.focusing:
        return 'Deep Focus';
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
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _breathController.dispose();
    _service.phaseNotifier.removeListener(_onServiceUpdate);
    _service.remainingSecondsNotifier.removeListener(_onServiceUpdate);
    _service.completedSessionsNotifier.removeListener(_onServiceUpdate);
    _service.distractionCountNotifier.removeListener(_onServiceUpdate);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'NEET Focus',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openFocusSettings,
            tooltip: 'Focus settings',
          ),
          if (_service.completedFocusSessions > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_service.completedFocusSessions}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F0F23), const Color(0xFF1A1A2E)]
                : [const Color(0xFFF8F9FF), const Color(0xFFEEF0FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── NEET Exam Countdown Banner ──
                _buildNeetBanner(scheme),

                const SizedBox(height: 16),

                // ── Subject & Topic Selector ──
                if (_service.phase == PomodoroPhase.idle) ...[
                  _buildSubjectSelector(scheme),
                  const SizedBox(height: 8),
                  _buildTopicChip(scheme),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildActiveSubjectBadge(scheme),
                  const SizedBox(height: 16),
                ],

                // ── Daily Goal Dashboard ──
                _buildDailyDashboard(scheme),

                const SizedBox(height: 20),

                // ── Preset Selector ──
                if (_service.phase == PomodoroPhase.idle) _buildPresets(scheme),

                const SizedBox(height: 24),

                // ── Timer Display ──
                _buildTimerDisplay(scheme),

                const SizedBox(height: 24),

                // ── Distraction Counter (during focus) ──
                if (_service.phase == PomodoroPhase.focusing)
                  _buildDistractionCounter(scheme),

                // ── Controls ──
                _buildControls(scheme),

                const SizedBox(height: 16),

                Text(
                  _phaseLabel(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Subject-wise Progress ──
                if (_subjectTodayMinutes.isNotEmpty)
                  _buildSubjectProgress(scheme),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeetBanner(ColorScheme scheme) {
    final days = _service.neetDaysRemaining;
    final isUrgent = days <= 30;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
              : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? const Color(0xFFFF6B6B) : const Color(0xFF667EEA)).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEET 2026',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days > 0 ? '$days days remaining' : 'Exam Day!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              days > 0 ? '${(days / 7).floor()}w ${days % 7}d' : 'TODAY',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedSubject ?? 'Select Subject',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedSubject != null ? scheme.onSurface : scheme.outline,
                      ),
                    ),
                    if (_selectedSubject != null)
                      Text(
                        'Tap to change',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.outline.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: scheme.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicChip(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.label_outline, size: 16),
            label: Text(_topicTag ?? 'Add Topic'),
            onPressed: _openTopicPicker,
            backgroundColor: _topicTag != null
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withOpacity(0.5),
            side: BorderSide(
              color: _topicTag != null ? scheme.primary : Colors.transparent,
            ),
          ),
          if (_topicTag != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: scheme.outline),
              onPressed: () => setState(() => _topicTag = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSubjectBadge(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _phaseColor(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _phaseColor(context).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 16, color: _phaseColor(context)),
            const SizedBox(width: 6),
            Text(
              _service.subjectTag ?? 'General Study',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (_service.topicTag != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _service.topicTag!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDashboard(ColorScheme scheme) {
    final progress = _dailyGoalMinutes > 0
        ? (_todayMinutes / _dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;
    final isGoalMet = _todayMinutes >= _dailyGoalMinutes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isGoalMet ? Icons.emoji_events_rounded : Icons.track_changes_rounded,
                    size: 18,
                    color: isGoalMet ? Colors.amber : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Target',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '$_todayMinutes / $_dailyGoalMinutes min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isGoalMet ? Colors.green : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: scheme.outlineVariant.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isGoalMet ? Colors.green : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat(Icons.timer_outlined, '$_todayMinutes', 'min today'),
              _buildMiniStat(Icons.local_fire_department_outlined, '$_todayPomodoros', 'sessions'),
              _buildMiniStat(Icons.bolt_outlined, '${_dailyGoalMinutes - _todayMinutes > 0 ? _dailyGoalMinutes - _todayMinutes : 0}', 'min left'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildPresets(ColorScheme scheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: PomodoroPreset.all.map((preset) {
          final isSelected = _selectedPreset.name == preset.name;
          final isNeet = preset.name.startsWith('NEET');
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNeet)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(preset.name),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedPreset = preset),
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
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
    final phaseColor = _phaseColor(context);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = (_service.phase == PomodoroPhase.focusing &&
                _service.remainingSeconds < 60)
            ? 1.0 + (_pulseController.value * 0.04)
            : 1.0;

        return Transform.scale(
          scale: pulseScale,
          child: SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                if (_service.phase == PomodoroPhase.focusing)
                  AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, child) {
                      return Container(
                        width: 300 + (_breathController.value * 20),
                        height: 300 + (_breathController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: phaseColor.withOpacity(0.1 - (_breathController.value * 0.05)),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                // Background track
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    backgroundColor: scheme.outlineVariant.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                  ),
                ),
                // Progress ring
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(phaseColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Inner glass circle
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.surface.withOpacity(0.6),
                            scheme.surface.withOpacity(0.3),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outlineVariant.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _service.formattedTime,
                            style: TextStyle(
                              fontSize: 68,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 2,
                              color: scheme.onSurface,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (_service.phase != PomodoroPhase.idle) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: phaseColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _service.phase == PomodoroPhase.paused
                                    ? 'Paused'
                                    : 'Session ${_service.completedFocusSessions + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: phaseColor,
                                  fontWeight: FontWeight.w600,
                                ),
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

  Widget _buildDistractionCounter(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_alt_outlined, color: Color(0xFFFF9800), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distractions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  _service.distractionCount == 0
                      ? 'Stay focused! Tap + if distracted'
                      : '${_service.distractionCount} distraction${_service.distractionCount > 1 ? 's' : ''} logged',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _service.logDistraction();
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Color(0xFFFF9800), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ColorScheme scheme) {
    final phase = _service.phase;

    if (phase == PomodoroPhase.idle) {
      return _buildPillButton(
        onTap: _handleStart,
        color: const Color(0xFF5B6EF5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              'Start Focus Session',
              style: TextStyle(
                fontSize: 17,
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
            color: const Color(0xFF5B6EF5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
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

  Widget _buildSubjectProgress(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Subject Breakdown",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ..._subjectTodayMinutes.entries.map((entry) {
            final subject = entry.key;
            final minutes = entry.value;
            final target = 120; // 2 hours per subject default
            final pct = (minutes / target).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      subject,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: scheme.outlineVariant.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct >= 1.0 ? Colors.green : scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${minutes}m',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
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
      elevation: 6,
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
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
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor ?? Colors.white, size: 28),
        ),
      ),
    );
  }
}
