import '../models/event.dart';

/// Which phase of its lifecycle an event is currently in.
enum CountdownPhase {
  beforeStart,
  active,
  completed,
}

class CountdownResult {
  final CountdownPhase phase;
  final String text;

  const CountdownResult(this.phase, this.text);
}

/// Pure logic, no Flutter/UI dependencies.
class CountdownService {
  CountdownService._();

  /// Returns the first event that is not yet fully passed.
  static Event? getActiveEvent(List<Event> sortedEvents, DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    for (final e in sortedEvents) {
      if (e.finalMillis > nowMillis) return e;
    }
    return null;
  }

  static CountdownPhase phaseOf(Event event, DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    final start = event.startTimeMillis;
    final deadline = event.deadlineMillis;

    if (start != null && nowMillis < start) {
      return CountdownPhase.beforeStart;
    }
    if (deadline != null) {
      return nowMillis < deadline ? CountdownPhase.active : CountdownPhase.completed;
    }
    return CountdownPhase.active;
  }

  static CountdownResult buildCountdownText(
    Event event,
    DateTime now, {
    required bool smartFormatEnabled,
  }) {
    final phase = phaseOf(event, now);

    switch (phase) {
      case CountdownPhase.beforeStart:
        final diff = Duration(
          milliseconds: event.startTimeMillis! - now.millisecondsSinceEpoch,
        );
        return CountdownResult(
          phase,
          smartFormatEnabled
              ? _smartBeforeStart(diff)
              : _plainBeforeStart(diff),
        );

      case CountdownPhase.active:
        if (event.deadlineMillis == null) {
          return const CountdownResult(CountdownPhase.active, 'In progress');
        }
        final diff = Duration(
          milliseconds: event.deadlineMillis! - now.millisecondsSinceEpoch,
        );
        return CountdownResult(
          phase,
          smartFormatEnabled ? _smartLeft(diff) : _plainLeft(diff),
        );

      case CountdownPhase.completed:
        return const CountdownResult(CountdownPhase.completed, 'Completed');
    }
  }

  // ---- PHASE 1 formatting ----

  static String _smartBeforeStart(Duration diff) {
    if (diff.isNegative) return 'Completed';
    if (diff.inHours >= 24) {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      return '$days ${_unit(days, 'day')}, $hours ${_unit(hours, 'hour')}, '
          '$minutes ${_unit(minutes, 'minute')} until start';
    } else if (diff.inMinutes >= 60) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return '$hours ${_unit(hours, 'hour')}, $minutes ${_unit(minutes, 'minute')} until start';
    } else {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$minutes ${_unit(minutes, 'minute')} until start';
    }
  }

  static String _plainBeforeStart(Duration diff) {
    if (diff.isNegative) return 'Completed';
    if (diff.inHours >= 24) {
      final days = diff.inDays;
      return '$days ${_unit(days, 'day')} until start';
    } else if (diff.inMinutes >= 60) {
      final hours = diff.inHours;
      return '$hours ${_unit(hours, 'hour')} left';
    } else {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$minutes ${_unit(minutes, 'minute')} left';
    }
  }

  // ---- PHASE 2 formatting ----

  static String _smartLeft(Duration diff) {
    if (diff.isNegative) return 'Completed';
    if (diff.inHours >= 24) {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return '$days ${_unit(days, 'day')}, $hours ${_unit(hours, 'hour')} left';
    } else if (diff.inMinutes >= 60) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return '$hours ${_unit(hours, 'hour')}, $minutes ${_unit(minutes, 'minute')} left';
    } else {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$minutes ${_unit(minutes, 'minute')} left';
    }
  }

  static String _plainLeft(Duration diff) {
    if (diff.isNegative) return 'Completed';
    if (diff.inHours >= 24) {
      final days = diff.inDays;
      return '$days ${_unit(days, 'day')} left';
    } else if (diff.inMinutes >= 60) {
      final hours = diff.inHours;
      return '$hours ${_unit(hours, 'hour')} left';
    } else {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$minutes ${_unit(minutes, 'minute')} left';
    }
  }

  static String _unit(int value, String singular) =>
      value == 1 ? singular : '${singular}s';
}
