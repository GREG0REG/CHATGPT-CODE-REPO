// FILE: lib/models/timetable_entry.dart
// COMPLETE REPLACEMENT — TimetableEntry data model with CSV/JSON support
// ADDED: Validation, duration formatting, overlap buffer, versioning, occurrence cloning,
//        widget map, summary, time operators, bulk CSV parser, color contrast, notification payload

import 'dart:convert';

/// Represents a single timetable class entry.
class TimetableEntry {
  final int? id;
  final String subjectName;
  final int dayOfWeek;
  final int startTime;
  final int endTime;
  final String room;
  final String color;
  final String? notes;

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

  bool get isValid {
    return subjectName.trim().isNotEmpty &&
        dayOfWeek >= 1 && dayOfWeek <= 7 &&
        startTime >= 0 && startTime < 1440 &&
        endTime > startTime && endTime <= 1440;
  }

  List<String> get validationErrors {
    final errors = <String>[];
    if (subjectName.trim().isEmpty) errors.add('Subject name is required');
    if (dayOfWeek < 1 || dayOfWeek > 7) errors.add('Day must be between 1 (Mon) and 7 (Sun)');
    if (startTime < 0 || startTime >= 1440) errors.add('Start time must be between 00:00 and 23:59');
    if (endTime <= startTime) errors.add('End time must be after start time');
    if (endTime > 1440) errors.add('End time must be before 24:00');
    return errors;
  }

  int get durationMinutes => endTime - startTime;

  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  static List<String> get csvHeaders => [
        'id', 'subjectName', 'dayOfWeek', 'startTime', 'endTime', 'room', 'color', 'notes',
      ];

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
        throw FormatException('Invalid integer for $fieldName: "$value"', row);
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

  static List<TimetableEntry> fromCsvString(String csv) {
    final lines = const LineSplitter().convert(csv.trim());
    if (lines.isEmpty) return [];
    
    final entries = <TimetableEntry>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final fields = _parseCsvLine(line);
      try {
        entries.add(TimetableEntry.fromCsvRow(fields));
      } catch (e) {
        continue;
      }
    }
    return entries;
  }

  static String toCsvString(List<TimetableEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln(csvHeaders.join(','));
    for (final entry in entries) {
      buffer.writeln(entry.toCsvRow().map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

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

  String toJsonString() => jsonEncode(toJson());

  factory TimetableEntry.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return TimetableEntry.fromJson(decoded);
    }
    throw FormatException('JSON must be an object, got ${decoded.runtimeType}');
  }

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

  TimetableEntry createOccurrence(DateTime date) {
    return copyWith(id: null);
  }

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

  String toSummary() {
    final parts = <String>[
      subjectName,
      '$dayNameShort $formattedTimeRange',
    ];
    if (room.isNotEmpty) parts.add('Room $room');
    return parts.join(', ');
  }

    Color get textColorOnBackground {
    final hexColor = color.replaceFirst('#', '');
    final r = int.parse(hexColor.substring(0, 2), radix: 16);
    final g = int.parse(hexColor.substring(2, 4), radix: 16);
    final b = int.parse(hexColor.substring(4, 6), radix: 16);
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  bool conflictsWith(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return false;
    return startTime < other.endTime && other.startTime < endTime;
  }

  bool conflictsWithBuffer(TimetableEntry other, {int bufferMinutes = 0}) {
    if (dayOfWeek != other.dayOfWeek) return false;
    return (startTime - bufferMinutes) < other.endTime &&
        other.startTime < (endTime + bufferMinutes);
  }

  String get formattedStartTime => _formatMinutes(startTime);
  String get formattedEndTime => _formatMinutes(endTime);
  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  String get dayName {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[(dayOfWeek - 1).clamp(0, 6)];
  }

  String get dayNameShort {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(dayOfWeek - 1).clamp(0, 6)];
  }

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

  bool operator <(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return dayOfWeek < other.dayOfWeek;
    return startTime < other.startTime;
  }

  bool operator >(TimetableEntry other) {
    if (dayOfWeek != other.dayOfWeek) return dayOfWeek > other.dayOfWeek;
    return startTime > other.startTime;
  }

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

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $ampm';
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
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
