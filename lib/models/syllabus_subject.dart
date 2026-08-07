import 'package:flutter/material.dart';

class SyllabusSubject {
  final int? id;
  final String name;
  final String colorHex;
  final int? targetCompletionDateMillis;
  final int createdAtMillis;

  SyllabusSubject({
    this.id,
    required this.name,
    this.colorHex = '#2196F3',
    this.targetCompletionDateMillis,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'targetCompletionDateMillis': targetCompletionDateMillis,
        'createdAtMillis': createdAtMillis,
      };

  factory SyllabusSubject.fromMap(Map<String, dynamic> map) => SyllabusSubject(
        id: map['id'] as int?,
        name: map['name'] as String,
        colorHex: map['colorHex'] as String? ?? '#2196F3',
        targetCompletionDateMillis: map['targetCompletionDateMillis'] as int?,
        createdAtMillis: map['createdAtMillis'] as int,
      );

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xff')));
}
