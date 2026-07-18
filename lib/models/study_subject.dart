import 'package:flutter/material.dart';

/// An independent study subject for the Pomodoro focus module.
/// Decoupled from Event subjects so users can track focus time per topic.
class StudySubject {
  final int? id;
  final String name;
  final String colorHex;
  final int totalFocusMinutes;
  final int createdAtMillis;

  const StudySubject({
    this.id,
    required this.name,
    this.colorHex = '#2196F3',
    this.totalFocusMinutes = 0,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'totalFocusMinutes': totalFocusMinutes,
      'createdAtMillis': createdAtMillis,
    };
  }

  factory StudySubject.fromMap(Map<String, dynamic> map) {
    return StudySubject(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorHex: map['colorHex'] as String? ?? '#2196F3',
      totalFocusMinutes: map['totalFocusMinutes'] as int? ?? 0,
      createdAtMillis: map['createdAtMillis'] as int,
    );
  }

  StudySubject copyWith({
    int? id,
    String? name,
    String? colorHex,
    int? totalFocusMinutes,
    int? createdAtMillis,
  }) {
    return StudySubject(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }
}
