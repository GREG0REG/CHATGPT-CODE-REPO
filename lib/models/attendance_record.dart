// FILE: lib/models/attendance_record.dart
// Attendance Record Model — CSV/JSON serialization, immutable with copyWith

import 'package:flutter/foundation.dart';

/// Represents a single attendance record for a subject on a specific date.
///
/// Status values: 'present', 'absent', 'late', 'excused'
@immutable
class AttendanceRecord {
  final int? id;
  final String subjectName;
  final DateTime date;
  final String status;
  final String? notes;

  static const List<String> validStatuses = ['present', 'absent', 'late', 'excused'];

  const AttendanceRecord({
    this.id,
    required this.subjectName,
    required this.date,
    required this.status,
    this.notes,
  });

  /// CSV column headers for export/import.
  static List<String> get csvHeaders => [
        'id',
        'subjectName',
        'date',
        'status',
        'notes',
      ];

  /// Converts this record to a CSV row (List of strings).
  List<String> toCsvRow() {
    return [
      id?.toString() ?? '',
      subjectName,
      date.toIso8601String(),
      status,
      notes ?? '',
    ];
  }

  /// Creates an [AttendanceRecord] from a CSV row (List of strings).
  ///
  /// Expects the row to match [csvHeaders] order.
  /// Throws [FormatException] if required fields are missing or invalid.
  factory AttendanceRecord.fromCsvRow(List<String> row) {
    if (row.length < 4) {
      throw FormatException(
        'CSV row must have at least 4 columns, got ${row.length}: $row',
      );
    }

    final idStr = row[0].trim();
    final subjectName = row[1].trim();
    final dateStr = row[2].trim();
    final status = row[3].trim().toLowerCase();
    final notes = row.length > 4 ? row[4].trim() : null;

    if (subjectName.isEmpty) {
      throw FormatException('subjectName cannot be empty');
    }
    if (dateStr.isEmpty) {
      throw FormatException('date cannot be empty');
    }
    if (!validStatuses.contains(status)) {
      throw FormatException(
        'Invalid status "\$status". Must be one of: \${validStatuses.join(", ")}',
      );
    }

    return AttendanceRecord(
      id: idStr.isNotEmpty ? int.parse(idStr) : null,
      subjectName: subjectName,
      date: DateTime.parse(dateStr),
      status: status,
      notes: notes?.isNotEmpty == true ? notes : null,
    );
  }

  /// Converts this record to a JSON-compatible Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectName': subjectName,
      'date': date.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  /// Creates an [AttendanceRecord] from a JSON Map.
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String?)?.toLowerCase() ?? '';
    if (!validStatuses.contains(statusStr)) {
      throw FormatException(
        'Invalid status "\$statusStr". Must be one of: \${validStatuses.join(", ")}',
      );
    }

    return AttendanceRecord(
      id: json['id'] as int?,
      subjectName: json['subjectName'] as String,
      date: DateTime.parse(json['date'] as String),
      status: statusStr,
      notes: json['notes'] as String?,
    );
  }

  /// Creates a copy of this record with optionally updated fields.
  AttendanceRecord copyWith({
    int? id,
    String? subjectName,
    DateTime? date,
    String? status,
    String? notes,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      subjectName: subjectName ?? this.subjectName,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'AttendanceRecord(id: \$id, subjectName: \$subjectName, date: \$date, status: \$status, notes: \$notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord &&
        other.id == id &&
        other.subjectName == subjectName &&
        other.date == date &&
        other.status == status &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(id, subjectName, date, status, notes);
  }
}
