import 'package:flutter/material.dart';

class SyllabusSubject {
  final int? id;
  final String name;
  final String colorHex;
  final int? targetCompletionDateMillis;
  final int? totalMarksWeightage; // NEET-specific: marks weightage
  final String? examCategory; // e.g., 'physics', 'chemistry', 'biology'
  final int createdAtMillis;

  SyllabusSubject({
    this.id,
    required this.name,
    this.colorHex = '#2196F3',
    this.targetCompletionDateMillis,
    this.totalMarksWeightage,
    this.examCategory,
    required this.createdAtMillis,
  });

  Color get color {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  SyllabusSubject copyWith({
    int? id,
    String? name,
    String? colorHex,
    int? targetCompletionDateMillis,
    int? totalMarksWeightage,
    String? examCategory,
    int? createdAtMillis,
  }) => SyllabusSubject(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
    targetCompletionDateMillis: targetCompletionDateMillis ?? this.targetCompletionDateMillis,
    totalMarksWeightage: totalMarksWeightage ?? this.totalMarksWeightage,
    examCategory: examCategory ?? this.examCategory,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorHex': colorHex,
    'targetCompletionDateMillis': targetCompletionDateMillis,
    'totalMarksWeightage': totalMarksWeightage,
    'examCategory': examCategory,
    'createdAtMillis': createdAtMillis,
  };

  factory SyllabusSubject.fromMap(Map<String, dynamic> map) => SyllabusSubject(
    id: map['id'] as int?,
    name: map['name'] as String,
    colorHex: map['colorHex'] as String? ?? '#2196F3',
    targetCompletionDateMillis: map['targetCompletionDateMillis'] as int?,
    totalMarksWeightage: map['totalMarksWeightage'] as int?,
    examCategory: map['examCategory'] as String?,
    createdAtMillis: map['createdAtMillis'] as int,
  );
}
