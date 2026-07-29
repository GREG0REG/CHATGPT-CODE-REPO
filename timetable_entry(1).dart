// FILE: lib/models/timetable_entry.dart
// COMPLETE REPLACEMENT — TimetableEntry data model with CSV/JSON support

import 'dart:convert';

/// Represents a single timetable class entry.
/// 
/// Fields map to the `timetable_classes` table schema:
/// - [id]: Primary key (auto-increment)
/// - [subjectName]: Name of the subject/class
/// - [dayOfWeek]: 1=Monday, 2=Tuesday, ..., 7=Sunday
/// - [startTime]: Minutes from midnight (e.g., 540 = 9:00 AM)
/// - [endTime]: Minutes from midnight (e.g., 600 = 10:00 AM)
/// - [room]: Classroom or location
/// - [color]: Hex color string (e.g., "#2196F3")
/// - [notes]: Optional notes
class TimetableEntry {
  final int? id;
  final String subjectName;
  final int dayOfWeek;
  final int startTime;      // minutes from midnight
  final int endTime;        // minutes from midnight
  final String room;
  final String color;       // hex color
  final String? notes;

  const TimetableEntry({
    this.id,
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room = '',
    this.color = '#2196F3',
    this.notes,
  });

  // ============================================================
  // CSV SUPPORT
  // ============================================================

  /// CSV header row for export/import.
  static List<String> get csvHeaders => [
        'id',
        'subjectName',
        'dayOfWeek',
        'startTime',
        'endTime',
        'room',
        'color',
        'notes',
      ];

  /// Converts this entry to a CSV row (List of Strings).
  List<String> toCsvRow() {
    return [
      id?.toString() ?? '',
      subjectName,
      dayOfWeek.toString(),
      startTime.toString(),
      endTime.toString(),
      room,
      color,
      notes ?? '',
    ];
  }

  /// Creates a [TimetableEntry] from a CSV row (List of Strings).
  /// 
  /// Expects exactly 8 columns matching [csvHeaders].
  /// Throws [FormatException] if row length is invalid or numeric fields
  /// cannot be parsed.
  factory TimetableEntry.fromCsvRow(List<String> row) {
    if (row.length != csvHeaders.length) {
      throw FormatException(
        'CSV row must have exactly ${csvHeaders.length} columns, got ${row.length}',
        row,
      );
    }

    int? parseInt(String value, String fieldName) {
      if (value.trim().isEmpty) return null;
      final parsed = int.tryParse(value.trim());
      if (parsed == null) {
        throw FormatException(
          'Invalid integer for $fieldName: "$value"',
          row,
        );
      }
      return parsed;
    }

    return TimetableEntry(
      id: parseInt(row[0], 'id'),
      subjectName: row[1].trim(),
      dayOfWeek: parseInt(row[2], 'dayOfWeek') ?? 1,
      startTime: parseInt(row[3], 'startTime') ?? 540,
      endTime: parseInt(row[4], 'endTime') ?? 600,
      room: row[5].trim(),
      color: row[6].trim().isEmpty ? '#2196F3' : row[6].trim(),
      notes: row[7].trim().isEmpty ? null : row[7].trim(),
    );
  }

  // ============================================================
  // JSON SUPPORT
  // ============================================================

  /// Converts this entry to a JSON-compatible [Map].
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectName': subjectName,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'color': color,
      'notes': notes,
    };
  }

  /// Creates a [TimetableEntry] from a JSON [Map].
  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        return parsed ?? fallback;
      }
      return fallback;
    }

    return TimetableEntry(
      id: json['id'] != null ? toInt(json['id'], 0) : null,
      subjectName: (json['subjectName'] ?? json['subject_name'] ?? 'Untitled').toString(),
      dayOfWeek: toInt(json['dayOfWeek'] ?? json['day_of_week'], 1),
      startTime: toInt(json['startTime'] ?? json['start_time'] ?? json['startTimeMinutes'], 540),
      endTime: toInt(json['endTime'] ?? json['end_time'] ?? json['endTimeMinutes'], 600),
      room: (json['room'] ?? '').toString(),
      color: (json['color'] ?? json['colorHex'] ?? '#2196F3').toString(),
      notes: json['notes'] != null ? json['notes'].toString() : null,
    );
  }

  /// Serializes to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from a JSON string.
  factory TimetableEntry.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return TimetableEntry.fromJson(decoded);
    }
    throw FormatException('JSON must be an object, got ${decoded.runtimeType}');
  }

  // ============================================================
  // copyWith
  // ============================================================

  /// Creates a copy of this entry with optionally overridden fields.
  TimetableEntry copyWith({
    int? id,
    String? subjectName,
    int? dayOfWeek,
    int? startTime,
    int? endTime,
    String? room,
    String? color,
    String? notes,
    bool clearNotes = false,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      subjectName: subjectName ?? this.subjectName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      color: color ?? this.color,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Returns true if this entry overlaps with [other] on the same day.
  bool conflictsWith(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return false;
    return startTime < other.endTime && other.startTime < endTime;
  }

  /// Duration of this class in minutes.
  int get durationMinutes => endTime - startTime;

  /// Formats start time as "9:00 AM" / "2:30 PM".
  String get formattedStartTime => _formatMinutes(startTime);

  /// Formats end time as "9:00 AM" / "2:30 PM".
  String get formattedEndTime => _formatMinutes(endTime);

  /// Formats time range as "9:00 AM - 10:00 AM".
  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  /// Day name (Monday, Tuesday, ...).
  String get dayName {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[(dayOfWeek - 1).clamp(0, 6)];
  }

  /// Short day name (Mon, Tue, ...).
  String get dayNameShort {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(dayOfWeek - 1).clamp(0, 6)];
  }

  /// Converts to a DB row map (for sqflite insert/update).
  /// 
  /// Omits [id] if null (let DB auto-increment).
  Map<String, dynamic> toDbRow() {
    final map = <String, dynamic>{
      'subjectName': subjectName,
      'dayOfWeek': dayOfWeek,
      'startTimeMinutes': startTime,
      'endTimeMinutes': endTime,
      'room': room,
      'colorHex': color,
      'note': notes,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  /// Creates from a DB row map (from sqflite query).
  factory TimetableEntry.fromDbRow(Map<String, dynamic> row) {
    return TimetableEntry(
      id: row['id'] as int?,
      subjectName: (row['subjectName'] ?? row['subject_name'] ?? 'Untitled').toString(),
      dayOfWeek: (row['dayOfWeek'] ?? row['day_of_week'] ?? 1) as int,
      startTime: (row['startTimeMinutes'] ?? row['start_time_minutes'] ?? 540) as int,
      endTime: (row['endTimeMinutes'] ?? row['end_time_minutes'] ?? 600) as int,
      room: (row['room'] ?? '').toString(),
      color: (row['colorHex'] ?? row['color_hex'] ?? '#2196F3').toString(),
      notes: row['note']?.toString(),
    );
  }

  // ============================================================
  // Overrides
  // ============================================================

  @override
  String toString() {
    return 'TimetableEntry(id: $id, subject: $subjectName, day: $dayName, time: $formattedTimeRange, room: $room)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimetableEntry &&
        other.id == id &&
        other.subjectName == subjectName &&
        other.dayOfWeek == dayOfWeek &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.room == room &&
        other.color == color &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(id, subjectName, dayOfWeek, startTime, endTime, room, color, notes);

  // ============================================================
  // Private helpers
  // ============================================================

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $ampm';
  }
}
