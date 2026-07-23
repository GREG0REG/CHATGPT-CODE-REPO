// CHATGPT-CODE-REPO-TEST/lib/services/pomodoro_service.dart
// COMPLETE FILE - Fixed timer state persistence for widget updates
// Uses SharedPreferences keys that match Kotlin PomodoroWidgetProvider

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

  static const classic = PomodoroPreset(
    name: 'Classic',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  static const deepWork = PomodoroPreset(
    name: 'Deep Work',
    focusMinutes: 50,
    shortBreakMinutes: 10,
    longBreakMinutes: 30,
    sessionsBeforeLongBreak: 3,
  );

  static const examCrunch = PomodoroPreset(
    name: 'Exam Crunch',
    focusMinutes: 45,
    shortBreakMinutes: 5,
    longBreakMinutes: 20,
    sessionsBeforeLongBreak: 6,
  );

  static const custom = PomodoroPreset(
    name: 'Custom',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  static const all = [classic, deepWork, examCrunch, custom];
}

class PomodoroService {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  // SharedPreferences keys - MUST match Kotlin PomodoroWidgetProvider exactly
  static const String _kPhase = 'flutter.pomodoro_phase';
  static const String _kEndTime = 'flutter.pomodoro_end_time_millis';
  static const String _kTotalDuration = 'flutter.pomodoro_total_duration_seconds';
  static const String _kSubject = 'flutter.pomodoro_subject';
  static const String _kStatus = 'flutter.pomodoro_status';
  static const String _kBgColor = 'flutter.pomodoro_bg_color';
  static const String _kSessions = 'flutter.pomodoro_completed_sessions';
  static const String _kRemainingSeconds = 'flutter.pomodoro_remaining_seconds';
  static const String _kProgressPercent = 'flutter.pomodoro_progress_percent';

  Timer? _timer;
  PomodoroPreset _preset = PomodoroPreset.classic;
  PomodoroPhase _phase = PomodoroPhase.idle;
  int _remainingSeconds = 0;
  int _completedFocusSessions = 0;
  String? _subjectTag;
  int? _eventId;
  int? _pendingSessionNoteId;

  // Notifiers for UI updates
  final ValueNotifier<PomodoroPhase> phaseNotifier = ValueNotifier(PomodoroPhase.idle);
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier(0);
  final ValueNotifier<int> completedSessionsNotifier = ValueNotifier(0);

  PomodoroPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  int get completedFocusSessions => _completedFocusSessions;
  String? get subjectTag => _subjectTag;
  int? get pendingSessionNoteId => _pendingSessionNoteId;
  PomodoroPreset get preset => _preset;

  bool get isRunning => _phase == PomodoroPhase.focusing || 
                        _phase == PomodoroPhase.shortBreak || 
                        _phase == PomodoroPhase.longBreak;

  String get formattedTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> init() async {
    await _restoreState();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString(_kPhase) ?? 'idle';
    final endTime = prefs.getInt(_kEndTime) ?? 0;
    
    if (endTime > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((endTime - now) / 1000).round();
      
      if (remaining > 0) {
        _phase = _parsePhase(savedPhase);
        _remainingSeconds = math.max(0, remaining);
        _completedFocusSessions = prefs.getInt(_kSessions) ?? 0;
        _subjectTag = prefs.getString(_kSubject);
        
        phaseNotifier.value = _phase;
        remainingSecondsNotifier.value = _remainingSeconds;
        completedSessionsNotifier.value = _completedFocusSessions;
        
        if (isRunning) {
          _startTimer();
        }
      } else {
        await _clearState();
      }
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

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final endTime = isRunning 
        ? DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000)
        : 0;
    
    final totalDuration = _preset.focusMinutes * 60;

    await prefs.setString(_kPhase, _phaseToString(_phase));
    await prefs.setInt(_kEndTime, endTime);
    await prefs.setInt(_kTotalDuration, totalDuration);
    await prefs.setString(_kSubject, _subjectTag ?? 'Ready to Focus');
    await prefs.setString(_kStatus, _getStatusText(_phase));
    await prefs.setInt(_kSessions, _completedFocusSessions);
    await prefs.setInt(_kRemainingSeconds, _remainingSeconds);
    
    final progress = totalDuration > 0 
        ? ((totalDuration - _remainingSeconds) / totalDuration * 100).round()
        : 0;
    await prefs.setInt(_kProgressPercent, progress.clamp(0, 100));

    debugPrint('Pomodoro state persisted: phase=${_phaseToString(_phase)}, endTime=$endTime, remaining=$_remainingSeconds, progress=$progress');
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPhase);
    await prefs.remove(_kEndTime);
    await prefs.remove(_kTotalDuration);
    await prefs.remove(_kSubject);
    await prefs.remove(_kStatus);
    await prefs.remove(_kBgColor);
    await prefs.remove(_kSessions);
    await prefs.remove(_kRemainingSeconds);
    await prefs.remove(_kProgressPercent);
  }

  Future<void> start({
    required PomodoroPreset preset,
    String? subjectTag,
    int? eventId,
  }) async {
    _preset = preset;
    _subjectTag = subjectTag;
    _eventId = eventId;
    _completedFocusSessions = 0;
    _pendingSessionNoteId = null;

    await _startFocus();
  }

  Future<void> _startFocus() async {
    _phase = PomodoroPhase.focusing;
    _remainingSeconds = _preset.focusMinutes * 60;
    
    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = _remainingSeconds;
    
    await _persistState();
    _startTimer();
    await WidgetService.refreshPomodoroWidget();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        remainingSecondsNotifier.value = _remainingSeconds;
        
        // Persist every 5 seconds to reduce writes but keep widget updated
        if (_remainingSeconds % 5 == 0) {
          await _persistState();
          await WidgetService.refreshPomodoroWidget();
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

  Future<void> _startShortBreak() async {
    _phase = PomodoroPhase.shortBreak;
    _remainingSeconds = _preset.shortBreakMinutes * 60;
    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = _remainingSeconds;
    await _persistState();
    _startTimer();
    await WidgetService.refreshPomodoroWidget();
  }

  Future<void> _startLongBreak() async {
    _phase = PomodoroPhase.longBreak;
    _remainingSeconds = _preset.longBreakMinutes * 60;
    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = _remainingSeconds;
    await _persistState();
    _startTimer();
    await WidgetService.refreshPomodoroWidget();
  }

  Future<void> _logSession() async {
    final session = StudySession(
      eventId: _eventId,
      subjectTag: _subjectTag,
      durationMinutes: _preset.focusMinutes,
      completedAtMillis: DateTime.now().millisecondsSinceEpoch,
      sessionType: 'pomodoro',
    );

    final id = await DatabaseHelper.instance.insertStudySession(session);
    _pendingSessionNoteId = id;

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

  void dismissSessionNote() {
    _pendingSessionNoteId = null;
  }

  void dispose() {
    _timer?.cancel();
    phaseNotifier.dispose();
    remainingSecondsNotifier.dispose();
    completedSessionsNotifier.dispose();
  }
}
