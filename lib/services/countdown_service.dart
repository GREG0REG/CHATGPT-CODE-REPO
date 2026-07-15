import '../models/event.dart';

/// Which phase of its lifecycle an event is currently in.
enum CountdownPhase {
  beforeStart, // now < startTime
  active, // startTime <= now < deadline (or no start set, now < deadline)
  completed, // deadline has passed (or, with no deadline, start has passed)
}

class CountdownResult {
  final CountdownPhase phase;
  final String text;

  const CountdownResult(this.phase, this.text);
}

/// Pure logic, no Flutter/UI dependencies, so it can be reused by both the
/// app UI and the background widget-update isolate.
class CountdownService {
  CountdownService._();

  /// Returns the first event that is not yet fully passed (i.e. whose
  /// [Event.finalMillis] is still in the future), given a list already
  /// sorted by date (nearest first). Returns null if none are upcoming.
  static Event? getActiveEvent(List<Event> sortedEvents, DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    for (final e in sortedEvents) {
      if (e.finalMillis > nowMillis) return e;
    }
    return null;
  }

  /// Computes the phase for a single event at [now]. Does NOT decide
  /// whether to move to the next event - callers should first select the
  /// active event via [getActiveEvent], which already skips passed events.
  ///
  /// PHASE 1 (beforeStart): now < startTime (only possible if a start time is set)
  /// PHASE 2 (active): startTime <= now < deadline, OR no start time set and now < deadline,
  ///                    OR a start time is set with no deadline and now < startTime has
  ///                    already been handled by PHASE 1 - once such an event's start time
  ///                    passes with no deadline to count down to, it is considered active
  ///                    indefinitely (there's nothing further to count down to).
  /// PHASE 3 (completed): the deadline has passed (or, when there is no deadline, this
  ///                       state is never reached from a start-only event).
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
    // No deadline set: once any start time has passed, treat the event as
    // active indefinitely (there's no further timestamp to complete against).
    return CountdownPhase.active;
  }

  /// Builds the display text for [event] at [now].
  ///
  /// PHASE 1 - before start:
  ///   >24h away  -> smart: "X days, Y hours, Z minutes until start" | plain: "X days until start"
  ///   <24h, >=1h -> smart: "X hours, Y minutes until start"        | plain: "X hours left"
  ///   <1h        -> smart: "X minutes until start"                  | plain: "X minutes left"
  /// PHASE 2 - active (between start and deadline, or no start set):
  ///   smart: "X days, Y hours left" (largest two units) | plain: "X days left" (largest unit)
  /// PHASE 3 - completed:
  ///   "Completed"
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
        // If there's no deadline to count down to, just say the event has started.
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

  /// Smart: full breakdown, using the two most significant non-zero units
  /// appropriate to the range, e.g. "24 days, 3 hours, 15 minutes until start",
  /// "5 hours, 23 minutes until start", "45 minutes until start".
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

  /// Plain: rounds to the single largest applicable unit.
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

  /// Smart: two most significant units, e.g. "3 days, 2 hours left",
  /// "2 hours, 15 minutes left", "15 minutes left".
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

  /// Plain: rounds to the single largest applicable unit.
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

