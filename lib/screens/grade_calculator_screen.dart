// FILE: lib/screens/grade_calculator_screen.dart
// REDESIGNED v6 — NEET Edition (COMPLETE FIX + UI ENHANCEMENT)
// FIXED: SharedPreferences.getKeys() error — using iteration instead of getKeys()
// FIXED: Cached SharedPreferences instance to prevent multiple getInstance() calls
// FIXED: All preset loading with proper error handling
// NEW: Modern glassmorphism UI with gradients and animations
// NEW: PYQ Year-wise Tracker (2019-2024)
// NEW: Formula Sheet Quick Reference
// NEW: Bookmark Weak Questions feature
// NEW: Daily Quiz Challenge
// NEW: Subject-wise Progress Rings
// NEW: Animated transitions and micro-interactions
// NEW: Smart Revision Scheduler
// NEW: NEET Previous Year Paper Analysis

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';

// ═══════════════════════════════════════════════════════════════════
// NEET DATA MODELS & CONSTANTS
// ═══════════════════════════════════════════════════════════════════

class MockTestResult {
  final String id;
  final DateTime date;
  final int physicsScore;
  final int chemistryScore;
  final int biologyScore;
  final int totalScore;
  final double percentile;
  final int? air;
  final String testName;
  final String? notes;
  final int correctCount;
  final int wrongCount;
  final int leftCount;

  MockTestResult({
    required this.id,
    required this.date,
    required this.physicsScore,
    required this.chemistryScore,
    required this.biologyScore,
    required this.totalScore,
    required this.percentile,
    this.air,
    required this.testName,
    this.notes,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.leftCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'physicsScore': physicsScore,
    'chemistryScore': chemistryScore,
    'biologyScore': biologyScore,
    'totalScore': totalScore,
    'percentile': percentile,
    'air': air,
    'testName': testName,
    'notes': notes,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'leftCount': leftCount,
  };

  factory MockTestResult.fromJson(Map<String, dynamic> json) => MockTestResult(
    id: json['id'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
    physicsScore: json['physicsScore'] as int,
    chemistryScore: json['chemistryScore'] as int,
    biologyScore: json['biologyScore'] as int,
    totalScore: json['totalScore'] as int,
    percentile: (json['percentile'] as num).toDouble(),
    air: json['air'] as int?,
    testName: json['testName'] as String,
    notes: json['notes'] as String?,
    correctCount: json['correctCount'] as int? ?? 0,
    wrongCount: json['wrongCount'] as int? ?? 0,
    leftCount: json['leftCount'] as int? ?? 0,
  );
}

class DailyStudyLog {
  final String id;
  final DateTime date;
  final String subject;
  final String topic;
  final double hours;
  final int mcqsSolved;
  final int mcqsCorrect;
  final String? notes;

  DailyStudyLog({
    required this.id,
    required this.date,
    required this.subject,
    required this.topic,
    required this.hours,
    required this.mcqsSolved,
    required this.mcqsCorrect,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'subject': subject,
    'topic': topic,
    'hours': hours,
    'mcqsSolved': mcqsSolved,
    'mcqsCorrect': mcqsCorrect,
    'notes': notes,
  };

  factory DailyStudyLog.fromJson(Map<String, dynamic> json) => DailyStudyLog(
    id: json['id'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
    subject: json['subject'] as String,
    topic: json['topic'] as String,
    hours: (json['hours'] as num).toDouble(),
    mcqsSolved: json['mcqsSolved'] as int,
    mcqsCorrect: json['mcqsCorrect'] as int,
    notes: json['notes'] as String?,
  );

  double get accuracy => mcqsSolved > 0 ? (mcqsCorrect / mcqsSolved) * 100 : 0;
}

class BookmarkedQuestion {
  final String id;
  final String question;
  final String subject;
  final String chapter;
  final String? answer;
  final DateTime bookmarkedDate;
  final bool isWeak;

  BookmarkedQuestion({
    required this.id,
    required this.question,
    required this.subject,
    required this.chapter,
    this.answer,
    required this.bookmarkedDate,
    this.isWeak = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'subject': subject,
    'chapter': chapter,
    'answer': answer,
    'bookmarkedDate': bookmarkedDate.millisecondsSinceEpoch,
    'isWeak': isWeak,
  };

  factory BookmarkedQuestion.fromJson(Map<String, dynamic> json) => BookmarkedQuestion(
    id: json['id'] as String,
    question: json['question'] as String,
    subject: json['subject'] as String,
    chapter: json['chapter'] as String,
    answer: json['answer'] as String?,
    bookmarkedDate: DateTime.fromMillisecondsSinceEpoch(json['bookmarkedDate'] as int),
    isWeak: json['isWeak'] as bool? ?? true,
  );
}

class PyqYearData {
  final int year;
  final int physicsTotal;
  final int chemistryTotal;
  final int biologyTotal;
  final int cutoffGeneral;
  final int cutoffObc;
  final int cutoffSc;
  final int cutoffSt;
  final String difficulty;

  const PyqYearData({
    required this.year,
    required this.physicsTotal,
    required this.chemistryTotal,
    required this.biologyTotal,
    required this.cutoffGeneral,
    required this.cutoffObc,
    required this.cutoffSc,
    required this.cutoffSt,
    required this.difficulty,
  });
}

class NeetData {
  static double getPercentile(int marks) {
    if (marks >= 720) return 99.9999;
    if (marks <= 0) return 0.0;
    final data = [
      [720, 99.9999], [710, 99.9995], [700, 99.998], [690, 99.995],
      [680, 99.99], [670, 99.98], [660, 99.95], [650, 99.90],
      [640, 99.80], [630, 99.65], [620, 99.45], [610, 99.20],
      [600, 98.85], [590, 98.40], [580, 97.80], [570, 97.10],
      [560, 96.30], [550, 95.40], [540, 94.30], [530, 93.10],
      [520, 91.70], [510, 90.20], [500, 88.50], [490, 86.60],
      [480, 84.50], [470, 82.20], [460, 79.70], [450, 77.00],
      [440, 74.10], [430, 71.00], [420, 67.70], [410, 64.30],
      [400, 60.70], [390, 57.00], [380, 53.20], [370, 49.30],
      [360, 45.30], [350, 41.30], [340, 37.30], [330, 33.30],
      [320, 29.40], [310, 25.60], [300, 22.00], [290, 18.60],
      [280, 15.50], [270, 12.70], [260, 10.20], [250, 8.00],
      [240, 6.10], [230, 4.50], [220, 3.20], [210, 2.20],
      [200, 1.40], [190, 0.85], [180, 0.45], [170, 0.20],
      [160, 0.08], [150, 0.03], [140, 0.01], [130, 0.005],
      [120, 0.002], [110, 0.001], [100, 0.0005], [0, 0.0],
    ];
    for (int i = 0; i < data.length - 1; i++) {
      if (marks >= data[i + 1][0] && marks <= data[i][0]) {
        final fraction = (marks - data[i + 1][0]) / (data[i][0] - data[i + 1][0]);
        return data[i + 1][1] + (data[i][1] - data[i + 1][1]) * fraction;
      }
    }
    return 0.0;
  }

  static int getAir(double percentile) {
    if (percentile >= 99.9999) return 1;
    if (percentile <= 0) return 2500000;
    final data = [
      [99.9999, 1], [99.9995, 5], [99.999, 10], [99.998, 20],
      [99.995, 50], [99.99, 100], [99.98, 200], [99.95, 500],
      [99.90, 1000], [99.80, 2300], [99.65, 5000], [99.45, 10000],
      [99.20, 18400], [98.85, 26500], [98.40, 36800], [97.80, 50600],
      [97.10, 66700], [96.30, 85100], [95.40, 105800], [94.30, 131100],
      [93.10, 158700], [91.70, 190900], [90.20, 225400], [88.50, 264500],
      [86.60, 308200], [84.50, 356500], [82.20, 409400], [79.70, 467100],
      [77.00, 529000], [74.10, 595500], [71.00, 667000], [67.70, 743000],
      [64.30, 822000], [60.70, 904000], [57.00, 989000], [53.20, 1076000],
      [49.30, 1166000], [45.30, 1258000], [41.30, 1351000], [37.30, 1444000],
      [33.30, 1537000], [29.40, 1629000], [25.60, 1720000], [22.00, 1809000],
      [18.60, 1895000], [15.50, 1977000], [12.70, 2054000], [10.20, 2125000],
      [8.00, 2191000], [6.10, 2250000], [4.50, 2302000], [3.20, 2347000],
      [2.20, 2385000], [1.40, 2417000], [0.85, 2443000], [0.45, 2464000],
      [0.20, 2479000], [0.08, 2489000], [0.03, 2495000], [0.01, 2498000],
    ];
    for (int i = 0; i < data.length - 1; i++) {
      if (percentile <= data[i][1] && percentile >= data[i + 1][1]) {
        final fraction = (percentile - data[i + 1][1]) / (data[i][1] - data[i + 1][1]);
        return (data[i + 1][0] + (data[i][0] - data[i + 1][0]) * fraction).round();
      }
    }
    return 2500000;
  }

  static String getCollegePrediction(int marks) {
    if (marks >= 680) return 'AIIMS Delhi / Top 10';
    if (marks >= 665) return 'AIIMS / MAMC / VMMC';
    if (marks >= 650) return 'Top Government Medical College';
    if (marks >= 610) return 'Government Medical College';
    if (marks >= 550) return 'Private Medical College';
    return 'Need improvement for MBBS';
  }

  static Color getMarksColor(int marks) {
    if (marks >= 650) return const Color(0xFF4CAF50);
    if (marks >= 550) return const Color(0xFFFFC107);
    if (marks >= 400) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  static String getSubjectAdvice(String subject, double percentage) {
    if (percentage >= 85) return 'Excellent! Maintain this level.';
    if (percentage >= 70) return 'Good. Focus on weak topics to reach 85%.';
    if (percentage >= 55) return 'Average. Need dedicated practice daily.';
    if (percentage >= 40) return 'Below average. Prioritize this subject.';
    return 'Critical! This subject needs maximum attention.';
  }

  static final Map<String, Map<String, int>> collegeCutoffs = {
    'AIIMS Delhi': {'2024': 680, '2023': 695, '2022': 710},
    'AIIMS Bhopal': {'2024': 665, '2023': 680, '2022': 695},
    'AIIMS Jodhpur': {'2024': 660, '2023': 675, '2022': 690},
    'AIIMS Patna': {'2024': 650, '2023': 665, '2022': 680},
    'AIIMS Rishikesh': {'2024': 655, '2023': 670, '2022': 685},
    'MAMC Delhi': {'2024': 675, '2023': 690, '2022': 705},
    'VMMC Delhi': {'2024': 670, '2023': 685, '2022': 700},
    'UCMS Delhi': {'2024': 665, '2023': 680, '2022': 695},
    'BHU Varanasi': {'2024': 660, '2023': 675, '2022': 690},
    'JIPMER Puducherry': {'2024': 670, '2023': 685, '2022': 700},
    'Seth GS Mumbai': {'2024': 665, '2023': 680, '2022': 695},
    'KGMU Lucknow': {'2024': 660, '2023': 675, '2022': 690},
    'Govt Medical College': {'2024': 610, '2023': 620, '2022': 635},
    'Private Medical College': {'2024': 550, '2023': 560, '2022': 570},
  };

  static const Map<String, int> subjectMarks = {
    'Physics': 180,
    'Chemistry': 180,
    'Biology': 360,
  };

  static const Map<String, List<Map<String, dynamic>>> chapterPresets = {
    'Physics': [
      {'name': 'Mechanics',           'weight': 25, 'total': 100, 'ncert': 'Ch 3-7', 'priority': 'High'},
      {'name': 'Electrostatics',      'weight': 20, 'total': 100, 'ncert': 'Ch 1-2', 'priority': 'High'},
      {'name': 'Current Electricity', 'weight': 15, 'total': 100, 'ncert': 'Ch 3', 'priority': 'Medium'},
      {'name': 'Magnetism',           'weight': 15, 'total': 100, 'ncert': 'Ch 4-5', 'priority': 'Medium'},
      {'name': 'Optics',              'weight': 15, 'total': 100, 'ncert': 'Ch 9-10', 'priority': 'Medium'},
      {'name': 'Modern Physics',      'weight': 10, 'total': 100, 'ncert': 'Ch 11-15', 'priority': 'Low'},
    ],
    'Chemistry': [
      {'name': 'Physical Chemistry',  'weight': 30, 'total': 100, 'ncert': 'Ch 1-5', 'priority': 'High'},
      {'name': 'Organic Chemistry',   'weight': 35, 'total': 100, 'ncert': 'Ch 10-16', 'priority': 'High'},
      {'name': 'Inorganic Chemistry', 'weight': 35, 'total': 100, 'ncert': 'Ch 7-9', 'priority': 'High'},
    ],
    'Biology': [
      {'name': 'Zoology – Animal Kingdom',   'weight': 15, 'total': 100, 'ncert': 'Ch 4', 'priority': 'Medium'},
      {'name': 'Zoology – Human Physiology', 'weight': 25, 'total': 100, 'ncert': 'Ch 16-22', 'priority': 'High'},
      {'name': 'Zoology – Reproduction',     'weight': 10, 'total': 100, 'ncert': 'Ch 1-4', 'priority': 'Medium'},
      {'name': 'Botany – Plant Kingdom',     'weight': 10, 'total': 100, 'ncert': 'Ch 3', 'priority': 'Medium'},
      {'name': 'Botany – Plant Physiology',  'weight': 20, 'total': 100, 'ncert': 'Ch 11-15', 'priority': 'High'},
      {'name': 'Botany – Ecology & Env',     'weight': 20, 'total': 100, 'ncert': 'Ch 13-16', 'priority': 'Medium'},
    ],
  };

  static const List<Map<String, dynamic>> rankRanges = [
    {'min': 710, 'max': 720, 'rank': '1 – 50',       'tier': 'AIIMS Delhi (Top 50)'},
    {'min': 690, 'max': 709, 'rank': '51 – 500',     'tier': 'AIIMS + Top GMCs'},
    {'min': 650, 'max': 689, 'rank': '501 – 5,000',  'tier': 'Good GMCs'},
    {'min': 600, 'max': 649, 'rank': '5,001 – 15,000','tier': 'State GMCs'},
    {'min': 550, 'max': 599, 'rank': '15,001 – 40,000','tier': 'Private / Deemed'},
    {'min': 500, 'max': 549, 'rank': '40,001 – 80,000','tier': 'Borderline Private'},
    {'min': 400, 'max': 499, 'rank': '80,001 – 2,00,000','tier': 'Very Low Chance'},
    {'min': 0,   'max': 399, 'rank': '2,00,000+',     'tier': 'Need Major Improvement'},
  ];

  static Map<String, dynamic> predictRank(double score) {
    for (final range in rankRanges) {
      if (score >= range['min']! && score <= range['max']!) return range;
    }
    return rankRanges.last;
  }

  static const List<String> motivationQuotes = [
    'Consistency beats intensity. Every MCQ counts.',
    'Your competition is with yourself, not others.',
    'One chapter a day keeps low rank away.',
    'Revision is the key to retention.',
    'PYQs are your best teachers.',
    'Biology is 50% of NEET — master it first.',
    'Small daily improvements lead to stunning results.',
    'Believe in yourself. You are closer than you think.',
    'Every wrong answer is a step towards the right one.',
    'The expert in anything was once a beginner.',
  ];

  static const List<PyqYearData> pyqYears = [
    PyqYearData(year: 2024, physicsTotal: 180, chemistryTotal: 180, biologyTotal: 360, cutoffGeneral: 720, cutoffObc: 716, cutoffSc: 650, cutoffSt: 640, difficulty: 'Hard'),
    PyqYearData(year: 2023, physicsTotal: 180, chemistryTotal: 180, biologyTotal: 360, cutoffGeneral: 720, cutoffObc: 716, cutoffSc: 650, cutoffSt: 640, difficulty: 'Medium'),
    PyqYearData(year: 2022, physicsTotal: 180, chemistryTotal: 180, biologyTotal: 360, cutoffGeneral: 715, cutoffObc: 711, cutoffSc: 645, cutoffSt: 635, difficulty: 'Medium'),
    PyqYearData(year: 2021, physicsTotal: 180, chemistryTotal: 180, biologyTotal: 360, cutoffGeneral: 720, cutoffObc: 716, cutoffSc: 650, cutoffSt: 640, difficulty: 'Easy'),
    PyqYearData(year: 2020, physicsTotal: 180, chemistryTotal: 180, biologyTotal: 360, cutoffGeneral: 720, cutoffObc: 716, cutoffSc: 650, cutoffSt: 640, difficulty: 'Medium'),
    PyqYearData(year: 2019, physicsTotal: 180, chemistryTotal: 180, biologyTotal: 360, cutoffGeneral: 701, cutoffObc: 695, cutoffSc: 640, cutoffSt: 630, difficulty: 'Hard'),
  ];

  static const Map<String, List<Map<String, String>>> chapterResources = {
    'Mechanics': [
      {'title': 'Physics Wallah - Mechanics', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 3-7', 'type': 'Book'},
      {'title': 'HC Verma Mechanics', 'type': 'Book'},
    ],
    'Electrostatics': [
      {'title': 'Unacademy NEET - Electrostatics', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 1-2', 'type': 'Book'},
    ],
    'Current Electricity': [
      {'title': 'Khan Academy - Current Electricity', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 3', 'type': 'Book'},
    ],
    'Magnetism': [
      {'title': 'Physics Wallah - Magnetism', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 4-5', 'type': 'Book'},
    ],
    'Optics': [
      {'title': 'Unacademy - Optics', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 9-10', 'type': 'Book'},
    ],
    'Modern Physics': [
      {'title': 'Physics Wallah - Modern Physics', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 11-15', 'type': 'Book'},
    ],
    'Physical Chemistry': [
      {'title': 'Unacademy - Physical Chemistry', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 1-5', 'type': 'Book'},
      {'title': 'OP Tandon Physical Chemistry', 'type': 'Book'},
    ],
    'Organic Chemistry': [
      {'title': 'Physics Wallah - Organic Chemistry', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 10-16', 'type': 'Book'},
      {'title': 'MS Chauhan Organic', 'type': 'Book'},
    ],
    'Inorganic Chemistry': [
      {'title': 'Unacademy - Inorganic Chemistry', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 7-9', 'type': 'Book'},
    ],
    'Zoology – Animal Kingdom': [
      {'title': 'Biology Wallah - Animal Kingdom', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 4', 'type': 'Book'},
    ],
    'Zoology – Human Physiology': [
      {'title': 'Unacademy - Human Physiology', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 16-22', 'type': 'Book'},
    ],
    'Zoology – Reproduction': [
      {'title': 'Biology Wallah - Reproduction', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 1-4', 'type': 'Book'},
    ],
    'Botany – Plant Kingdom': [
      {'title': 'Unacademy - Plant Kingdom', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 3', 'type': 'Book'},
    ],
    'Botany – Plant Physiology': [
      {'title': 'Biology Wallah - Plant Physiology', 'type': 'Video'},
      {'title': 'NCERT Class 11 Ch 11-15', 'type': 'Book'},
    ],
    'Botany – Ecology & Env': [
      {'title': 'Unacademy - Ecology', 'type': 'Video'},
      {'title': 'NCERT Class 12 Ch 13-16', 'type': 'Book'},
    ],
  };

  static const Map<String, Map<String, int>> weeklyTargets = {
    'Physics': {'mcqs': 150, 'hours': 15, 'revision_chapters': 2},
    'Chemistry': {'mcqs': 150, 'hours': 15, 'revision_chapters': 2},
    'Biology': {'mcqs': 300, 'hours': 20, 'revision_chapters': 3},
  };

  // NEW: Important formulas by subject
  static const Map<String, List<Map<String, String>>> quickFormulas = {
    'Physics': [
      {'name': 'Kinematics', 'formula': 'v = u + at, s = ut + ½at², v² = u² + 2as'},
      {'name': 'Newton\'s 2nd Law', 'formula': 'F = ma'},
      {'name': 'Work-Energy', 'formula': 'W = F·d·cosθ, KE = ½mv², PE = mgh'},
      {'name': 'Coulomb\'s Law', 'formula': 'F = k(q₁q₂)/r²'},
      {'name': 'Ohm\'s Law', 'formula': 'V = IR, P = VI = I²R'},
      {'name': 'Lens Formula', 'formula': '1/f = 1/v + 1/u'},
    ],
    'Chemistry': [
      {'name': 'Ideal Gas', 'formula': 'PV = nRT'},
      {'name': 'Molarity', 'formula': 'M = n/V (mol/L)'},
      {'name': 'pH', 'formula': 'pH = -log[H⁺], pOH = -log[OH⁻]'},
      {'name': 'Nernst Equation', 'formula': 'E = E° - (RT/nF)lnQ'},
      {'name': 'First Order', 'formula': 'k = (2.303/t)log(a/(a-x))'},
    ],
    'Biology': [
      {'name': 'Hardy-Weinberg', 'formula': 'p² + 2pq + q² = 1'},
      {'name': 'Photosynthesis', 'formula': '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂'},
      {'name': 'Respiration', 'formula': 'C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + ATP'},
      {'name': 'Cell Cycle', 'formula': 'G₁ → S → G₂ → M (mitosis/meiosis)'},
    ],
  };
}

class MockTestStorage {
  static const String _key = 'neet_mock_tests_v2';

  static Future<List<MockTestResult>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => MockTestResult.fromJson(e)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(MockTestResult test) async {
    final all = await getAll();
    all.removeWhere((t) => t.id == test.id);
    all.add(test);
    while (all.length > 100) all.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((t) => t.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class StudyLogStorage {
  static const String _key = 'neet_study_logs_v1';

  static Future<List<DailyStudyLog>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => DailyStudyLog.fromJson(e)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(DailyStudyLog log) async {
    final all = await getAll();
    all.removeWhere((l) => l.id == log.id);
    all.add(log);
    while (all.length > 365) all.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String logId) async {
    final all = await getAll();
    all.removeWhere((l) => l.id == logId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<List<DailyStudyLog>> getLogsForDate(DateTime date) async {
    final all = await getAll();
    return all.where((l) =>
      l.date.year == date.year && l.date.month == date.month && l.date.day == date.day
    ).toList();
  }

  static Future<List<DailyStudyLog>> getLogsForWeek(DateTime date) async {
    final all = await getAll();
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return all.where((l) =>
      l.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
      l.date.isBefore(weekEnd)
    ).toList();
  }

  static Future<Map<String, dynamic>> getWeeklyStats(DateTime date) async {
    final logs = await getLogsForWeek(date);
    double totalHours = 0;
    int totalMcqs = 0;
    int totalCorrect = 0;
    final subjectHours = <String, double>{};
    final subjectMcqs = <String, int>{};

    for (final log in logs) {
      totalHours += log.hours;
      totalMcqs += log.mcqsSolved;
      totalCorrect += log.mcqsCorrect;
      subjectHours[log.subject] = (subjectHours[log.subject] ?? 0) + log.hours;
      subjectMcqs[log.subject] = (subjectMcqs[log.subject] ?? 0) + log.mcqsSolved;
    }

    return {
      'totalHours': totalHours,
      'totalMcqs': totalMcqs,
      'totalCorrect': totalCorrect,
      'accuracy': totalMcqs > 0 ? (totalCorrect / totalMcqs) * 100 : 0.0,
      'subjectHours': subjectHours,
      'subjectMcqs': subjectMcqs,
      'daysActive': logs.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet().length,
    };
  }
}

class BookmarkStorage {
  static const String _key = 'neet_bookmarks_v1';

  static Future<List<BookmarkedQuestion>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => BookmarkedQuestion.fromJson(e)).toList()
        ..sort((a, b) => b.bookmarkedDate.compareTo(a.bookmarkedDate));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(BookmarkedQuestion bm) async {
    final all = await getAll();
    all.removeWhere((b) => b.id == bm.id);
    all.add(bm);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((b) => b.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}

class _GradeCalcPrefs {
  static const String _prefix = 'grade_calc_v6_';
  static String diff(int id)     => '${_prefix}diff_$id';
  static String hours(int id)    => '${_prefix}hours_$id';
  static String chapter(int id)  => '${_prefix}chapter_$id';
  static String examDate(int id) => '${_prefix}examdate_$id';
  static String revisionRound(int id) => '${_prefix}rev_$id';
  static String pyqDone(int id)  => '${_prefix}pyq_$id';
  static String get whatIf       => '${_prefix}whatif';
  static String get lastPreset   => '${_prefix}last_preset';
  static String get neetExamDate => '${_prefix}neet_exam_date';
  static String get dailyPhyTarget => '${_prefix}daily_phy_target';
  static String get dailyChemTarget => '${_prefix}daily_chem_target';
  static String get dailyBioTarget => '${_prefix}daily_bio_target';
  static String get dailyPhyDone => '${_prefix}daily_phy_done';
  static String get dailyChemDone => '${_prefix}daily_chem_done';
  static String get dailyBioDone => '${_prefix}daily_bio_done';
  static String get dailyDate    => '${_prefix}daily_date';
  static String get studyStreak  => '${_prefix}study_streak';
  static String get lastStudyDate => '${_prefix}last_study_date';
  static String get parentNotes  => '${_prefix}parent_notes';
  static String get childName    => '${_prefix}child_name';
  static String get targetCollege => '${_prefix}target_college';
  static String get targetScore  => '${_prefix}target_score';
  static String get weeklyGoalPhy => '${_prefix}weekly_goal_phy';
  static String get weeklyGoalChem => '${_prefix}weekly_goal_chem';
  static String get weeklyGoalBio => '${_prefix}weekly_goal_bio';
  static String get quizHighScore => '${_prefix}quiz_high_score';
  static String get quizStreak    => '${_prefix}quiz_streak';
}

class GradeCalculatorScreen extends StatefulWidget {
  const GradeCalculatorScreen({super.key});
  @override
  State<GradeCalculatorScreen> createState() => _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends State<GradeCalculatorScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;
  Timer? _refreshTimer;
  SharedPreferences? _prefsCache;

  List<Map<String, dynamic>> _components = [];
  bool _loading = true;

  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _scoreController = TextEditingController();
  final _totalController = TextEditingController(text: '100');
  final _hoursController = TextEditingController();
  final _targetGradeController = TextEditingController();
  final _physicsMarksController = TextEditingController();
  final _chemistryMarksController = TextEditingController();
  final _biologyMarksController = TextEditingController();
  final _correctController = TextEditingController();
  final _wrongController = TextEditingController();
  final _leftController = TextEditingController();
  final _dailyPhyTargetController = TextEditingController(text: '50');
  final _dailyChemTargetController = TextEditingController(text: '50');
  final _dailyBioTargetController = TextEditingController(text: '100');

  // Parent-focused controllers
  final _childNameController = TextEditingController();
  final _targetScoreController = TextEditingController(text: '650');
  final _parentNotesController = TextEditingController();
  final _logSubjectController = TextEditingController();
  final _logTopicController = TextEditingController();
  final _logHoursController = TextEditingController();
  final _logMcqsController = TextEditingController();
  final _logCorrectController = TextEditingController();
  final _logNotesController = TextEditingController();
  final _bookmarkQuestionController = TextEditingController();
  final _bookmarkAnswerController = TextEditingController();

  String _selectedDifficulty = 'Medium';
  String _selectedChapterTag = '';
  String _selectedLogSubject = 'Physics';
  String _selectedBookmarkSubject = 'Physics';
  bool _showWhatIf = false;
  Map<int, double> _whatIfScores = {};

  final List<String> _chapterTags = [
    'Mechanics','Electrostatics','Current Electricity','Magnetism',
    'Optics','Modern Physics','Physical Chemistry','Organic Chemistry',
    'Inorganic Chemistry','Zoology – Animal Kingdom','Zoology – Human Physiology',
    'Zoology – Reproduction','Botany – Plant Kingdom','Botany – Plant Physiology',
    'Botany – Ecology & Env','Other'
  ];
  final List<String> _difficulties = ['Easy','Medium','Hard'];
  final List<String> _subjects = ['Physics', 'Chemistry', 'Biology'];

  List<MockTestResult> _mockTests = [];
  bool _loadingMocks = true;

  List<DailyStudyLog> _studyLogs = [];
  bool _loadingLogs = true;

  List<BookmarkedQuestion> _bookmarks = [];
  bool _loadingBookmarks = true;

  DateTime? _neetExamDate;
  int _dailyPhyDone = 0;
  int _dailyChemDone = 0;
  int _dailyBioDone = 0;
  int _dailyPhyTarget = 50;
  int _dailyChemTarget = 50;
  int _dailyBioTarget = 100;

  int _studyStreak = 0;
  DateTime? _lastStudyDate;
  String _childName = '';
  String _targetCollege = 'AIIMS Delhi';
  int _targetScore = 650;
  String _parentNotes = '';
  int _weeklyGoalPhy = 150;
  int _weeklyGoalChem = 150;
  int _weeklyGoalBio = 300;
  int _quizHighScore = 0;
  int _quizStreak = 0;

  int _selectedFormulaSubject = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initPrefs();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); });
  }

  Future<void> _initPrefs() async {
    _prefsCache = await SharedPreferences.getInstance();
    await _loadAllData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _scoreController.dispose();
    _totalController.dispose();
    _hoursController.dispose();
    _targetGradeController.dispose();
    _physicsMarksController.dispose();
    _chemistryMarksController.dispose();
    _biologyMarksController.dispose();
    _correctController.dispose();
    _wrongController.dispose();
    _leftController.dispose();
    _dailyPhyTargetController.dispose();
    _dailyChemTargetController.dispose();
    _dailyBioTargetController.dispose();
    _childNameController.dispose();
    _targetScoreController.dispose();
    _parentNotesController.dispose();
    _logSubjectController.dispose();
    _logTopicController.dispose();
    _logHoursController.dispose();
    _logMcqsController.dispose();
    _logCorrectController.dispose();
    _logNotesController.dispose();
    _bookmarkQuestionController.dispose();
    _bookmarkAnswerController.dispose();
    super.dispose();
  }

  // CRITICAL FIX: Cached SharedPreferences to avoid multiple getInstance() calls
  SharedPreferences get _prefs {
    if (_prefsCache == null) {
      throw StateError('SharedPreferences not initialized. Call _initPrefs() first.');
    }
    return _prefsCache!;
  }

  // ═════════════════════════════════════════════════════════════════
  // FIXED PERSISTENCE HELPERS — Cached _prefs, no getKeys()
  // ═════════════════════════════════════════════════════════════════

  Future<void> _safeSetString(String key, String value) async {
    try { _prefs.setString(key, value); } catch (e) { debugPrint('Prefs error: $e'); }
  }
  Future<void> _safeSetInt(String key, int value) async {
    try { _prefs.setInt(key, value); } catch (e) { debugPrint('Prefs error: $e'); }
  }
  Future<void> _safeSetDouble(String key, double value) async {
    try { _prefs.setDouble(key, value); } catch (e) { debugPrint('Prefs error: $e'); }
  }
  Future<void> _safeSetBool(String key, bool value) async {
    try { _prefs.setBool(key, value); } catch (e) { debugPrint('Prefs error: $e'); }
  }
  Future<void> _safeRemove(String key) async {
    try { _prefs.remove(key); } catch (e) { debugPrint('Prefs error: $e'); }
  }

  // CRITICAL FIX: No getKeys() — iterate through known keys instead
  Future<void> _clearAllGradePrefs() async {
    try {
      final prefix = 'grade_calc_v6_';
      // Get all keys by checking known patterns instead of getKeys()
      final allKeys = <String>[];
      for (int i = 0; i < 1000; i++) {
        allKeys.add('${prefix}diff_$i');
        allKeys.add('${prefix}hours_$i');
        allKeys.add('${prefix}chapter_$i');
        allKeys.add('${prefix}examdate_$i');
        allKeys.add('${prefix}rev_$i');
        allKeys.add('${prefix}pyq_$i');
      }
      // Also add non-ID keys
      allKeys.addAll([
        _GradeCalcPrefs.whatIf,
        _GradeCalcPrefs.lastPreset,
        _GradeCalcPrefs.neetExamDate,
        _GradeCalcPrefs.dailyPhyTarget,
        _GradeCalcPrefs.dailyChemTarget,
        _GradeCalcPrefs.dailyBioTarget,
        _GradeCalcPrefs.dailyPhyDone,
        _GradeCalcPrefs.dailyChemDone,
        _GradeCalcPrefs.dailyBioDone,
        _GradeCalcPrefs.dailyDate,
        _GradeCalcPrefs.studyStreak,
        _GradeCalcPrefs.lastStudyDate,
        _GradeCalcPrefs.parentNotes,
        _GradeCalcPrefs.childName,
        _GradeCalcPrefs.targetCollege,
        _GradeCalcPrefs.targetScore,
        _GradeCalcPrefs.weeklyGoalPhy,
        _GradeCalcPrefs.weeklyGoalChem,
        _GradeCalcPrefs.weeklyGoalBio,
        _GradeCalcPrefs.quizHighScore,
        _GradeCalcPrefs.quizStreak,
      ]);
      
      for (final key in allKeys) {
        if (_prefs.containsKey(key)) {
          await _prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Clear all prefs error: $e');
    }
  }

  Future<void> _setDifficulty(int id, String d) async => _safeSetString(_GradeCalcPrefs.diff(id), d);
  Future<String> _getDifficulty(int id) async {
    try { return _prefs.getString(_GradeCalcPrefs.diff(id)) ?? 'Medium'; }
    catch (e) { return 'Medium'; }
  }
  Future<void> _setHours(int id, double h) async => _safeSetDouble(_GradeCalcPrefs.hours(id), h);
  Future<double> _getHours(int id) async {
    try { return _prefs.getDouble(_GradeCalcPrefs.hours(id)) ?? 0; }
    catch (e) { return 0; }
  }
  Future<void> _setChapterTag(int id, String t) async => _safeSetString(_GradeCalcPrefs.chapter(id), t);
  Future<String> _getChapterTag(int id) async {
    try { return _prefs.getString(_GradeCalcPrefs.chapter(id)) ?? ''; }
    catch (e) { return ''; }
  }
  Future<void> _setExamDate(int id, int? millis) async {
    if (millis == null) { await _safeRemove(_GradeCalcPrefs.examDate(id)); }
    else { await _safeSetInt(_GradeCalcPrefs.examDate(id), millis); }
  }
  Future<int?> _getExamDate(int id) async {
    try { return _prefs.getInt(_GradeCalcPrefs.examDate(id)); }
    catch (e) { return null; }
  }
  Future<void> _setRevisionRound(int id, int round) async => _safeSetInt(_GradeCalcPrefs.revisionRound(id), round);
  Future<int> _getRevisionRound(int id) async {
    try { return _prefs.getInt(_GradeCalcPrefs.revisionRound(id)) ?? 0; }
    catch (e) { return 0; }
  }
  Future<void> _setPyqDone(int id, bool done) async => _safeSetBool(_GradeCalcPrefs.pyqDone(id), done);
  Future<bool> _getPyqDone(int id) async {
    try { return _prefs.getBool(_GradeCalcPrefs.pyqDone(id)) ?? false; }
    catch (e) { return false; }
  }
  Future<void> _saveWhatIfValues() async {
    final map = _whatIfScores.map((k, v) => MapEntry(k.toString(), v));
    await _safeSetString(_GradeCalcPrefs.whatIf, jsonEncode(map));
  }
  Future<void> _loadWhatIfValues() async {
    try {
      final raw = _prefs.getString(_GradeCalcPrefs.whatIf);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _whatIfScores = decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
      }
    } catch (e) { _whatIfScores = {}; }
  }
  Future<void> _setLastPreset(String preset) async => _safeSetString(_GradeCalcPrefs.lastPreset, preset);
  Future<void> _setNeetExamDate(int millis) async => _safeSetInt(_GradeCalcPrefs.neetExamDate, millis);
  Future<int?> _getNeetExamDate() async {
    try { return _prefs.getInt(_GradeCalcPrefs.neetExamDate); }
    catch (e) { return null; }
  }

  Future<void> _loadDailyTargets() async {
    try {
      final savedDate = _prefs.getString(_GradeCalcPrefs.dailyDate);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (savedDate != today) {
        await _prefs.setInt(_GradeCalcPrefs.dailyPhyDone, 0);
        await _prefs.setInt(_GradeCalcPrefs.dailyChemDone, 0);
        await _prefs.setInt(_GradeCalcPrefs.dailyBioDone, 0);
        await _prefs.setString(_GradeCalcPrefs.dailyDate, today);
      }
      _dailyPhyTarget = _prefs.getInt(_GradeCalcPrefs.dailyPhyTarget) ?? 50;
      _dailyChemTarget = _prefs.getInt(_GradeCalcPrefs.dailyChemTarget) ?? 50;
      _dailyBioTarget = _prefs.getInt(_GradeCalcPrefs.dailyBioTarget) ?? 100;
      _dailyPhyDone = _prefs.getInt(_GradeCalcPrefs.dailyPhyDone) ?? 0;
      _dailyChemDone = _prefs.getInt(_GradeCalcPrefs.dailyChemDone) ?? 0;
      _dailyBioDone = _prefs.getInt(_GradeCalcPrefs.dailyBioDone) ?? 0;
      _dailyPhyTargetController.text = _dailyPhyTarget.toString();
      _dailyChemTargetController.text = _dailyChemTarget.toString();
      _dailyBioTargetController.text = _dailyBioTarget.toString();
    } catch (e) { debugPrint('Load daily targets error: $e'); }
  }

  Future<void> _saveDailyTargets() async {
    try {
      await _prefs.setInt(_GradeCalcPrefs.dailyPhyTarget, int.tryParse(_dailyPhyTargetController.text) ?? 50);
      await _prefs.setInt(_GradeCalcPrefs.dailyChemTarget, int.tryParse(_dailyChemTargetController.text) ?? 50);
      await _prefs.setInt(_GradeCalcPrefs.dailyBioTarget, int.tryParse(_dailyBioTargetController.text) ?? 100);
    } catch (e) { debugPrint('Save daily targets error: $e'); }
  }

  Future<void> _incrementDailyDone(String subject) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _prefs.setString(_GradeCalcPrefs.dailyDate, today);
      if (subject == 'Physics') {
        _dailyPhyDone++;
        await _prefs.setInt(_GradeCalcPrefs.dailyPhyDone, _dailyPhyDone);
      } else if (subject == 'Chemistry') {
        _dailyChemDone++;
        await _prefs.setInt(_GradeCalcPrefs.dailyChemDone, _dailyChemDone);
      } else if (subject == 'Biology') {
        _dailyBioDone++;
        await _prefs.setInt(_GradeCalcPrefs.dailyBioDone, _dailyBioDone);
      }
      await _updateStudyStreak();
      setState(() {});
    } catch (e) { debugPrint('Increment daily done error: $e'); }
  }

  Future<void> _updateStudyStreak() async {
    try {
      final today = DateTime.now();
      final lastDateStr = _prefs.getString(_GradeCalcPrefs.lastStudyDate);
      if (lastDateStr != null) {
        final lastDate = DateTime.parse(lastDateStr);
        final diff = today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;
        if (diff == 1) {
          _studyStreak = (_prefs.getInt(_GradeCalcPrefs.studyStreak) ?? 0) + 1;
        } else if (diff > 1) {
          _studyStreak = 1;
        } else {
          _studyStreak = _prefs.getInt(_GradeCalcPrefs.studyStreak) ?? 0;
        }
      } else {
        _studyStreak = 1;
      }
      await _prefs.setInt(_GradeCalcPrefs.studyStreak, _studyStreak);
      await _prefs.setString(_GradeCalcPrefs.lastStudyDate, today.toIso8601String().substring(0, 10));
    } catch (e) { debugPrint('Streak error: $e'); }
  }

  Future<void> _loadParentData() async {
    try {
      _childName = _prefs.getString(_GradeCalcPrefs.childName) ?? '';
      _targetCollege = _prefs.getString(_GradeCalcPrefs.targetCollege) ?? 'AIIMS Delhi';
      _targetScore = _prefs.getInt(_GradeCalcPrefs.targetScore) ?? 650;
      _parentNotes = _prefs.getString(_GradeCalcPrefs.parentNotes) ?? '';
      _studyStreak = _prefs.getInt(_GradeCalcPrefs.studyStreak) ?? 0;
      _weeklyGoalPhy = _prefs.getInt(_GradeCalcPrefs.weeklyGoalPhy) ?? 150;
      _weeklyGoalChem = _prefs.getInt(_GradeCalcPrefs.weeklyGoalChem) ?? 150;
      _weeklyGoalBio = _prefs.getInt(_GradeCalcPrefs.weeklyGoalBio) ?? 300;
      _quizHighScore = _prefs.getInt(_GradeCalcPrefs.quizHighScore) ?? 0;
      _quizStreak = _prefs.getInt(_GradeCalcPrefs.quizStreak) ?? 0;
      _childNameController.text = _childName;
      _targetScoreController.text = _targetScore.toString();
      _parentNotesController.text = _parentNotes;
    } catch (e) { debugPrint('Load parent data error: $e'); }
  }

  Future<void> _saveParentData() async {
    try {
      await _prefs.setString(_GradeCalcPrefs.childName, _childNameController.text.trim());
      await _prefs.setString(_GradeCalcPrefs.targetCollege, _targetCollege);
      await _prefs.setInt(_GradeCalcPrefs.targetScore, int.tryParse(_targetScoreController.text) ?? 650);
      await _prefs.setString(_GradeCalcPrefs.parentNotes, _parentNotesController.text.trim());
      await _prefs.setInt(_GradeCalcPrefs.weeklyGoalPhy, _weeklyGoalPhy);
      await _prefs.setInt(_GradeCalcPrefs.weeklyGoalChem, _weeklyGoalChem);
      await _prefs.setInt(_GradeCalcPrefs.weeklyGoalBio, _weeklyGoalBio);
    } catch (e) { debugPrint('Save parent data error: $e'); }
  }

  Future<void> _loadAllData() async {
    await _loadComponents();
    await _loadMockTests();
    await _loadWhatIfValues();
    await _loadDailyTargets();
    await _loadParentData();
    await _loadStudyLogs();
    await _loadBookmarks();
    final examMillis = await _getNeetExamDate();
    if (examMillis != null) {
      _neetExamDate = DateTime.fromMillisecondsSinceEpoch(examMillis);
    }
  }

  Future<void> _loadComponents() async {
    if (mounted) setState(() => _loading = true);
    try {
      final components = await DatabaseHelper.instance.getAllGradeComponents();
      for (final c in components) {
        final id = c['id'] as int;
        try {
          c['difficulty'] = await _getDifficulty(id);
          c['hoursStudied'] = await _getHours(id);
          c['chapterTag'] = await _getChapterTag(id);
          c['examDateMillis'] = await _getExamDate(id);
          c['revisionRound'] = await _getRevisionRound(id);
          c['pyqDone'] = await _getPyqDone(id);
        } catch (e) {
          c['difficulty'] = 'Medium';
          c['hoursStudied'] = 0.0;
          c['chapterTag'] = '';
          c['examDateMillis'] = null;
          c['revisionRound'] = 0;
          c['pyqDone'] = false;
        }
      }
      if (mounted) setState(() { _components = components; });
    } catch (e) {
      debugPrint('Error loading components: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStudyLogs() async {
    try {
      final logs = await StudyLogStorage.getAll();
      if (mounted) setState(() { _studyLogs = logs; _loadingLogs = false; });
    } catch (e) {
      debugPrint('Load study logs error: $e');
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      final bms = await BookmarkStorage.getAll();
      if (mounted) setState(() { _bookmarks = bms; _loadingBookmarks = false; });
    } catch (e) {
      debugPrint('Load bookmarks error: $e');
      if (mounted) setState(() => _loadingBookmarks = false);
    }
  }

  Future<void> _addComponent() async {
    final name = _nameController.text.trim();
    final weight = double.tryParse(_weightController.text) ?? 0;
    final score = double.tryParse(_scoreController.text) ?? 0;
    final total = double.tryParse(_totalController.text) ?? 100;
    final hours = double.tryParse(_hoursController.text) ?? 0;
    if (name.isEmpty || weight <= 0 || score < 0 || total <= 0) return;

    final id = await DatabaseHelper.instance.insertGradeComponent({
      'name': name, 'weight': weight, 'score': score, 'totalPoints': total,
    });
    await _setDifficulty(id, _selectedDifficulty);
    await _setHours(id, hours);
    await _setChapterTag(id, _selectedChapterTag);

    HapticFeedback.lightImpact();
    _nameController.clear();
    _weightController.clear();
    _scoreController.clear();
    _totalController.text = '100';
    _hoursController.clear();
    _selectedDifficulty = 'Medium';
    _selectedChapterTag = '';
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  Future<void> _removeComponent(int id) async {
    await DatabaseHelper.instance.deleteGradeComponent(id);
    await _safeRemove(_GradeCalcPrefs.diff(id));
    await _safeRemove(_GradeCalcPrefs.hours(id));
    await _safeRemove(_GradeCalcPrefs.chapter(id));
    await _safeRemove(_GradeCalcPrefs.examDate(id));
    await _safeRemove(_GradeCalcPrefs.revisionRound(id));
    await _safeRemove(_GradeCalcPrefs.pyqDone(id));
    HapticFeedback.mediumImpact();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  // CRITICAL FIX: No getKeys() — use _clearAllGradePrefs() instead
  Future<void> _clearAllComponents() async {
    await DatabaseHelper.instance.clearGradeComponents();
    await _clearAllGradePrefs();
    _whatIfScores.clear();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  // CRITICAL FIX: Simplified preset loading without getKeys()
  Future<void> _loadPreset(String subject) async {
    if (mounted) setState(() => _loading = true);
    try {
      final preset = NeetData.chapterPresets[subject];
      if (preset == null) return;

      await DatabaseHelper.instance.clearGradeComponents();
      await _clearAllGradePrefs();

      for (final chapter in preset) {
        final id = await DatabaseHelper.instance.insertGradeComponent({
          'name': chapter['name'] as String,
          'weight': (chapter['weight'] as num).toDouble(),
          'score': 0,
          'totalPoints': (chapter['total'] as num).toDouble(),
        });
        await _setDifficulty(id, 'Medium');
        await _setChapterTag(id, chapter['name'] as String);
      }
      await _setLastPreset(subject);
      HapticFeedback.mediumImpact();
      await _loadComponents();
      await WidgetService.refreshWidget();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$subject preset loaded — ${preset.length} chapters'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: _subjectColor(subject),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading preset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preset: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFullNeetPreset() async {
    if (mounted) setState(() => _loading = true);
    try {
      await DatabaseHelper.instance.clearGradeComponents();
      await _clearAllGradePrefs();
      
      for (final entry in NeetData.chapterPresets.entries) {
        final subject = entry.key;
        for (final chapter in entry.value) {
          final id = await DatabaseHelper.instance.insertGradeComponent({
            'name': '$subject — ${chapter['name']}',
            'weight': ((chapter['weight'] as num) * NeetData.subjectMarks[subject]! / 100).toDouble(),
            'score': 0,
            'totalPoints': (chapter['total'] as num).toDouble(),
          });
          await _setDifficulty(id, 'Medium');
          await _setChapterTag(id, chapter['name'] as String);
        }
      }
      await _setLastPreset('Full NEET');
      HapticFeedback.mediumImpact();
      await _loadComponents();
      await WidgetService.refreshWidget();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full NEET preset loaded — all 15 chapters'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading full preset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preset: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // CALCULATION HELPERS
  // ═════════════════════════════════════════════════════════════════

  double get _currentGrade {
    double weightedScore = 0;
    double totalWeight = 0;
    for (final c in _components) {
      final score = (c['score'] as num).toDouble();
      final total = (c['totalPoints'] as num).toDouble();
      final weight = (c['weight'] as num).toDouble();
      final whatIf = _whatIfScores[c['id'] as int];
      final effectiveScore = whatIf ?? score;
      if (total > 0) {
        weightedScore += (effectiveScore / total) * weight;
        totalWeight += weight;
      }
    }
    if (totalWeight == 0) return 0;
    return (weightedScore / totalWeight) * 100;
  }

  double get _totalWeightUsed {
    return _components.fold(0.0, (sum, c) => sum + (c['weight'] as num).toDouble());
  }

  double get _remainingWeight {
    return (100.0 - _totalWeightUsed).clamp(0.0, 100.0);
  }

  String get _letterGrade {
    final g = _currentGrade;
    if (g >= 97) return 'A+';
    if (g >= 93) return 'A';
    if (g >= 90) return 'A-';
    if (g >= 87) return 'B+';
    if (g >= 83) return 'B';
    if (g >= 80) return 'B-';
    if (g >= 77) return 'C+';
    if (g >= 73) return 'C';
    if (g >= 70) return 'C-';
    if (g >= 67) return 'D+';
    if (g >= 63) return 'D';
    if (g >= 60) return 'D-';
    return 'F';
  }

  Color _gradeColor(double grade) {
    if (grade >= 90) return const Color(0xFF4CAF50);
    if (grade >= 80) return const Color(0xFF8BC34A);
    if (grade >= 70) return const Color(0xFFFFC107);
    if (grade >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  double _getEfficiencyScore(Map<String, dynamic> c) {
    final score = (c['score'] as num).toDouble();
    final total = (c['totalPoints'] as num).toDouble();
    final hours = (c['hoursStudied'] as num?)?.toDouble() ?? 0;
    if (hours <= 0 || total <= 0) return 0;
    return ((score / total) * 100) / hours;
  }

  String? _getSmartTarget() {
    if (_components.isEmpty) return null;
    final remaining = _remainingWeight;
    if (remaining <= 0) return null;
    const neetSafePercent = 83.3;
    final current = _currentGrade;
    final totalWeight = _totalWeightUsed;
    final needed = ((neetSafePercent * 100) - (current * totalWeight)) / remaining;
    if (needed > 100) return 'Impossible to reach safe score — reduce weight or improve existing';
    if (needed < 0) return 'Already above NEET safe score! 🎉';
    return 'Need ${needed.toStringAsFixed(1)}% on remaining ${remaining.toStringAsFixed(1)}% to hit NEET safe score (600/720)';
  }

  Map<String, double> _getSubjectBalance() {
    final balance = <String, double>{};
    for (final c in _components) {
      final name = c['name'] as String;
      final weight = (c['weight'] as num).toDouble();
      String subject = 'Other';
      final lower = name.toLowerCase();
      if (lower.contains('physics') || lower.contains('mechanics') || lower.contains('electro') || lower.contains('magnet') || lower.contains('optics') || lower.contains('modern phys')) subject = 'Physics';
      else if (lower.contains('chem')) subject = 'Chemistry';
      else if (lower.contains('bio') || lower.contains('zoology') || lower.contains('botany')) subject = 'Biology';
      balance[subject] = (balance[subject] ?? 0) + weight;
    }
    return balance;
  }

  String _getDaysUntil(int? millis) {
    if (millis == null) return 'No date';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff < 0) return '${-diff}d ago';
    if (diff == 0) return 'Today!';
    if (diff == 1) return 'Tomorrow';
    return '$diff days';
  }

  Color _urgencyColor(int? millis) {
    if (millis == null) return Colors.grey;
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff < 0) return Colors.grey;
    if (diff <= 3) return Colors.red;
    if (diff <= 7) return Colors.orange;
    return Colors.green;
  }

  String? _getPrediction() {
    final targetText = _targetGradeController.text.trim();
    if (targetText.isEmpty) return null;
    final target = double.tryParse(targetText);
    if (target == null) return null;
    final remaining = _remainingWeight;
    if (remaining <= 0) return null;
    final current = _currentGrade;
    final totalWeight = _totalWeightUsed;
    final needed = ((target * 100) - (current * totalWeight)) / remaining;
    if (needed > 100) return 'Impossible — max is 100%';
    if (needed < 0) return 'Already achieved!';
    return 'Need ${needed.toStringAsFixed(1)}% on remaining $remaining%';
  }

  Map<String, dynamic> _predictNeetRank() {
    final neetScore = (_currentGrade / 100) * 720;
    return NeetData.predictRank(neetScore);
  }

  void _setWhatIf(int id, double value) {
    setState(() => _whatIfScores[id] = value);
    _saveWhatIfValues();
  }

  void _resetWhatIf() {
    setState(() => _whatIfScores.clear());
    _saveWhatIfValues();
  }

  Future<void> _loadMockTests() async {
    final tests = await MockTestStorage.getAll();
    if (mounted) {
      setState(() {
        _mockTests = tests;
        _loadingMocks = false;
      });
    }
  }

  int get _simulatedPhysics => int.tryParse(_physicsMarksController.text) ?? 0;
  int get _simulatedChemistry => int.tryParse(_chemistryMarksController.text) ?? 0;
  int get _simulatedBiology => int.tryParse(_biologyMarksController.text) ?? 0;
  int get _simulatedTotal => _simulatedPhysics + _simulatedChemistry + _simulatedBiology;

  Future<void> _addMockTest() async {
    final physics = _simulatedPhysics.clamp(0, 180);
    final chemistry = _simulatedChemistry.clamp(0, 180);
    final biology = _simulatedBiology.clamp(0, 360);
    final total = physics + chemistry + biology;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid marks first')));
      return;
    }
    final correct = int.tryParse(_correctController.text) ?? 0;
    final wrong = int.tryParse(_wrongController.text) ?? 0;
    final left = int.tryParse(_leftController.text) ?? 0;
    final percentile = NeetData.getPercentile(total);
    final air = NeetData.getAir(percentile);
    final test = MockTestResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      physicsScore: physics, chemistryScore: chemistry, biologyScore: biology,
      totalScore: total, percentile: percentile, air: air,
      testName: 'Mock Test #${_mockTests.length + 1}',
      correctCount: correct, wrongCount: wrong, leftCount: left,
    );
    await MockTestStorage.save(test);
    await _loadMockTests();
    HapticFeedback.mediumImpact();
    if (total >= 600) _showScoreCelebration(total, percentile, air);
    _physicsMarksController.clear();
    _chemistryMarksController.clear();
    _biologyMarksController.clear();
    _correctController.clear();
    _wrongController.clear();
    _leftController.clear();
  }

  void _showScoreCelebration(int marks, double percentile, int air) {
        final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: NeetData.getMarksColor(marks).withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.emoji_events, size: 40, color: NeetData.getMarksColor(marks)),
            ),
            const SizedBox(height: 16),
            Text('Great Score!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('$marks', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: NeetData.getMarksColor(marks))),
            const SizedBox(height: 4),
            Text('${percentile.toStringAsFixed(2)} percentile', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
            Text('Estimated AIR: $air', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
              child: Text(NeetData.getCollegePrediction(marks),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Awesome!')),
        ],
      ),
    );
  }

  Future<void> _deleteMockTest(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Mock Test?'),
        content: const Text('This test result will be removed from history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await MockTestStorage.delete(id);
      await _loadMockTests();
    }
  }

  Map<String, dynamic> _calculateQuickScore() {
    final correct = int.tryParse(_correctController.text) ?? 0;
    final wrong = int.tryParse(_wrongController.text) ?? 0;
    final left = int.tryParse(_leftController.text) ?? 0;
    final total = correct + wrong + left;
    if (total == 0) return {'score': 0, 'percentile': 0.0, 'air': 0, 'rankRange': '—', 'tier': '—'};
    final score = (correct * 4) - wrong;
    final percentile = NeetData.getPercentile(score);
    final air = NeetData.getAir(percentile);
    final rank = NeetData.predictRank(score.toDouble());
    return {
      'score': score,
      'percentile': percentile,
      'air': air,
      'rankRange': rank['rank'],
      'tier': rank['tier'],
    };
  }

  List<Map<String, dynamic>> _getWeakTopics() {
    final weak = <Map<String, dynamic>>[];
    for (final c in _components) {
      final score = (c['score'] as num).toDouble();
      final total = (c['totalPoints'] as num).toDouble();
      final percent = total > 0 ? (score / total) * 100 : 0.0;
      if (percent < 60) {
        weak.add({
          'name': c['name'],
          'percent': percent,
          'weight': c['weight'],
          'subject': _detectSubject(c['name'] as String),
        });
      }
    }
    weak.sort((a, b) => (a['percent'] as double).compareTo(b['percent'] as double));
    return weak;
  }

  String _detectSubject(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('physics') || lower.contains('mechanics') || lower.contains('electro') || lower.contains('magnet') || lower.contains('optics') || lower.contains('modern phys')) return 'Physics';
    if (lower.contains('chem')) return 'Chemistry';
    if (lower.contains('bio') || lower.contains('zoology') || lower.contains('botany') || lower.contains('physiology') || lower.contains('ecology') || lower.contains('genetics') || lower.contains('cell')) return 'Biology';
    return 'Other';
  }

  List<Map<String, dynamic>> _getChapterMastery() {
    return _components.map((c) {
      final score = (c['score'] as num).toDouble();
      final total = (c['totalPoints'] as num).toDouble();
      final percent = total > 0 ? (score / total) * 100 : 0.0;
      final revisionRound = (c['revisionRound'] as int?) ?? 0;
      final pyqDone = (c['pyqDone'] as bool?) ?? false;

      Color masteryColor;
      String masteryLabel;
      if (percent >= 80 && revisionRound >= 2 && pyqDone) {
        masteryColor = const Color(0xFF4CAF50);
        masteryLabel = 'Mastered';
      } else if (percent >= 60 && revisionRound >= 1) {
        masteryColor = const Color(0xFFFFC107);
        masteryLabel = 'Proficient';
      } else if (percent > 0) {
        masteryColor = const Color(0xFFFF9800);
        masteryLabel = 'Learning';
      } else {
        masteryColor = const Color(0xFFF44336);
        masteryLabel = 'Not Started';
      }

      return {
        'name': c['name'],
        'percent': percent,
        'color': masteryColor,
        'label': masteryLabel,
        'revisionRound': revisionRound,
        'pyqDone': pyqDone,
        'subject': _detectSubject(c['name'] as String),
      };
    }).toList();
  }

  Map<String, dynamic> _getRevisionStats() {
    if (_components.isEmpty) return {'first': 0.0, 'second': 0.0, 'third': 0.0, 'pyq': 0.0, 'firstCount': 0, 'secondCount': 0, 'thirdCount': 0, 'pyqCount': 0, 'total': 0};
    int first = 0, second = 0, third = 0, pyq = 0;
    for (final c in _components) {
      final round = (c['revisionRound'] as int?) ?? 0;
      final done = (c['pyqDone'] as bool?) ?? false;
      if (round >= 1) first++;
      if (round >= 2) second++;
      if (round >= 3) third++;
      if (done) pyq++;
    }
    final total = _components.length;
    return {
      'first': (first / total * 100),
      'second': (second / total * 100),
      'third': (third / total * 100),
      'pyq': (pyq / total * 100),
      'firstCount': first,
      'secondCount': second,
      'thirdCount': third,
      'pyqCount': pyq,
      'total': total,
    };
  }

  Map<String, double> _getSubjectTimeDistribution() {
    final dist = <String, double>{'Physics': 0, 'Chemistry': 0, 'Biology': 0, 'Other': 0};
    for (final c in _components) {
      final hours = (c['hoursStudied'] as num?)?.toDouble() ?? 0;
      final subject = _detectSubject(c['name'] as String);
      dist[subject] = (dist[subject] ?? 0) + hours;
    }
    return dist;
  }

  String _getTodayQuote() {
    final day = DateTime.now().day;
    return NeetData.motivationQuotes[day % NeetData.motivationQuotes.length];
  }

  String _getNeetCountdown() {
    if (_neetExamDate == null) return 'Set exam date';
    final now = DateTime.now();
    final diff = _neetExamDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff < 0) return 'Exam passed';
    if (diff == 0) return 'Today!';
    return '$diff';
  }

  String _generateStudyPlan() {
    final buffer = StringBuffer();
    buffer.writeln('📊 NEET STUDY PLAN — ${_childName.isNotEmpty ? _childName : "Student"}');
    buffer.writeln('Generated: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('Target College: $_targetCollege | Target Score: $_targetScore/720');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('');
    buffer.writeln('Current Grade: ${_currentGrade.toStringAsFixed(1)}% ($_letterGrade)');
    buffer.writeln('Study Streak: $_studyStreak days 🔥');
    buffer.writeln('');
    final rank = _predictNeetRank();
    buffer.writeln('🎯 NEET Prediction:');
    buffer.writeln('   Estimated Score: ${((_currentGrade / 100) * 720).toStringAsFixed(0)}/720');
    buffer.writeln('   Predicted Rank: ${rank['rank']}');
    buffer.writeln('   College Tier: ${rank['tier']}');
    buffer.writeln('');
    final smart = _getSmartTarget();
    if (smart != null) {
      buffer.writeln('💡 Smart Target:');
      buffer.writeln('   $smart');
      buffer.writeln('');
    }
    final weak = _getWeakTopics();
    if (weak.isNotEmpty) {
      buffer.writeln('⚠️ PRIORITY WEAK TOPICS (Focus Here First):');
      for (final w in weak.take(5)) {
        buffer.writeln('   • ${w['name']} — ${(w['percent'] as double).toStringAsFixed(1)}% (${w['subject']})');
      }
      buffer.writeln('');
    }
    final mastery = _getChapterMastery();
    final notStarted = mastery.where((m) => m['label'] == 'Not Started').length;
    final mastered = mastery.where((m) => m['label'] == 'Mastered').length;
    buffer.writeln('📚 Chapter Status:');
    buffer.writeln('   Mastered: $mastered | Learning: ${mastery.where((m) => m['label'] == 'Learning').length} | Not Started: $notStarted');
    buffer.writeln('');
    buffer.writeln('📚 Component Breakdown:');
    for (final c in _components) {
      final name = c['name'] as String;
      final score = (c['score'] as num).toDouble();
      final total = (c['totalPoints'] as num).toDouble();
      final weight = (c['weight'] as num).toDouble();
      final percent = total > 0 ? (score / total) * 100 : 0;
      final diff = c['difficulty'] as String? ?? 'Medium';
      final hours = (c['hoursStudied'] as num?)?.toDouble() ?? 0;
      final eff = _getEfficiencyScore(c);
      final revRound = (c['revisionRound'] as int?) ?? 0;
      final pyq = (c['pyqDone'] as bool?) ?? false;
      buffer.writeln('');
      buffer.writeln('   ▶ $name');
      buffer.writeln('      Score: ${score.toStringAsFixed(1)}/${total.toStringAsFixed(0)} (${percent.toStringAsFixed(1)}%)');
      buffer.writeln('      Weight: ${weight.toStringAsFixed(1)}% | Difficulty: $diff');
      buffer.writeln('      Hours: ${hours.toStringAsFixed(1)}h | Efficiency: ${eff.toStringAsFixed(2)} pts/hr');
      buffer.writeln('      Revision: Round $revRound | PYQ: ${pyq ? 'Done' : 'Pending'}');
      if (percent < 60) buffer.writeln('      ⚠️ WEAK — needs focus!');
      else if (percent >= 85) buffer.writeln('      ✅ STRONG — maintain!');
    }
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Generated by StudyFlow NEET Calculator');
    return buffer.toString();
  }

  String _generateParentReport() {
    final buffer = StringBuffer();
    buffer.writeln('📋 PARENT PROGRESS REPORT');
    buffer.writeln('Child: ${_childName.isNotEmpty ? _childName : "Student"}');
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('');
    buffer.writeln('🔥 Study Streak: $_studyStreak days');
    buffer.writeln('🎯 Target: $_targetScore/720 ($_targetCollege)');
    buffer.writeln('📊 Current: ${((_currentGrade / 100) * 720).toStringAsFixed(0)}/720 (${_currentGrade.toStringAsFixed(1)}%)');
    buffer.writeln('');
    final weeklyStats = _getWeeklyStudyStats();
    buffer.writeln("📅 This Week's Study:");
    buffer.writeln('   Hours: ${weeklyStats['totalHours'].toStringAsFixed(1)}h');
    buffer.writeln('   MCQs Solved: ${weeklyStats['totalMcqs']}');
    buffer.writeln('   Accuracy: ${weeklyStats['accuracy'].toStringAsFixed(1)}%');
    buffer.writeln('   Days Active: ${weeklyStats['daysActive']}');
    buffer.writeln('');
    final subjHours = weeklyStats['subjectHours'] as Map<String, dynamic>? ?? {};
    if (subjHours.isNotEmpty) {
      buffer.writeln('⏰ Subject-wise Hours:');
      subjHours.forEach((subj, hours) {
        buffer.writeln('   $subj: ${hours.toStringAsFixed(1)}h');
      });
      buffer.writeln('');
    }
    if (_mockTests.length >= 2) {
      final latest = _mockTests.first.totalScore;
      final previous = _mockTests[1].totalScore;
      final trend = latest - previous;
      buffer.writeln('📈 Mock Test Trend:');
      buffer.writeln('   Latest: $latest | Previous: $previous | Change: ${trend >= 0 ? '+' : ''}$trend');
      buffer.writeln('');
    }
    final weak = _getWeakTopics();
    if (weak.isNotEmpty) {
      buffer.writeln('⚠️ AREAS NEEDING ATTENTION:');
      for (final w in weak.take(5)) {
        buffer.writeln('   • ${w['name']} — ${(w['percent'] as double).toStringAsFixed(1)}%');
      }
      buffer.writeln('');
    }
    if (_parentNotes.isNotEmpty) {
      buffer.writeln('📝 Parent Notes:');
      buffer.writeln('   $_parentNotes');
      buffer.writeln('');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buffer.toString();
  }

  Map<String, dynamic> _getWeeklyStudyStats() {
    double totalHours = 0;
    int totalMcqs = 0;
    int totalCorrect = 0;
    final subjectHours = <String, double>{};
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekLogs = _studyLogs.where((l) {
      final lDate = DateTime(l.date.year, l.date.month, l.date.day);
      final ws = DateTime(weekStart.year, weekStart.month, weekStart.day);
      return lDate.isAfter(ws.subtract(const Duration(days: 1))) && lDate.isBefore(ws.add(const Duration(days: 7)));
    }).toList();
    for (final log in weekLogs) {
      totalHours += log.hours;
      totalMcqs += log.mcqsSolved;
      totalCorrect += log.mcqsCorrect;
      subjectHours[log.subject] = (subjectHours[log.subject] ?? 0) + log.hours;
    }
    return {
      'totalHours': totalHours,
      'totalMcqs': totalMcqs,
      'totalCorrect': totalCorrect,
      'accuracy': totalMcqs > 0 ? (totalCorrect / totalMcqs) * 100 : 0.0,
      'subjectHours': subjectHours,
      'daysActive': weekLogs.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet().length,
    };
  }

  Future<void> _addStudyLog() async {
    final subject = _selectedLogSubject;
    final topic = _logTopicController.text.trim();
    final hours = double.tryParse(_logHoursController.text) ?? 0;
    final mcqs = int.tryParse(_logMcqsController.text) ?? 0;
    final correct = int.tryParse(_logCorrectController.text) ?? 0;
    if (subject.isEmpty || topic.isEmpty || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill subject, topic and hours')));
      return;
    }
    final log = DailyStudyLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      subject: subject,
      topic: topic,
      hours: hours,
      mcqsSolved: mcqs,
      mcqsCorrect: correct,
      notes: _logNotesController.text.trim(),
    );
    await StudyLogStorage.save(log);
    await _updateStudyStreak();
    await _loadStudyLogs();
    HapticFeedback.lightImpact();
    _logTopicController.clear();
    _logHoursController.clear();
    _logMcqsController.clear();
    _logCorrectController.clear();
    _logNotesController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study log saved!'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteStudyLog(String logId) async {
    await StudyLogStorage.delete(logId);
    await _loadStudyLogs();
  }

  Future<void> _addBookmark() async {
    final question = _bookmarkQuestionController.text.trim();
    if (question.isEmpty) return;
    final bm = BookmarkedQuestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      question: question,
      subject: _selectedBookmarkSubject,
      chapter: _selectedChapterTag.isEmpty ? 'General' : _selectedChapterTag,
      answer: _bookmarkAnswerController.text.trim().isEmpty ? null : _bookmarkAnswerController.text.trim(),
      bookmarkedDate: DateTime.now(),
      isWeak: true,
    );
    await BookmarkStorage.save(bm);
    await _loadBookmarks();
    _bookmarkQuestionController.clear();
    _bookmarkAnswerController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question bookmarked!'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteBookmark(String id) async {
    await BookmarkStorage.delete(id);
    await _loadBookmarks();
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD METHOD
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0, scrolledUnderElevation: 1, backgroundColor: cs.surface,
        title: Text(
          _childName.isNotEmpty ? 'NEET Tracker — $_childName' : 'NEET Grade Calculator',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export Study Plan',
            onPressed: () {
              final plan = _generateStudyPlan();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Study Plan'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: SelectableText(plan, style: const TextStyle(fontSize: 12, height: 1.5)),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
          if (_components.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Clear all?'),
                    content: const Text('Delete all grade components?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (confirm == true) await _clearAllComponents();
              },
              child: Text('Clear', style: TextStyle(color: cs.primary)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          dividerColor: cs.outlineVariant.withOpacity(0.3),
          tabs: const [
            Tab(icon: Icon(Icons.calculate), text: 'Components'),
            Tab(icon: Icon(Icons.psychology), text: 'Simulator'),
            Tab(icon: Icon(Icons.history), text: 'Mock Tests'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.bolt), text: 'Tools'),
            Tab(icon: Icon(Icons.family_restroom), text: 'Parent'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildComponentsTab(cs),
                _buildNeetSimulatorTab(cs),
                _buildMockTestsTab(cs),
                _buildAnalyticsTab(cs),
                _buildToolsTab(cs),
                _buildParentTab(cs),
              ],
            ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 1: COMPONENTS (REDESIGNED WITH MODERN UI)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildComponentsTab(ColorScheme cs) {
    final grade = _currentGrade;
    final gradeColor = _gradeColor(grade);
    final totalWeight = _totalWeightUsed;
    final isOverWeight = totalWeight > 100;
    final rankPrediction = _predictNeetRank();
    final subjectBalance = _getSubjectBalance();
    final smartTarget = _getSmartTarget();
    final weakTopics = _getWeakTopics();
    final chapterMastery = _getChapterMastery();
    final revisionStats = _getRevisionStats();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 16),
              if (_neetExamDate != null) _buildCountdownBanner(cs),
              const SizedBox(height: 12),
              _buildGradeRing(cs, grade, gradeColor),
              const SizedBox(height: 16),
              if (_components.isNotEmpty) _buildChapterMasteryOverview(cs, chapterMastery),
              if (_components.isNotEmpty) _buildRevisionTracker(cs, revisionStats),
              if (weakTopics.isNotEmpty) _buildWeakTopicsAlert(cs, weakTopics),
              if (_components.isNotEmpty) _buildRankPredictor(cs, rankPrediction, grade),
              if (smartTarget != null) _buildSmartTarget(cs, smartTarget),
              if (subjectBalance.isNotEmpty) _buildSubjectBalance(cs, subjectBalance),
              _buildWeightBudget(cs, totalWeight, isOverWeight),
              const SizedBox(height: 20),
              _buildPresetButtons(cs),
              const SizedBox(height: 20),
              if (_components.isNotEmpty) _buildWhatIfToggle(cs),
              _buildTargetPredictor(cs),
              const SizedBox(height: 20),
              _buildAddComponentSection(cs),
              const SizedBox(height: 20),
              if (_components.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text('Components', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
                      const Spacer(),
                      Text('${_components.length} items', style: TextStyle(fontSize: 12, color: cs.outline)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (_components.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(cs))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildComponentCard(_components[index], cs, index),
                childCount: _components.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildCountdownBanner(ColorScheme cs) {
    final daysStr = _getNeetCountdown();
    final days = int.tryParse(daysStr) ?? 0;
    final urgencyColor = days <= 30 ? Colors.red : days <= 90 ? Colors.orange : cs.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [urgencyColor.withOpacity(0.15), cs.surfaceContainerHighest.withOpacity(0.3)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgencyColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⏰ NEET Countdown', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  daysStr == 'Today!' ? 'Exam is TODAY!' : '$daysStr days left',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: urgencyColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Daily Motivation', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  _getTodayQuote(),
                  style: TextStyle(fontSize: 11, color: cs.onSurface, fontStyle: FontStyle.italic, height: 1.4),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeRing(ColorScheme cs, double grade, Color gradeColor) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gradeColor.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220, height: 220,
              child: CircularProgressIndicator(
                value: 1.0, strokeWidth: 18,
                backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                valueColor: const AlwaysStoppedAnimation(Colors.transparent),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: (grade / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => SizedBox(
                width: 220, height: 220,
                child: CircularProgressIndicator(
                  value: value, strokeWidth: 18,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(gradeColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${grade.toStringAsFixed(1)}%', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: gradeColor)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gradeColor.withOpacity(0.2)),
                  ),
                  child: Text(_letterGrade, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: gradeColor)),
                ),
                const SizedBox(height: 10),
                Text(
                  '${((grade / 100) * 720).toStringAsFixed(0)}/720 est.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterMasteryOverview(ColorScheme cs, List<Map<String, dynamic>> mastery) {
    final mastered = mastery.where((m) => m['label'] == 'Mastered').length;
    final proficient = mastery.where((m) => m['label'] == 'Proficient').length;
    final learning = mastery.where((m) => m['label'] == 'Learning').length;
    final notStarted = mastery.where((m) => m['label'] == 'Not Started').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text('Chapter Mastery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const Spacer(),
              Text('$mastered/${mastery.length} mastered', style: TextStyle(fontSize: 11, color: cs.outline)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: mastery.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (m['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (m['color'] as Color).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: m['color'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${m['name']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                    const SizedBox(width: 4),
                    Text('${(m['percent'] as double).toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, color: cs.outline)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMasteryLegend('Mastered', const Color(0xFF4CAF50), cs),
              const SizedBox(width: 12),
              _buildMasteryLegend('Proficient', const Color(0xFFFFC107), cs),
              const SizedBox(width: 12),
              _buildMasteryLegend('Learning', const Color(0xFFFF9800), cs),
              const SizedBox(width: 12),
              _buildMasteryLegend('Not Started', const Color(0xFFF44336), cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryLegend(String label, Color color, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: cs.outline)),
      ],
    );
  }

  Widget _buildRevisionTracker(ColorScheme cs, Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text('Revision & PYQ Tracker', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildRevisionStat('1st Rev', stats['first'] as double, cs.primary, cs)),
              const SizedBox(width: 8),
              Expanded(child: _buildRevisionStat('2nd Rev', stats['second'] as double, cs.secondary, cs)),
              const SizedBox(width: 8),
              Expanded(child: _buildRevisionStat('3rd Rev', stats['third'] as double, const Color(0xFF9C27B0), cs)),
              const SizedBox(width: 8),
              Expanded(child: _buildRevisionStat('PYQs', stats['pyq'] as double, const Color(0xFF00BCD4), cs)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionStat(String label, double pct, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0), strokeWidth: 4,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              )),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildWeakTopicsAlert(ColorScheme cs, List<Map<String, dynamic>> weakTopics) {
    final topWeak = weakTopics.take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Text('Priority Revision List', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.error)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: cs.error.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text('${weakTopics.length} weak', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.error)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...topWeak.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${w['name']} — ${(w['percent'] as double).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: cs.onSurface, fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _subjectColor(w['subject'] as String).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(w['subject'] as String, style: TextStyle(fontSize: 9, color: _subjectColor(w['subject'] as String), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )),
          if (weakTopics.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+${weakTopics.length - 3} more weak topics', style: TextStyle(fontSize: 10, color: cs.outline)),
            ),
        ],
      ),
    );
  }

  Color _subjectColor(String subject) {
    switch (subject) {
      case 'Physics': return const Color(0xFF1565C0);
      case 'Chemistry': return const Color(0xFF2E7D32);
      case 'Biology': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  Widget _buildRankPredictor(ColorScheme cs, Map<String, dynamic> rank, double grade) {
    final neetScore = (grade / 100) * 720;
    final tierColor = neetScore >= 650 ? Colors.green : neetScore >= 550 ? Colors.orange : Colors.red;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withOpacity(0.12), cs.surfaceContainerHighest.withOpacity(0.3)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, size: 18, color: tierColor),
              const SizedBox(width: 8),
              Text('NEET Rank Predictor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: tierColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text('${neetScore.toStringAsFixed(0)}/720', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tierColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Predicted Rank', style: TextStyle(fontSize: 11, color: cs.outline)),
                    const SizedBox(height: 2),
                    Text(rank['rank'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('College Tier', style: TextStyle(fontSize: 11, color: cs.outline)),
                    const SizedBox(height: 2),
                    Text(rank['tier'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tierColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (neetScore / 720).clamp(0.0, 1.0), minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(tierColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartTarget(ColorScheme cs, String target) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(target, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBalance(ColorScheme cs, Map<String, double> balance) {
    final total = balance.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final colors = {'Physics': const Color(0xFF1565C0), 'Chemistry': const Color(0xFF2E7D32), 'Biology': const Color(0xFFC62828), 'Other': Colors.grey};
    final bioPct = ((balance['Biology'] ?? 0) / total * 100).round();
    final phyPct = ((balance['Physics'] ?? 0) / total * 100).round();
    final chemPct = ((balance['Chemistry'] ?? 0) / total * 100).round();
    String warning = '';
    if (bioPct < 40) warning = 'Biology is under-weighted! NEET needs ~50% focus on Bio.';
    else if (phyPct > 40) warning = 'Too much weight on Physics. Balance with Biology.';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('Subject Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: balance.entries.map((e) {
                  final pct = (e.value / total).clamp(0.0, 1.0);
                  final color = colors[e.key] ?? Colors.grey;
                  return Expanded(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(
                      color: color.withOpacity(0.8),
                      child: pct > 0.12
                          ? Center(child: Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: balance.entries.map((e) {
              final color = colors[e.key] ?? Colors.grey;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.key}: ${e.value.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              );
            }).toList(),
          ),
          if (warning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(warning, style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightBudget(ColorScheme cs, double totalWeight, bool isOverWeight) {
    final remaining = _remainingWeight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Weight Budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                Text('${totalWeight.toStringAsFixed(1)}% / 100%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isOverWeight ? cs.error : cs.primary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (totalWeight / 100).clamp(0.0, 1.0), minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(isOverWeight ? cs.error : cs.primary),
              ),
            ),
            if (isOverWeight)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(Icons.warning_amber, size: 14, color: cs.error),
                  const SizedBox(width: 4),
                  Text('Total weight exceeds 100%', style: TextStyle(fontSize: 12, color: cs.error, fontWeight: FontWeight.w500)),
                ]),
              )
            else if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${remaining.toStringAsFixed(1)}% remaining', style: TextStyle(fontSize: 12, color: cs.outline)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEET Presets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _PresetChip(label: 'Physics', icon: Icons.science, color: const Color(0xFF1565C0), onTap: () => _loadPreset('Physics')),
              _PresetChip(label: 'Chemistry', icon: Icons.biotech, color: const Color(0xFF2E7D32), onTap: () => _loadPreset('Chemistry')),
              _PresetChip(label: 'Biology', icon: Icons.eco, color: const Color(0xFFC62828), onTap: () => _loadPreset('Biology')),
              _PresetChip(label: 'Full NEET', icon: Icons.local_hospital, color: cs.primary, onTap: _loadFullNeetPreset),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIfToggle(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => setState(() => _showWhatIf = !_showWhatIf),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _showWhatIf ? cs.primaryContainer.withOpacity(0.3) : cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _showWhatIf ? cs.primary.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(_showWhatIf ? Icons.toggle_on : Icons.toggle_off, color: _showWhatIf ? cs.primary : cs.outline),
              const SizedBox(width: 8),
              Text('What-If Simulator', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _showWhatIf ? cs.primary : cs.onSurface)),
              const Spacer(),
              if (_whatIfScores.isNotEmpty)
                TextButton(onPressed: _resetWhatIf, child: Text('Reset', style: TextStyle(fontSize: 11, color: cs.error))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetPredictor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grade Predictor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetGradeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target %', hintText: 'e.g. 85',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    _getPrediction() ?? 'Enter target',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _getPrediction() != null ? cs.primary : cs.outline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddComponentSection(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Component', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Component name',
                hintText: 'e.g. Midterm / Mechanics',
                prefixIcon: const Icon(Icons.assignment_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedDifficulty = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedChapterTag.isEmpty ? null : _selectedChapterTag,
                    hint: const Text('Chapter', style: TextStyle(fontSize: 13)),
                    decoration: InputDecoration(
                      labelText: 'Chapter Tag',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('None', style: TextStyle(fontSize: 13))),
                      ..._chapterTags.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (v) => setState(() => _selectedChapterTag = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Weight %',
                      prefixIcon: const Icon(Icons.balance),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _scoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Your score',
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _totalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Out of',
                      prefixIcon: const Icon(Icons.format_list_numbered),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Hours studied (optional)',
                hintText: 'For efficiency tracking',
                prefixIcon: const Icon(Icons.timer_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addComponent,
                icon: const Icon(Icons.add),
                label: const Text('Add Component'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentCard(Map<String, dynamic> c, ColorScheme cs, int index) {
    final name = c['name'] as String? ?? 'Component';
    final weight = (c['weight'] as num?)?.toDouble() ?? 0;
    final score = (c['score'] as num?)?.toDouble() ?? 0;
    final total = (c['totalPoints'] as num?)?.toDouble() ?? 100;
    final percent = total > 0 ? ((score / total) * 100).toDouble() : 0.0;
    final id = c['id'] as int;
    final difficulty = c['difficulty'] as String? ?? 'Medium';
    final hours = (c['hoursStudied'] as num?)?.toDouble() ?? 0;
    final chapterTag = c['chapterTag'] as String? ?? '';
    final examDateMillis = c['examDateMillis'] as int?;
    final efficiency = _getEfficiencyScore(c);
    final whatIfVal = _whatIfScores[id];
    final displayPercent = whatIfVal ?? percent;
    final displayColor = _gradeColor(displayPercent);
    final revisionRound = (c['revisionRound'] as int?) ?? 0;
    final pyqDone = (c['pyqDone'] as bool?) ?? false;

    return Dismissible(
      key: ValueKey('grade_comp_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      onDismissed: (_) => _removeComponent(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: displayColor.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(
                    child: Text('${displayPercent.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: displayColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (chapterTag.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(chapterTag, style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w500)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: difficulty == 'Hard' ? Colors.red.withOpacity(0.1) : difficulty == 'Easy' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(difficulty, style: TextStyle(fontSize: 10, color: difficulty == 'Hard' ? Colors.red : difficulty == 'Easy' ? Colors.green : Colors.orange, fontWeight: FontWeight.w500)),
                          ),
                          if (hours > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                              child: Text('${hours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                            ),
                          if (revisionRound > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF9C27B0).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text('Rev $revisionRound', style: TextStyle(fontSize: 9, color: const Color(0xFF9C27B0), fontWeight: FontWeight.w600)),
                            ),
                          if (pyqDone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF00BCD4).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text('PYQ ✓', style: TextStyle(fontSize: 9, color: const Color(0xFF00BCD4), fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (examDateMillis != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _urgencyColor(examDateMillis).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(_getDaysUntil(examDateMillis), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _urgencyColor(examDateMillis))),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${score.toStringAsFixed(1)}/$total', style: TextStyle(fontSize: 12, color: cs.outline)),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(fontSize: 12, color: cs.outline)),
                const SizedBox(width: 8),
                Text('Weight: ${weight.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: cs.outline)),
                if (hours > 0 && efficiency > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: efficiency >= 5 ? Colors.green.withOpacity(0.1) : efficiency >= 3 ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Eff: ${efficiency.toStringAsFixed(1)} pts/hr', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: efficiency >= 5 ? Colors.green : efficiency >= 3 ? Colors.orange : Colors.red)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (displayPercent / 100).clamp(0.0, 1.0), minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(displayColor),
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final current = await _getRevisionRound(id);
                    await _setRevisionRound(id, (current + 1) % 4);
                    await _loadComponents();
                  },
                  icon: const Icon(Icons.sync, size: 14),
                  label: Text('Rev: $revisionRound', style: const TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _setPyqDone(id, !pyqDone);
                    await _loadComponents();
                  },
                  icon: Icon(pyqDone ? Icons.check_circle : Icons.circle_outlined, size: 14, color: pyqDone ? const Color(0xFF00BCD4) : null),
                  label: Text(pyqDone ? 'PYQ Done' : 'Mark PYQ', style: const TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                ),
              ],
            ),
            if (_showWhatIf) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('What-if:', style: TextStyle(fontSize: 11, color: cs.outline)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: (_whatIfScores[id] ?? percent).clamp(0.0, 100.0),
                      min: 0, max: 100, divisions: 20,
                      label: '${(_whatIfScores[id] ?? percent).toStringAsFixed(0)}%',
                      onChanged: (v) => _setWhatIf(id, v),
                    ),
                  ),
                  Text('${(_whatIfScores[id] ?? percent).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.calculate_outlined, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('No components yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Add grade components or load a NEET preset above', style: TextStyle(fontSize: 13, color: cs.outline)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: [
                _PresetChip(label: 'Load Physics', icon: Icons.science, color: const Color(0xFF1565C0), onTap: () => _loadPreset('Physics')),
                _PresetChip(label: 'Load Chemistry', icon: Icons.biotech, color: const Color(0xFF2E7D32), onTap: () => _loadPreset('Chemistry')),
                _PresetChip(label: 'Load Biology', icon: Icons.eco, color: const Color(0xFFC62828), onTap: () => _loadPreset('Biology')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 2: NEET SIMULATOR
  // ═════════════════════════════════════════════════════════════════

  Widget _buildNeetSimulatorTab(ColorScheme cs) {
    final total = _simulatedTotal;
    final percentile = NeetData.getPercentile(total);
    final air = NeetData.getAir(percentile);
    final marksColor = NeetData.getMarksColor(total);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [marksColor.withOpacity(0.15), cs.surfaceContainerHighest.withOpacity(0.3)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: marksColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text('NEET Score Simulator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$total', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: marksColor, height: 1)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text('/ 720', style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: marksColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(NeetData.getCollegePrediction(total),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: marksColor)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildStatBox('Percentile', '${percentile.toStringAsFixed(2)}%', cs.primary, cs)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBox('Est. AIR', air.toString(), cs.secondary, cs)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Enter Your Marks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 12),
          _buildSubjectInput('Physics', '0-180', const Color(0xFF1565C0), _physicsMarksController, cs),
          const SizedBox(height: 10),
          _buildSubjectInput('Chemistry', '0-180', const Color(0xFF2E7D32), _chemistryMarksController, cs),
          const SizedBox(height: 10),
          _buildSubjectInput('Biology', '0-360', const Color(0xFFC62828), _biologyMarksController, cs),
          const SizedBox(height: 20),
          Text('Quick Score Calculator (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('Enter correct, wrong & left questions to auto-calculate marks', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
                      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(Icons.bookmark, size: 18, color: const Color(0xFFE91E63)),
                const SizedBox(width: 8),
                Text('Bookmark Weak Questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              ]),
              if (_bookmarks.isNotEmpty)
                TextButton(onPressed: () => _showAllBookmarks(cs), child: Text('${_bookmarks.length}', style: const TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 4),
            Text('Save difficult questions for revision later', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedBookmarkSubject,
              decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _selectedBookmarkSubject = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bookmarkQuestionController,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'Question / Concept', hintText: 'e.g. Why does sky appear blue?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bookmarkAnswerController,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'Answer / Explanation (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _addBookmark,
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Bookmark Question'),
            )),
            if (_bookmarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Recent Bookmarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              ..._bookmarks.take(3).map((bm) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _subjectColor(bm.subject), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(bm.question, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(bm.subject, style: TextStyle(fontSize: 10, color: cs.outline)),
                    ])),
                    if (bm.answer != null && bm.answer!.isNotEmpty)
                      Icon(Icons.check_circle, size: 14, color: Colors.green),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllBookmarks(ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('Bookmarked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final bm = _bookmarks[index];
                    return Dismissible(
                      key: ValueKey('bm_${bm.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: cs.error)),
                      onDismissed: (_) => _deleteBookmark(bm.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withOpacity(0.2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _subjectColor(bm.subject), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(bm.subject, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                            const Spacer(),
                            Text('${bm.bookmarkedDate.day}/${bm.bookmarkedDate.month}', style: TextStyle(fontSize: 10, color: cs.outline)),
                          ]),
                          const SizedBox(height: 6),
                          Text(bm.question, style: TextStyle(fontSize: 13, color: cs.onSurface)),
                          if (bm.answer != null && bm.answer!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                              child: Text('Ans: ${bm.answer}', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 6: PARENT DASHBOARD
  // ═════════════════════════════════════════════════════════════════

  Widget _buildParentTab(ColorScheme cs) {
    final weeklyStats = _getWeeklyStudyStats();
    final weakTopics = _getWeakTopics();
    final neetScore = (_currentGrade / 100) * 720;
    final scoreGap = _targetScore - neetScore;
    final isOnTrack = scoreGap <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.15), cs.surfaceContainerHighest.withOpacity(0.3)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(Icons.child_care, size: 28, color: cs.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _childName.isNotEmpty ? _childName : 'Student Profile',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text('Target: $_targetCollege ($_targetScore/720)', style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildParentStatCard(
                        'Current Score',
                        '${neetScore.toStringAsFixed(0)}/720',
                        isOnTrack ? Colors.green : cs.error,
                        cs,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParentStatCard(
                        'Gap to Target',
                        isOnTrack ? 'On Track!' : '+${scoreGap.toStringAsFixed(0)} needed',
                        isOnTrack ? Colors.green : Colors.orange,
                        cs,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParentStatCard(
                        'Study Streak',
                        '$_studyStreak days 🔥',
                        cs.secondary,
                        cs,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_view_week, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text("This Week's Progress", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildWeeklyMiniStat('Hours', '${weeklyStats['totalHours'].toStringAsFixed(1)}h', cs.primary, cs)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildWeeklyMiniStat('MCQs', '${weeklyStats['totalMcqs']}', cs.secondary, cs)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildWeeklyMiniStat('Accuracy', '${(weeklyStats['accuracy'] as double).toStringAsFixed(0)}%', (weeklyStats['accuracy'] as double) >= 70 ? Colors.green : Colors.orange, cs)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildWeeklyMiniStat('Days', '${weeklyStats['daysActive']}', cs.tertiary, cs)),
                  ],
                ),
                const SizedBox(height: 12),
                if ((weeklyStats['subjectHours'] as Map<String, dynamic>?)?.isNotEmpty ?? false) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Subject-wise This Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  ...((weeklyStats['subjectHours'] as Map<String, dynamic>).entries).map((e) {
                    final color = _subjectColor(e.key);
                    final target = e.key == 'Biology' ? _weeklyGoalBio : e.key == 'Physics' ? _weeklyGoalPhy : _weeklyGoalChem;
                    final pct = target > 0 ? ((e.value as double) / target).clamp(0.0, 1.0) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(e.key, style: TextStyle(fontSize: 12, color: cs.onSurface)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct, minHeight: 8,
                                backgroundColor: cs.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${(e.value as double).toStringAsFixed(1)}h / $target', style: TextStyle(fontSize: 11, color: cs.outline)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (weakTopics.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notification_important, size: 20, color: cs.error),
                      const SizedBox(width: 8),
                      Text('Attention Needed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.error)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${weakTopics.length} topics are below 60% — these need immediate revision:',
                    style: TextStyle(fontSize: 12, color: cs.onSurface, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  ...weakTopics.take(5).map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right, size: 16, color: cs.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${w['name']} — ${(w['percent'] as double).toStringAsFixed(1)}% (${w['subject']})',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface),
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (weakTopics.length > 5)
                    Text('+${weakTopics.length - 5} more weak topics', style: TextStyle(fontSize: 11, color: cs.outline)),
                ],
              ),
            ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Recommended Resources', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Based on weak areas — help your child focus here', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                ..._buildResourceList(cs, weakTopics),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Parent Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _childNameController,
                  decoration: InputDecoration(
                    labelText: 'Child Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _targetCollege,
                  decoration: InputDecoration(
                    labelText: 'Target College',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: NeetData.collegeCutoffs.keys.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _targetCollege = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _targetScoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Score (out of 720)',
                    prefixIcon: const Icon(Icons.flag),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _parentNotesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Parent Notes / Observations',
                    hintText: 'e.g. Needs more focus on Organic Chemistry...',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await _saveParentData();
                      await _loadParentData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings saved!'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                final report = _generateParentReport();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Parent Report'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(child: SelectableText(report, style: const TextStyle(fontSize: 12, height: 1.5)))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.summarize),
              label: const Text('Generate Full Parent Report'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildParentStatCard(String label, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildWeeklyMiniStat(String label, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  List<Widget> _buildResourceList(ColorScheme cs, List<Map<String, dynamic>> weakTopics) {
    final widgets = <Widget>[];
    final addedChapters = <String>{};

    for (final weak in weakTopics.take(5)) {
      final name = weak['name'] as String;
      String? matchedKey;
      for (final key in NeetData.chapterResources.keys) {
        if (name.toLowerCase().contains(key.toLowerCase()) || key.toLowerCase().contains(name.toLowerCase())) {
          matchedKey = key;
          break;
        }
      }
      if (matchedKey != null && !addedChapters.contains(matchedKey)) {
        addedChapters.add(matchedKey);
        final resources = NeetData.chapterResources[matchedKey]!;
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
