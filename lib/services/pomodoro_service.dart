// CHATGPT-CODE-REPO-TEST/lib/services/pomodoro_service.dart
// COMPLETE FILE - Pomodoro Timer Service with LIVE WIDGET support
// Now persists end-time so widget can calculate remaining time independently

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database_helper.dart';
import '../models/study_session.dart';
import '../services/focus_settings_service.dart';
import '../services/widget_service.dart';

/// Timer phases for the Pomodoro cycle
enum PomodoroPhase {
  idle,
  focusing,
  shortBreak,
  longBreak,
  paused,
}

/// A preset configuration for Pomodoro timer sessions
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

  /// Total duration in seconds for a focus session
  int get focusSeconds => focusMinutes * 60;

  /// Total duration in seconds for a short break
  int get shortBreakSeconds => shortBreakMinutes * 60;

  /// Total duration in seconds for a long break
  int get longBreakSeconds => longBreakMinutes * 60;

  /// All built-in presets
  static const List<PomodoroPreset> all = [
    classic,
    deepWork,
    examCrunch,
    custom,
  ];

  static const PomodoroPreset classic = PomodoroPreset(
    name: 'Classic',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  static const PomodoroPreset deepWork = PomodoroPreset(
    name: 'Deep Work',
    focusMinutes: 50,
    shortBreakMinutes: 10,
    longBreakMinutes: 30,
    sessionsBeforeLongBreak: 2,
  );

  static const PomodoroPreset examCrunch = PomodoroPreset(
    name: 'Exam Crunch',
    focusMinutes: 45,
    shortBreakMinutes: 5,
    longBreakMinutes: 20,
    sessionsBeforeLongBreak: 3,
  );

  static const PomodoroPreset custom = PomodoroPreset(
    name: 'Custom',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  @override
  String toString() => name;
}

/// Service that manages the Pomodoro timer state and session tracking
/// Now supports LIVE widget updates even when app is backgrounded/killed
class PomodoroService {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  Timer? _timer;

  // ── State ──
  PomodoroPhase _phase = PomodoroPhase.idle;
  PomodoroPreset _preset = PomodoroPreset.classic;
  int _remainingSeconds = 0;
  int _completedFocusSessions = 0;
  String? _subjectTag;
  int? _eventId;
  int? _pendingSessionNoteId;

  // End-time based tracking for live widget support
  int? _endTimeMillis;
  int _totalDurationSeconds = 0;

  // ── Notifiers ──
  final ValueNotifier<PomodoroPhase> phaseNotifier = ValueNotifier<PomodoroPhase>(PomodoroPhase.idle);
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> completedSessionsNotifier = ValueNotifier<int>(0);

  // ── Public getters ──
  PomodoroPhase get phase => _phase;
  PomodoroPreset get preset => _preset;
  int get remainingSeconds => _remainingSeconds;
  int get completedFocusSessions => _completedFocusSessions;
  String? get subjectTag => _subjectTag;
  int? get pendingSessionNoteId => _pendingSessionNoteId;
  bool get isRunning => _phase == PomodoroPhase.focusing || _phase == PomodoroPhase.shortBreak || _phase == PomodoroPhase.longBreak;

  /// Formatted time string (MM:SS)
  String get formattedTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> init() async {
    // Load any persisted state if needed
    final prefs = await SharedPreferences.getInstance();
    _completedFocusSessions = prefs.getInt('pomodoro_completed_sessions_total') ?? 0;

    // Try to restore active timer state if app was killed
    await _restoreStateIfNeeded();
  }

  /// Restore timer state if there was an active session when app was killed
  Future<void> _restoreStateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString('pomodoro_phase');
    final savedEndTime = prefs.getInt('pomodoro_end_time_millis');

    if (savedPhase != null && savedPhase != 'idle' && savedEndTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((savedEndTime - now) / 1000).ceil();

      if (remaining > 0) {
        // Timer is still running! Restore it.
        _phase = PomodoroPhase.values.firstWhere(
          (p) => p.name == savedPhase,
          orElse: () => PomodoroPhase.idle,
        );
        _remainingSeconds = remaining;
        _endTimeMillis = savedEndTime;
        _totalDurationSeconds = prefs.getInt('pomodoro_total_duration_seconds') ?? _preset.focusSeconds;
        _completedFocusSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;
        _subjectTag = prefs.getString('pomodoro_subject');

        _updateNotifiers();
        _startTimer();
      } else {
        // Timer expired while app was killed - clean up
        await _clearPomodoroState();
      }
    }
  }

  /// Start a new Pomodoro session
  Future<void> start({
    required PomodoroPreset preset,
    String? subjectTag,
    int? eventId,
  }) async {
    _preset = preset;
    _subjectTag = subjectTag;
    _eventId = eventId;
    _phase = PomodoroPhase.focusing;
    _remainingSeconds = preset.focusSeconds;
    _totalDurationSeconds = preset.focusSeconds;
    _endTimeMillis = DateTime.now().millisecondsSinceEpoch + (preset.focusSeconds * 1000);

    _updateNotifiers();
    await _savePomodoroState();
    _startTimer();

    // Trigger immediate widget update
    WidgetService.refreshPomodoroWidget();
  }

  /// Pause the current session
  void pause() {
    if (_phase == PomodoroPhase.focusing ||
        _phase == PomodoroPhase.shortBreak ||
        _phase == PomodoroPhase.longBreak) {
      _phase = PomodoroPhase.paused;
      _timer?.cancel();
      _endTimeMillis = null; // Clear end time when paused
      _updateNotifiers();
      _savePomodoroState();
      WidgetService.refreshPomodoroWidget();
    }
  }

  /// Resume from pause
  void resume() {
    if (_phase == PomodoroPhase.paused) {
      // Determine which phase to resume to based on remaining time vs preset
      if (_remainingSeconds <= _preset.shortBreakSeconds &&
          _remainingSeconds > 0 &&
          _completedFocusSessions > 0 &&
          _completedFocusSessions % _preset.sessionsBeforeLongBreak != 0) {
        _phase = PomodoroPhase.shortBreak;
        _totalDurationSeconds = _preset.shortBreakSeconds;
      } else if (_remainingSeconds <= _preset.longBreakSeconds &&
          _remainingSeconds > 0 &&
          _completedFocusSessions > 0 &&
          _completedFocusSessions % _preset.sessionsBeforeLongBreak == 0) {
        _phase = PomodoroPhase.longBreak;
        _totalDurationSeconds = _preset.longBreakSeconds;
      } else {
        _phase = PomodoroPhase.focusing;
        _totalDurationSeconds = _preset.focusSeconds;
      }

      _endTimeMillis = DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);
      _startTimer();
      _updateNotifiers();
      _savePomodoroState();
      WidgetService.refreshPomodoroWidget();
    }
  }

  /// Stop and reset the timer
  Future<void> stop() async {
    _timer?.cancel();
    _phase = PomodoroPhase.idle;
    _remainingSeconds = 0;
    _endTimeMillis = null;
    _updateNotifiers();
    await _clearPomodoroState();
    WidgetService.refreshPomodoroWidget();
  }

  /// Skip the current break and go to next focus session
  void skipBreak() {
    if (_phase == PomodoroPhase.shortBreak || _phase == PomodoroPhase.longBreak) {
      _timer?.cancel();
      _startFocusSession();
    }
  }

  /// Dismiss the session note prompt
  void dismissSessionNote() {
    _pendingSessionNoteId = null;
  }

  // ── Internal timer logic ──

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endTimeMillis != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remaining = ((_endTimeMillis! - now) / 1000).ceil();

        if (remaining > 0) {
          _remainingSeconds = remaining;
          remainingSecondsNotifier.value = _remainingSeconds;
          _savePomodoroState();
        } else {
          _remainingSeconds = 0;
          remainingSecondsNotifier.value = 0;
          _onPhaseComplete();
        }
      } else {
        // Fallback if endTime not set
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          remainingSecondsNotifier.value = _remainingSeconds;
          _savePomodoroState();
        } else {
          _onPhaseComplete();
        }
      }
    });
  }

  void _onPhaseComplete() async {
    _timer?.cancel();

    switch (_phase) {
      case PomodoroPhase.focusing:
        // Focus session complete - log it
        _completedFocusSessions++;
        completedSessionsNotifier.value = _completedFocusSessions;

        final session = StudySession(
          eventId: _eventId,
          subjectTag: _subjectTag,
          durationMinutes: _preset.focusMinutes,
          completedAtMillis: DateTime.now().millisecondsSinceEpoch,
          sessionType: 'pomodoro',
        );

        final id = await DatabaseHelper.instance.insertStudySession(session);
        _pendingSessionNoteId = id;

        // Update daily goal
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        await DatabaseHelper.instance.addAchievedMinutes(startOfDay, _preset.focusMinutes);
        await DatabaseHelper.instance.addAchievedPomodoro(startOfDay);

        // Update subject focus time if applicable
        if (_subjectTag != null) {
          final subjects = await DatabaseHelper.instance.getAllStudySubjects();
          final match = subjects.where((s) => s.name == _subjectTag).firstOrNull;
          if (match != null && match.id != null) {
            await DatabaseHelper.instance.addSubjectFocusMinutes(match.id!, _preset.focusMinutes);
          }
        }

        // Determine next phase
        if (_completedFocusSessions % _preset.sessionsBeforeLongBreak == 0) {
          _phase = PomodoroPhase.longBreak;
          _remainingSeconds = _preset.longBreakSeconds;
          _totalDurationSeconds = _preset.longBreakSeconds;
        } else {
          _phase = PomodoroPhase.shortBreak;
          _remainingSeconds = _preset.shortBreakSeconds;
          _totalDurationSeconds = _preset.shortBreakSeconds;
        }
        _endTimeMillis = DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

        // Auto-start break if enabled
        final autoBreak = await FocusSettingsService.instance.getAutoStartBreak();
        if (autoBreak) {
          _startTimer();
        } else {
          _phase = PomodoroPhase.paused;
          _endTimeMillis = null;
        }
        break;

      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        // Break complete - back to focus
        _startFocusSession();
        break;

      case PomodoroPhase.paused:
      case PomodoroPhase.idle:
        break;
    }

    _updateNotifiers();
    await _savePomodoroState();
    WidgetService.refreshPomodoroWidget();

    // Play completion sound if enabled
    final soundEnabled = await FocusSettingsService.instance.getTimerSoundEnabled();
    if (soundEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _startFocusSession() {
    _phase = PomodoroPhase.focusing;
    _remainingSeconds = _preset.focusSeconds;
    _totalDurationSeconds = _preset.focusSeconds;
    _endTimeMillis = DateTime.now().millisecondsSinceEpoch + (_preset.focusSeconds * 1000);
    _startTimer();
  }

  void _updateNotifiers() {
    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = _remainingSeconds;
    completedSessionsNotifier.value = _completedFocusSessions;
  }

  // ── Persistence ──
  // Now saves END TIME so widget can calculate remaining independently

  Future<void> _savePomodoroState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pomodoro_phase', _phase.name);
    await prefs.setInt('pomodoro_remaining_seconds', _remainingSeconds);
    await prefs.setInt('pomodoro_completed_sessions', _completedFocusSessions);
    await prefs.setString('pomodoro_preset_name', _preset.name);
    await prefs.setString('pomodoro_subject', _subjectTag ?? 'General Study');
    await prefs.setString('pomodoro_status', _phaseLabel());
    await prefs.setInt('pomodoro_total_duration_seconds', _totalDurationSeconds);
    await prefs.setInt('pomodoro_completed_sessions_total', _completedFocusSessions);

    // KEY: Save end time for live widget calculation
    if (_endTimeMillis != null) {
      await prefs.setInt('pomodoro_end_time_millis', _endTimeMillis!);
    } else {
      await prefs.remove('pomodoro_end_time_millis');
    }
  }

  Future<void> _clearPomodoroState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pomodoro_phase');
    await prefs.remove('pomodoro_remaining_seconds');
    await prefs.remove('pomodoro_completed_sessions');
    await prefs.remove('pomodoro_preset_name');
    await prefs.remove('pomodoro_subject');
    await prefs.remove('pomodoro_status');
    await prefs.remove('pomodoro_total_duration_seconds');
    await prefs.remove('pomodoro_end_time_millis');
    _endTimeMillis = null;
    _pendingSessionNoteId = null;
  }

  String _phaseLabel() {
    switch (_phase) {
      case PomodoroPhase.focusing:
        return 'Focus';
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

  double _progressPercent() {
    if (_phase == PomodoroPhase.idle || _totalDurationSeconds <= 0) return 0.0;
    return 1.0 - (_remainingSeconds / _totalDurationSeconds);
  }
}
