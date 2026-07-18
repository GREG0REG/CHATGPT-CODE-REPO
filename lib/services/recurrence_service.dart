import 'dart:math';

import '../models/event.dart';

class RecurrenceService {
  RecurrenceService._();
  
  static const int _maxOccurrencesPerEvent = 1000;
  static const int _maxLookaheadDays = 730;

  static List<Event> expandEvents(List<Event> rawEvents, DateTime now) {
    final result = <Event>[];
    final cutoff = now.add(const Duration(days: _maxLookaheadDays));

    for (final event in rawEvents) {
      if (!event.isRecurring) {
        result.add(event);
        continue;
      }

      final virtuals = _generateVirtualOccurrences(event, now, cutoff);
      result.add(event);
      result.addAll(virtuals);
    }

    result.sort((a, b) => a.primarySortMillis.compareTo(b.primarySortMillis));
    return result;
  }

  static Event? getNextOccurrence(Event event, DateTime now) {
    if (!event.isRecurring) {
      return event.finalMillis > now.millisecondsSinceEpoch ? event : null;
    }

    final virtuals = _generateVirtualOccurrences(
      event,
      now,
      now.add(const Duration(days: _maxLookaheadDays)),
      maxCount: 1,
    );
    return virtuals.isNotEmpty ? virtuals.first : null;
  }

  static List<Event> _generateVirtualOccurrences(
    Event event,
    DateTime now,
    DateTime cutoff, {
    int maxCount = _maxOccurrencesPerEvent,
  }) {
    final virtuals = <Event>[];
    final excluded = event.excludedDates;

    switch (event.recurrence) {
      case RecurrenceType.none:
        return [];
      case RecurrenceType.daily:
        virtuals.addAll(_generateIntervalOccurrences(
          event: event,
          now: now,
          cutoff: cutoff,
          intervalDays: event.recurrenceInterval,
          maxCount: maxCount,
          excluded: excluded,
        ));
        break;
      case RecurrenceType.weekly:
        virtuals.addAll(_generateIntervalOccurrences(
          event: event,
          now: now,
          cutoff: cutoff,
          intervalDays: event.recurrenceInterval * 7,
          maxCount: maxCount,
          excluded: excluded,
        ));
        break;
      case RecurrenceType.monthly:
        virtuals.addAll(_generateMonthlyOccurrences(
          event: event,
          now: now,
          cutoff: cutoff,
          intervalMonths: event.recurrenceInterval,
          maxCount: maxCount,
          excluded: excluded,
        ));
        break;
      case RecurrenceType.yearly:
        if (event.yearlyUseSpecificDates && event.yearlySpecificDates.isNotEmpty) {
          virtuals.addAll(_generateYearlySpecificOccurrences(
            event: event,
            now: now,
            cutoff: cutoff,
            maxCount: maxCount,
            excluded: excluded,
          ));
        } else {
          virtuals.addAll(_generateYearlyIntervalOccurrences(
            event: event,
            now: now,
            cutoff: cutoff,
            intervalYears: event.recurrenceInterval,
            maxCount: maxCount,
            excluded: excluded,
          ));
        }
        break;
    }

    return virtuals;
  }

  static List<Event> _generateIntervalOccurrences({
    required Event event,
    required DateTime now,
    required DateTime cutoff,
    required int intervalDays,
    required int maxCount,
    required List<int> excluded,
  }) {
    final virtuals = <Event>[];
    final baseDate = DateTime.fromMillisecondsSinceEpoch(event.dateMillis);
    var current = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final nowDate = DateTime(now.year, now.month, now.day);

    while (current.isBefore(nowDate)) {
      current = current.add(Duration(days: intervalDays));
    }

    int count = 0;
    while (count < maxCount && !current.isAfter(cutoff)) {
      final occurrenceMillis = current.millisecondsSinceEpoch;
      if (!excluded.contains(occurrenceMillis)) {
        virtuals.add(_buildVirtualEvent(event, current, occurrenceMillis));
        count++;
      }
      current = current.add(Duration(days: intervalDays));
    }

    return virtuals;
  }

  static List<Event> _generateMonthlyOccurrences({
    required Event event,
    required DateTime now,
    required DateTime cutoff,
    required int intervalMonths,
    required int maxCount,
    required List<int> excluded,
  }) {
    final virtuals = <Event>[];
    final baseDate = DateTime.fromMillisecondsSinceEpoch(event.dateMillis);
    var currentYear = baseDate.year;
    var currentMonth = baseDate.month;

    final nowYearMonth = now.year * 12 + now.month;
    var currentYearMonth = currentYear * 12 + currentMonth;

    while (currentYearMonth < nowYearMonth) {
      currentMonth += intervalMonths;
      while (currentMonth > 12) {
        currentMonth -= 12;
        currentYear++;
      }
      currentYearMonth = currentYear * 12 + currentMonth;
    }

    int count = 0;
    while (count < maxCount) {
      final daysInMonth = _daysInMonth(currentYear, currentMonth);
      final day = min(baseDate.day, daysInMonth);
      final current = DateTime(currentYear, currentMonth, day);

      if (current.isAfter(cutoff)) break;

      final occurrenceMillis = current.millisecondsSinceEpoch;
      if (!current.isBefore(DateTime(now.year, now.month, now.day)) &&
          !excluded.contains(occurrenceMillis)) {
        virtuals.add(_buildVirtualEvent(event, current, occurrenceMillis));
        count++;
      }

      currentMonth += intervalMonths;
      while (currentMonth > 12) {
        currentMonth -= 12;
        currentYear++;
      }
    }

    return virtuals;
  }

  static List<Event> _generateYearlyIntervalOccurrences({
    required Event event,
    required DateTime now,
    required DateTime cutoff,
    required int intervalYears,
    required int maxCount,
    required List<int> excluded,
  }) {
    final virtuals = <Event>[];
    final baseDate = DateTime.fromMillisecondsSinceEpoch(event.dateMillis);
    var currentYear = baseDate.year;

    while (currentYear < now.year) {
      currentYear += intervalYears;
    }

    int count = 0;
    while (count < maxCount) {
      final current = DateTime(currentYear, baseDate.month, baseDate.day);
      if (current.isAfter(cutoff)) break;

      final occurrenceMillis = current.millisecondsSinceEpoch;
      if (!current.isBefore(DateTime(now.year, now.month, now.day)) &&
          !excluded.contains(occurrenceMillis)) {
        virtuals.add(_buildVirtualEvent(event, current, occurrenceMillis));
        count++;
      }

      currentYear += intervalYears;
    }

    return virtuals;
  }

  static List<Event> _generateYearlySpecificOccurrences({
    required Event event,
    required DateTime now,
    required DateTime cutoff,
    required int maxCount,
    required List<int> excluded,
  }) {
    final virtuals = <Event>[];
    final specificDates = event.yearlySpecificDates;
    var currentYear = now.year;

    final candidatesThisYear = <_OccurrenceCandidate>[];
    for (final sd in specificDates) {
      final dt = sd.toDateTime(currentYear);
      final todayStart = DateTime(now.year, now.month, now.day);
      if (!dt.isBefore(todayStart)) {
        candidatesThisYear.add(_OccurrenceCandidate(dt, sd));
      }
    }
    candidatesThisYear.sort((a, b) => a.date.compareTo(b.date));

    for (final cand in candidatesThisYear) {
      if (virtuals.length >= maxCount) break;
      final occurrenceMillis = cand.date.millisecondsSinceEpoch;
      if (!excluded.contains(occurrenceMillis)) {
        virtuals.add(_buildVirtualEvent(
          event,
          cand.date,
          occurrenceMillis,
          customStartTime: cand.specificDate.customStartTimeMillis,
          customDeadline: cand.specificDate.customDeadlineMillis,
        ));
      }
    }

    return virtuals;
  }

  static Event _buildVirtualEvent(
    Event event,
    DateTime occurrenceDate,
    int occurrenceMillis, {
    int? customStartTime,
    int? customDeadline,
  }) {
    int? startMillis;
    int? deadlineMillis;

    if (event.startTimeMillis != null || customStartTime != null) {
      final baseStart = DateTime.fromMillisecondsSinceEpoch(
          customStartTime ?? event.startTimeMillis!);
      startMillis = DateTime(
        occurrenceDate.year,
        occurrenceDate.month,
        occurrenceDate.day,
        baseStart.hour,
        baseStart.minute,
      ).millisecondsSinceEpoch;
    }

    if (event.deadlineMillis != null || customDeadline != null) {
      final baseDeadline = DateTime.fromMillisecondsSinceEpoch(
          customDeadline ?? event.deadlineMillis!);
      deadlineMillis = DateTime(
        occurrenceDate.year,
        occurrenceDate.month,
        occurrenceDate.day,
        baseDeadline.hour,
        baseDeadline.minute,
      ).millisecondsSinceEpoch;
    }

    // FIX: Preserve student study pack fields so child occurrences keep icon/color/subject
    return Event(
      id: -event.id!,
      title: event.title,
      dateMillis: occurrenceMillis,
      startTimeMillis: startMillis,
      deadlineMillis: deadlineMillis,
      notes: event.notes,
      recurrence: RecurrenceType.none,
      recurrenceInterval: 1,
      yearlyUseSpecificDates: false,
      iconName: event.iconName,
      priority: event.priority,
      subjectTag: event.subjectTag,
      isCompleted: event.isCompleted,
    );
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}

class _OccurrenceCandidate {
  final DateTime date;
  final YearlySpecificDate specificDate;

  _OccurrenceCandidate(this.date, this.specificDate);
}
