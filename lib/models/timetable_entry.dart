// FILE: lib/models/timetable_entry.dart
// COMPLETE REPLACEMENT — TimetableEntry data model with CSV/JSON support
// ADDED: Validation, duration formatting, overlap buffer, versioning, occurrence cloning,
//        widget map, summary, time operators, bulk CSV parser, color contrast, notification payload

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

  // ============================================================
  // SCHEMA VERSION for future migrations
  // ============================================================
  static const int currentSchemaVersion = 1;

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
  // VALIDATION
  // ============================================================

  /// Returns true if this entry has valid data.
  bool get isValid {
    return subjectName.trim().isNotEmpty &&
        dayOfWeek >= 1 && dayOfWeek <= 7 &&
        startTime >= 0 && startTime < 1440 &&
        endTime > startTime && endTime <= 1440;
  }

  /// Returns a list of validation error messages, empty if valid.
  List<String> get validationErrors {
    final errors = <String>[];
    if (subjectName.trim().isEmpty) errors.add('Subject name is required');
    if (dayOfWeek < 1 || dayOfWeek > 7) errors.add('Day must be between 1 (Mon) and 7 (Sun)');
    if (startTime < 0 || startTime >= 1440) errors.add('Start time must be between 00:00 and 23:59');
    if (endTime <= startTime) errors.add('End time must be after start time');
    if (endTime > 1440) errors.add('End time must be before 24:00');
    return errors;
  }

  // ============================================================
  // DURATION HELPERS
  // ============================================================

  /// Duration of this class in minutes.
  int get durationMinutes => endTime - startTime;

  /// Duration formatted as "1h 30m" or "45m".
  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

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

  /// Parses a multi-line CSV string into a list of [TimetableEntry].
  /// First line is treated as header and skipped.
  static List<TimetableEntry> fromCsvString(String csv) {
    final lines = const LineSplitter().convert(csv.trim());
    if (lines.isEmpty) return [];
    
    final entries = <TimetableEntry>[];
    // Skip header line (line 0)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // Simple CSV parsing — handles quoted fields
      final fields = _parseCsvLine(line);
      try {
        entries.add(TimetableEntry.fromCsvRow(fields));
      } catch (e) {
        // Skip invalid rows
        continue;
      }
    }
    return entries;
  }

  /// Converts a list of entries to a full CSV string with header.
  static String toCsvString(List<TimetableEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln(csvHeaders.join(','));
    for (final entry in entries) {
      buffer.writeln(entry.toCsvRow().map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  // ============================================================
  // JSON SUPPORT
  // ============================================================

  /// Converts this entry to a JSON-compatible [Map].
  Map<String, dynamic> toJson() {
    return {
      '_version': currentSchemaVersion,
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
  // OCCURRENCE CLONING (for recurring instances)
  // ============================================================

  /// Creates a one-off copy of this entry for a specific date.
  /// Useful for generating instances of recurring classes.
  TimetableEntry createOccurrence(DateTime date) {
    return copyWith(
      id: null, // New ID for this occurrence
    );
  }

  // ============================================================
  // WIDGET MAP (lightweight for home screen widget)
  // ============================================================

  /// Converts to a lightweight map with only essential fields for widgets.
  Map<String, dynamic> toWidgetMap() {
    return {
      'id': id,
      'subject': subjectName,
      'day': dayOfWeek,
      'start': formattedStartTime,
      'end': formattedEndTime,
      'room': room,
      'color': color,
    };
  }

  // ============================================================
  // NOTIFICATION PAYLOAD
  // ============================================================

  /// Converts to a flat map suitable for flutter_local_notifications payload.
  Map<String, String> toNotificationPayload() {
    return {
      'entry_id': id?.toString() ?? '0',
      'subject': subjectName,
      'day': dayOfWeek.toString(),
      'start': startTime.toString(),
      'end': endTime.toString(),
      'room': room,
      'type': 'timetable_class',
    };
  }

  // ============================================================
  // SUMMARY / PRETTY PRINT
  // ============================================================

  /// Returns a human-readable summary.
  String toSummary() {
    final parts = <String>[
      subjectName,
      '$dayNameShort $formattedTimeRange',
    ];
    if (room.isNotEmpty) parts.add('Room $room');
    return parts.join(', ');
  }

  // ============================================================
  // COLOR CONTRAST HELPER
  // ============================================================

  /// Returns black or white text color based on background luminance.
  Color get textColorOnBackground {
    final hexColor = color.replaceFirst('#', '');
    final r = int.parse(hexColor.substring(0, 2), radix: 16);
    final g = int.parse(hexColor.substring(2, 4), radix: 16);
    final b = int.parse(hexColor.substring(4, 6), radix: 16);
    // Relative luminance formula
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Returns true if this entry overlaps with [other] on the same day.
  bool conflictsWith(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return false;
    return startTime < other.endTime && other.startTime < endTime;
  }

  /// Returns true if this entry overlaps with [other] within [bufferMinutes].
  bool conflictsWithBuffer(TimetableEntry other, {int bufferMinutes = 0}) {
    if (dayOfWeek != other.dayOfWeek) return false;
    return (startTime - bufferMinutes) < other.endTime &&
        other.startTime < (endTime + bufferMinutes);
  }

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
  // TIME COMPARISON OPERATORS
  // ============================================================

  bool operator <(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return dayOfWeek < other.dayOfWeek;
    return startTime < other.startTime;
  }

  bool operator >(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return dayOfWeek > other.dayOfWeek;
    return startTime > other.startTime;
  }

  // ============================================================
  // DIFF / PATCH
  // ============================================================

  /// Returns a map of changed fields between this and [other].
  /// Empty map if identical.
  Map<String, dynamic> diff(TimetableEntry other) {
    final changes = <String, dynamic>{};
    if (subjectName != other.subjectName) changes['subjectName'] = other.subjectName;
    if (dayOfWeek != other.dayOfWeek) changes['dayOfWeek'] = other.dayOfWeek;
    if (startTime != other.startTime) changes['startTime'] = other.startTime;
    if (endTime != other.endTime) changes['endTime'] = other.endTime;
    if (room != other.room) changes['room'] = other.room;
    if (color != other.color) changes['color'] = other.color;
    if (notes != other.notes) changes['notes'] = other.notes;
    return changes;
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

  /// Escapes a field for CSV output.
  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Parses a single CSV line into fields.
  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}
