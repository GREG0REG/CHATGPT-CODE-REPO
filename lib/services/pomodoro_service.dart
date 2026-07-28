// CHATGPT-CODE-REPO-TEST/lib/services/pomodoro_service.dart
// COMPLETE REPLACEMENT — NEET Edition v15
// FIXED: Session note popup spam (pendingSessionNoteId cleared atomically)
// NEW: NEET presets, distraction logging, per-phase progress, intensity rating

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../models/study_session.dart';
import 'focus_settings_service.dart';
import 'widget_service.dart';

enum PomodoroPhase { idle, focusing, shortBreak, longBreak, paused }

class PomodoroPreset {
  final String name;
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;

  const PomodoroPreset({
    required this.name,
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.sessionsBeforeLongBreak,
  });

  static const neetRevision = PomodoroPreset(
    name: 'NEET Revision',
    focusMinutes: 90,
    shortBreakMinutes: 15,
    longBreakMinutes: 30,
    sessionsBeforeLongBreak: 3,
  );

  static const neetDeep = PomodoroPreset(
    name: 'NEET Deep',
    focusMinutes: 120,
    shortBreakMinutes: 20,
    longBreakMinutes: 45,
    sessionsBeforeLongBreak: 2,
  );

  static const neetSprint = PomodoroPreset(
    name: 'NEET Sprint',
    focusMinutes: 60,
    shortBreakMinutes: 10,
    longBreakMinutes: 20,
    sessionsBeforeLongBreak: 4,
  );

  static const custom = PomodoroPreset(
    name: 'Custom',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  static const all = [neetRevision, neetDeep, neetSprint, custom];
}

class PomodoroService {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  // SharedPreferences keys — MUST match Kotlin PomodoroWidgetProvider exactly.
  static const String _kPhase = 'pomodoro_phase';
  static const String _kEndTime = 'pomodoro_end_time_millis';
  static const String _kTotalDuration = 'pomodoro_total_duration_seconds';
  static const String _kSubject = 'pomodoro_subject';
  static const String _kStatus = 'pomodoro_status';
  static const String _kSessions = 'pomodoro_completed_sessions';
  static const String _kRemainingSeconds = 'pomodoro_remaining_seconds';
  static const String _kProgressPercent = 'pomodoro_progress_percent';
  static const String _kPresetName = 'pomodoro_preset_name';
  static const String _kFocusMinutes = 'pomodoro_focus_minutes';
  static const String _kShortBreakMinutes = 'pomodoro_short_break_minutes';
  static const String _kLongBreakMinutes = 'pomodoro_long_break_minutes';
  static const String _kSessionsBeforeLong = 'pomodoro_sessions_before_long';
  // NEW keys for NEET features
  static const String _kDistractionCount = 'pomodoro_distraction_count';
  static const String _kIntensityRating = 'pomodoro_intensity_rating';
  static const String _kTopicTag = 'pomodoro_topic_tag';

  Timer? _timer;
  PomodoroPreset _preset = PomodoroPreset.neetRevision;
  PomodoroPhase _phase = PomodoroPhase.idle;
  int _remainingSeconds = 0;
  int _completedFocusSessions = 0;
  String? _subjectTag;
  int? _eventId;
  int? _pendingSessionNoteId;
  int _totalDurationSeconds = 0;
  int _distractionCount = 0;
  int _intensityRating = 0; // 0 = unset, 1-5 = rated
  String? _topicTag;
  bool _noteSheetShown = false; // CRITICAL FIX: prevents duplicate note popups

  // Notifiers for UI updates
  final ValueNotifier<PomodoroPhase> phaseNotifier = ValueNotifier(PomodoroPhase.idle);
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier(0);
  final ValueNotifier<int> completedSessionsNotifier = ValueNotifier(0);
  final ValueNotifier<int> distractionCountNotifier = ValueNotifier(0);

  PomodoroPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  int get completedFocusSessions => _completedFocusSessions;
  String? get subjectTag => _subjectTag;
  int? get pendingSessionNoteId => _pendingSessionNoteId;
  PomodoroPreset get preset => _preset;
  int get distractionCount => _distractionCount;
  int get intensityRating => _intensityRating;
  String? get topicTag => _topicTag;

  bool get isRunning => _phase == PomodoroPhase.focusing ||
                        _phase == PomodoroPhase.shortBreak ||
                        _phase == PomodoroPhase.longBreak;

  String get formattedTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Days remaining until NEET exam (May 2, 2026)
  int get neetDaysRemaining {
    final examDate = DateTime(2026, 5, 2);
    final now = DateTime.now();
    final diff = examDate.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays;
  }

  Future<void> init() async {
    await _restoreState();
  }

  /// CRITICAL FIX: When app returns from background, recalculate from endTime
  Future<void> recalculateFromEndTime() async {
    if (!isRunning && _phase != PomodoroPhase.paused) return;

    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt(_kEndTime) ?? 0;

    if (endTime > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((endTime - now) / 1000).round();

      if (remaining > 0) {
        _remainingSeconds = math.max(0, remaining);
        remainingSecondsNotifier.value = _remainingSeconds;

        final progress = _totalDurationSeconds > 0
            ? ((_totalDurationSeconds - _remainingSeconds) / _totalDurationSeconds * 100).round()
            : 0;

        await prefs.setInt(_kRemainingSeconds, _remainingSeconds);
        await prefs.setInt(_kProgressPercent, progress.clamp(0, 100));

        debugPrint('🔄 Recalculated from endTime: remaining=$_remainingSeconds, progress=$progress');
      } else {
        debugPrint('⏰ Timer expired while in background');
        await _onTimerComplete();
      }
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString(_kPhase) ?? 'idle';
    final endTime = prefs.getInt(_kEndTime) ?? 0;
    final savedPresetName = prefs.getString(_kPresetName) ?? 'NEET Revision';

    _preset = PomodoroPreset.all.firstWhere(
      (p) => p.name == savedPresetName,
      orElse: () => PomodoroPreset.neetRevision,
    );

    _distractionCount = prefs.getInt(_kDistractionCount) ?? 0;
    _intensityRating = prefs.getInt(_kIntensityRating) ?? 0;
    distractionCountNotifier.value = _distractionCount;

    if (endTime > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((endTime - now) / 1000).round();

      if (remaining > 0) {
        _phase = _parsePhase(savedPhase);
        _remainingSeconds = math.max(0, remaining);
        _completedFocusSessions = prefs.getInt(_kSessions) ?? 0;
        _subjectTag = prefs.getString(_kSubject);
        _topicTag = prefs.getString(_kTopicTag);
        _totalDurationSeconds = prefs.getInt(_kTotalDuration) ?? (_getPhaseDurationSeconds(_phase));

        phaseNotifier.value = _phase;
        remainingSecondsNotifier.value = _remainingSeconds;
        completedSessionsNotifier.value = _completedFocusSessions;

        if (isRunning) {
          _startTimer();
          debugPrint('✅ Restored running timer: $_remainingSeconds seconds left');
        } else if (_phase == PomodoroPhase.paused) {
          debugPrint('✅ Restored paused timer: $_remainingSeconds seconds left');
        }
      } else {
        await _clearState();
      }
    }
  }

  int _getPhaseDurationSeconds(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.focusing:
        return _preset.focusMinutes * 60;
      case PomodoroPhase.shortBreak:
        return _preset.shortBreakMinutes * 60;
      case PomodoroPhase.longBreak:
        return _preset.longBreakMinutes * 60;
      default:
        return _preset.focusMinutes * 60;
    }
  }

  PomodoroPhase _parsePhase(String phase) {
    switch (phase) {
      case 'focusing': return PomodoroPhase.focusing;
      case 'shortBreak': return PomodoroPhase.shortBreak;
      case 'longBreak': return PomodoroPhase.longBreak;
      case 'paused': return PomodoroPhase.paused;
      default: return PomodoroPhase.idle;
    }
  }

  String _phaseToString(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.focusing: return 'focusing';
      case PomodoroPhase.shortBreak: return 'shortBreak';
      case PomodoroPhase.longBreak: return 'longBreak';
      case PomodoroPhase.paused: return 'paused';
      case PomodoroPhase.idle: return 'idle';
    }
  }

  String _getStatusText(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.focusing: return 'Focus';
      case PomodoroPhase.shortBreak: return 'Short Break';
      case PomodoroPhase.longBreak: return 'Long Break';
      case PomodoroPhase.paused: return 'Paused';
      case PomodoroPhase.idle: return 'Ready';
    }
  }

  /// NEW: Get total duration for current phase (fixes break progress bug)
  int _getCurrentPhaseTotalSeconds() {
    switch (_phase) {
      case PomodoroPhase.focusing:
        return _preset.focusMinutes * 60;
      case PomodoroPhase.shortBreak:
        return _preset.shortBreakMinutes * 60;
      case PomodoroPhase.longBreak:
        return _preset.longBreakMinutes * 60;
      case PomodoroPhase.paused:
        return _totalDurationSeconds > 0 ? _totalDurationSeconds : _preset.focusMinutes * 60;
      case PomodoroPhase.idle:
        return _preset.focusMinutes * 60;
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();

    final endTime = isRunning
        ? DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000)
        : 0;

    // FIX: Use per-phase total duration instead of always focusMinutes
    final totalDuration = _getCurrentPhaseTotalSeconds();
    _totalDurationSeconds = totalDuration;

    await prefs.setString(_kPhase, _phaseToString(_phase));
    await prefs.setInt(_kEndTime, endTime);
    await prefs.setInt(_kTotalDuration, totalDuration);
    await prefs.setString(_kSubject, _subjectTag ?? 'Ready to Focus');
    await prefs.setString(_kStatus, _getStatusText(_phase));
    await prefs.setInt(_kSessions, _completedFocusSessions);
    await prefs.setInt(_kRemainingSeconds, _remainingSeconds);
    await prefs.setString(_kPresetName, _preset.name);
    await prefs.setInt(_kFocusMinutes, _preset.focusMinutes);
    await prefs.setInt(_kShortBreakMinutes, _preset.shortBreakMinutes);
    await prefs.setInt(_kLongBreakMinutes, _preset.longBreakMinutes);
    await prefs.setInt(_kSessionsBeforeLong, _preset.sessionsBeforeLongBreak);
    await prefs.setInt(_kDistractionCount, _distractionCount);
    await prefs.setInt(_kIntensityRating, _intensityRating);
    if (_topicTag != null) {
      await prefs.setString(_kTopicTag, _topicTag!);
    } else {
      await prefs.remove(_kTopicTag);
    }

    final progress = totalDuration > 0
        ? ((totalDuration - _remainingSeconds) / totalDuration * 100).round()
        : 0;
    await prefs.setInt(_kProgressPercent, progress.clamp(0, 100));

    debugPrint('💾 Persisted: phase=${_phaseToString(_phase)}, endTime=$endTime, remaining=$_remainingSeconds, progress=$progress, totalDuration=$totalDuration');
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPhase);
    await prefs.remove(_kEndTime);
    await prefs.remove(_kTotalDuration);
    await prefs.remove(_kSubject);
    await prefs.remove(_kStatus);
    await prefs.remove(_kSessions);
    await prefs.remove(_kRemainingSeconds);
    await prefs.remove(_kProgressPercent);
    await prefs.remove(_kPresetName);
    await prefs.remove(_kFocusMinutes);
    await prefs.remove(_kShortBreakMinutes);
    await prefs.remove(_kLongBreakMinutes);
    await prefs.remove(_kSessionsBeforeLong);
    await prefs.remove(_kDistractionCount);
    await prefs.remove(_kIntensityRating);
    await prefs.remove(_kTopicTag);
    _noteSheetShown = false;
    _distractionCount = 0;
    _intensityRating = 0;
    _topicTag = null;
    distractionCountNotifier.value = 0;
  }

  Future<void> start({
    required PomodoroPreset preset,
    String? subjectTag,
    String? topicTag,
    int? eventId,
  }) async {
    _preset = preset;
    _subjectTag = subjectTag;
    _topicTag = topicTag;
    _eventId = eventId;
    _completedFocusSessions = 0;
    _pendingSessionNoteId = null;
    _noteSheetShown = false;
    _distractionCount = 0;
    _intensityRating = 0;
    distractionCountNotifier.value = 0;

    await _startFocus();
  }

  Future<void> _startFocus() async {
    _phase = PomodoroPhase.focusing;
    _remainingSeconds = _preset.focusMinutes * 60;
    _totalDurationSeconds = _remainingSeconds;

    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = _remainingSeconds;

    await _persistState();
    _startTimer();
    await WidgetService.refreshPomodoroWidget();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      final endTime = prefs.getInt(_kEndTime) ?? 0;

      if (endTime > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final newRemaining = ((endTime - now) / 1000).round();

        if (newRemaining > 0) {
          _remainingSeconds = math.max(0, newRemaining);
          remainingSecondsNotifier.value = _remainingSeconds;

          if (_remainingSeconds % 5 == 0) {
            await _persistState();
            await WidgetService.refreshPomodoroWidget();
          }
        } else {
          await _onTimerComplete();
        }
      } else {
        await _onTimerComplete();
      }
    });
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();

    if (_phase == PomodoroPhase.focusing) {
      _completedFocusSessions++;
      completedSessionsNotifier.value = _completedFocusSessions;

      await _logSession();

      if (_completedFocusSessions % _preset.sessionsBeforeLongBreak == 0) {
        await _startLongBreak();
      } else {
        await _startShortBreak();
      }
    } else {
      await _startFocus();
    }
  }

  Future<void> _logSession() async {
    final session = StudySession(
      eventId: _eventId,
      subjectTag: _subjectTag,
      durationMinutes: _preset.focusMinutes,
      completedAtMillis: DateTime.now().millisecondsSinceEpoch,
      sessionType: _preset.name.toLowerCase().replaceAll(' ', '_'),
      notes: _topicTag != null ? 'Topic: $_topicTag\nDistractions: $_distractionCount' : 'Distractions: $_distractionCount',
    );

    final id = await DatabaseHelper.instance.insertStudySession(session);
    _pendingSessionNoteId = id;
    _noteSheetShown = false; // Reset so it can be shown once

    if (_subjectTag != null) {
      final subjects = await DatabaseHelper.instance.getAllStudySubjects();
      final match = subjects.where((s) => s.name == _subjectTag).firstOrNull;
      if (match?.id != null) {
        await DatabaseHelper.instance.addSubjectFocusMinutes(match!.id!, _preset.focusMinutes);
      }
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    await DatabaseHelper.instance.addAchievedMinutes(startOfDay, _preset.focusMinutes);
    await DatabaseHelper.instance.addAchievedPomodoro(startOfDay);
  }

  Future<void> pause() async {
    _timer?.cancel();
    _phase = PomodoroPhase.paused;
    phaseNotifier.value = _phase;
    await _persistState();
    await WidgetService.refreshPomodoroWidget();
  }

  Future<void> resume() async {
    if (_phase == PomodoroPhase.paused) {
      _phase = PomodoroPhase.focusing;
      phaseNotifier.value = _phase;
      await _persistState();
      _startTimer();
      await WidgetService.refreshPomodoroWidget();
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _phase = PomodoroPhase.idle;
    _remainingSeconds = 0;
    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = 0;
    await _clearState();
    await WidgetService.refreshPomodoroWidget();
  }

  Future<void> skipBreak() async {
    _timer?.cancel();
    await _startFocus();
  }

  /// NEW: Log a distraction during focus
  void logDistraction() {
    if (_phase != PomodoroPhase.focusing) return;
    _distractionCount++;
    distractionCountNotifier.value = _distractionCount;
    debugPrint('😵 Distraction logged: count=$_distractionCount');
  }

  /// NEW: Set intensity rating for completed session
  void setIntensityRating(int rating) {
    _intensityRating = rating.clamp(1, 5);
  }

  /// CRITICAL FIX: Atomically consume the pending note ID so popup shows once
  int? consumePendingSessionNote() {
    if (_noteSheetShown) return null;
    final id = _pendingSessionNoteId;
    if (id != null) {
      _noteSheetShown = true;
    }
    return id;
  }

  void dismissSessionNote() {
    _pendingSessionNoteId = null;
    _noteSheetShown = false;
  }

  void dispose() {
    _timer?.cancel();
    phaseNotifier.dispose();
    remainingSecondsNotifier.dispose();
    completedSessionsNotifier.dispose();
    distractionCountNotifier.dispose();
  }
}
