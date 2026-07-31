// FILE: lib/screens/grade_calculator_screen.dart
// COMBINED EDITION — Merges ALL features from both v3 versions
// TAB 1 — Components: Grade ring, chapter presets, difficulty, hours, efficiency,
//          what-if simulator, subject balance, weight budget, exam date, export
// TAB 2 — NEET Simulator: Real-time score, percentile, AIR, college prediction,
//          cutoff comparison, save to mock tests, celebration dialog
// TAB 3 — Mock Tests: History, trend chart, CRUD, stats, empty state
// TAB 4 — Analytics: Consistency, improvement, smart recommendations,
//          target calculator, subject averages, rank predictor
// PERSISTENCE: SQLite for components, SharedPreferences for mock tests + metadata

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_countdown/database_helper.dart';
import '../services/settings_service.dart';
import 'package:event_countdown/services/widget_service.dart';

// ═══════════════════════════════════════════════════════════════════
// NEET DATA MODELS & HISTORICAL DATA
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
  );
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
      {'name': 'Mechanics',           'weight': 25, 'total': 100},
      {'name': 'Electrostatics',      'weight': 20, 'total': 100},
      {'name': 'Current Electricity', 'weight': 15, 'total': 100},
      {'name': 'Magnetism',           'weight': 15, 'total': 100},
      {'name': 'Optics',              'weight': 15, 'total': 100},
      {'name': 'Modern Physics',      'weight': 10, 'total': 100},
    ],
    'Chemistry': [
      {'name': 'Physical Chemistry',  'weight': 30, 'total': 100},
      {'name': 'Organic Chemistry',   'weight': 35, 'total': 100},
      {'name': 'Inorganic Chemistry', 'weight': 35, 'total': 100},
    ],
    'Biology': [
      {'name': 'Zoology – Animal Kingdom',   'weight': 15, 'total': 100},
      {'name': 'Zoology – Human Physiology', 'weight': 25, 'total': 100},
      {'name': 'Zoology – Reproduction',     'weight': 10, 'total': 100},
      {'name': 'Botany – Plant Kingdom',     'weight': 10, 'total': 100},
      {'name': 'Botany – Plant Physiology',  'weight': 20, 'total': 100},
      {'name': 'Botany – Ecology & Env',     'weight': 20, 'total': 100},
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
}

class MockTestStorage {
  static const String _key = 'neet_mock_tests_v1';

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
    while (all.length > 50) all.removeLast();
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

class _GradeCalcPrefs {
  static const String _prefix = 'grade_calc_';
  static String diff(int id)     => '${_prefix}diff_$id';
  static String hours(int id)    => '${_prefix}hours_$id';
  static String chapter(int id)  => '${_prefix}chapter_$id';
  static String examDate(int id) => '${_prefix}examdate_$id';
  static String get whatIf       => '${_prefix}whatif';
  static String get lastPreset   => '${_prefix}last_preset';
}

class GradeCalculatorScreen extends StatefulWidget {
  const GradeCalculatorScreen({super.key});
  @override
  State<GradeCalculatorScreen> createState() => _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends State<GradeCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

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

  String _selectedDifficulty = 'Medium';
  String _selectedChapterTag = '';
  bool _showWhatIf = false;
  Map<int, double> _whatIfScores = {};

  final List<String> _chapterTags = [
    'Mechanics','Electrostatics','Current Electricity','Magnetism',
    'Optics','Modern Physics','Physical Chem','Organic Chem',
    'Inorganic Chem','Zoology','Botany','Genetics','Ecology',
    'Human Physiology','Cell Biology','Other'
  ];
  final List<String> _difficulties = ['Easy','Medium','Hard'];

  List<MockTestResult> _mockTests = [];
  bool _loadingMocks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadComponents();
    _loadMockTests();
    _loadWhatIfValues();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); });
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
    super.dispose();
  }

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<void> _setDifficulty(int id, String d) async {
    (await _prefs).setString(_GradeCalcPrefs.diff(id), d);
  }
  Future<String> _getDifficulty(int id) async {
    return (await _prefs).getString(_GradeCalcPrefs.diff(id)) ?? 'Medium';
  }
  Future<void> _setHours(int id, double h) async {
    (await _prefs).setDouble(_GradeCalcPrefs.hours(id), h);
  }
  Future<double> _getHours(int id) async {
    return (await _prefs).getDouble(_GradeCalcPrefs.hours(id)) ?? 0;
  }
  Future<void> _setChapterTag(int id, String t) async {
    (await _prefs).setString(_GradeCalcPrefs.chapter(id), t);
  }
  Future<String> _getChapterTag(int id) async {
    return (await _prefs).getString(_GradeCalcPrefs.chapter(id)) ?? '';
  }
  Future<void> _setExamDate(int id, int? millis) async {
    final p = await _prefs;
    if (millis == null) {
      p.remove(_GradeCalcPrefs.examDate(id));
    } else {
      p.setInt(_GradeCalcPrefs.examDate(id), millis);
    }
  }
  Future<int?> _getExamDate(int id) async {
    return (await _prefs).getInt(_GradeCalcPrefs.examDate(id));
  }
  Future<void> _saveWhatIfValues() async {
    final p = await _prefs;
    final map = _whatIfScores.map((k, v) => MapEntry(k.toString(), v));
    await p.setString(_GradeCalcPrefs.whatIf, jsonEncode(map));
  }
  Future<void> _loadWhatIfValues() async {
    final raw = (await _prefs).getString(_GradeCalcPrefs.whatIf);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _whatIfScores = decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
    }
  }
  Future<void> _setLastPreset(String preset) async {
    (await _prefs).setString(_GradeCalcPrefs.lastPreset, preset);
  }

  Future<void> _loadComponents() async {
    setState(() => _loading = true);
    final components = await DatabaseHelper.instance.getAllGradeComponents();
    for (final c in components) {
      final id = c['id'] as int;
      c['difficulty'] = await _getDifficulty(id);
      c['hoursStudied'] = await _getHours(id);
      c['chapterTag'] = await _getChapterTag(id);
      c['examDateMillis'] = await _getExamDate(id);
    }
    setState(() { _components = components; _loading = false; });
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
    final p = await _prefs;
    await p.remove(_GradeCalcPrefs.diff(id));
    await p.remove(_GradeCalcPrefs.hours(id));
    await p.remove(_GradeCalcPrefs.chapter(id));
    await p.remove(_GradeCalcPrefs.examDate(id));
    HapticFeedback.mediumImpact();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  Future<void> _clearAllComponents() async {
    await DatabaseHelper.instance.clearGradeComponents();
    final p = await _prefs;
    for (final k in p.getKeys().where((k) => k.startsWith('grade_calc_'))) {
      await p.remove(k);
    }
    _whatIfScores.clear();
    await _loadComponents();
    await WidgetService.refreshWidget();
  }

  Future<void> _loadPreset(String subject) async {
    final preset = NeetData.chapterPresets[subject];
    if (preset == null) return;
    await DatabaseHelper.instance.clearGradeComponents();
    final p = await _prefs;
    for (final k in p.getKeys().where((k) => k.startsWith('grade_calc_'))) {
      await p.remove(k);
    }
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
        ),
      );
    }
  }

  Future<void> _loadFullNeetPreset() async {
    await DatabaseHelper.instance.clearGradeComponents();
    final p = await _prefs;
    for (final k in p.getKeys().where((k) => k.startsWith('grade_calc_'))) {
      await p.remove(k);
    }
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
  }

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
      if (lower.contains('physics')) subject = 'Physics';
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
    final percentile = NeetData.getPercentile(total);
    final air = NeetData.getAir(percentile);
    final test = MockTestResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      physicsScore: physics, chemistryScore: chemistry, biologyScore: biology,
      totalScore: total, percentile: percentile, air: air,
      testName: 'Mock Test #${_mockTests.length + 1}',
    );
    await MockTestStorage.save(test);
    await _loadMockTests();
    HapticFeedback.mediumImpact();
    if (total >= 600) _showScoreCelebration(total, percentile, air);
    _physicsMarksController.clear();
    _chemistryMarksController.clear();
    _biologyMarksController.clear();
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

  String _generateStudyPlan() {
    final buffer = StringBuffer();
    buffer.writeln('📊 NEET STUDY PLAN — Generated ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Current Grade: ${_currentGrade.toStringAsFixed(1)}% ($_letterGrade)');
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
      buffer.writeln('');
      buffer.writeln('   ▶ $name');
      buffer.writeln('      Score: ${score.toStringAsFixed(1)}/${total.toStringAsFixed(0)} (${percent.toStringAsFixed(1)}%)');
      buffer.writeln('      Weight: ${weight.toStringAsFixed(1)}% | Difficulty: $diff');
      buffer.writeln('      Hours: ${hours.toStringAsFixed(1)}h | Efficiency: ${eff.toStringAsFixed(2)} pts/hr');
      if (percent < 60) buffer.writeln('      ⚠️ WEAK — needs focus!');
      else if (percent >= 85) buffer.writeln('      ✅ STRONG — maintain!');
    }
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Generated by Event Countdown App');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0, scrolledUnderElevation: 1, backgroundColor: cs.surface,
        title: const Text('NEET Grade Calculator', style: TextStyle(fontWeight: FontWeight.w600)),
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
            Tab(icon: Icon(Icons.psychology), text: 'NEET Simulator'),
            Tab(icon: Icon(Icons.history), text: 'Mock Tests'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
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
              ],
            ),
    );
  }

  Widget _buildComponentsTab(ColorScheme cs) {
    final grade = _currentGrade;
    final gradeColor = _gradeColor(grade);
    final totalWeight = _totalWeightUsed;
    final isOverWeight = totalWeight > 100;
    final rankPrediction = _predictNeetRank();
    final subjectBalance = _getSubjectBalance();
    final smartTarget = _getSmartTarget();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 220, height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220, height: 220,
                        child: CircularProgressIndicator(
                          value: 1.0, strokeWidth: 16,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: (grade / 100).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => SizedBox(
                          width: 220, height: 220,
                          child: CircularProgressIndicator(
                            value: value, strokeWidth: 16,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation(gradeColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${grade.toStringAsFixed(1)}%', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: gradeColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(color: gradeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: Text(_letterGrade, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: gradeColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_components.isNotEmpty)
                _buildRankPredictor(cs, rankPrediction, grade),
              if (smartTarget != null)
                _buildSmartTarget(cs, smartTarget),
              if (subjectBalance.isNotEmpty)
                _buildSubjectBalance(cs, subjectBalance),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      borderRadius: BorderRadius.circular(8),
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
                    else if (_remainingWeight > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${_remainingWeight.toStringAsFixed(1)}% remaining', style: TextStyle(fontSize: 12, color: cs.outline)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildPresetButtons(cs),
              const SizedBox(height: 20),
              if (_components.isNotEmpty)
                _buildWhatIfToggle(cs),
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

  Widget _buildRankPredictor(ColorScheme cs, Map<String, dynamic> rank, double grade) {
    final neetScore = (grade / 100) * 720;
    final tierColor = neetScore >= 650 ? Colors.green : neetScore >= 550 ? Colors.orange : Colors.red;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withOpacity(0.15), cs.surfaceContainerHighest.withOpacity(0.3)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.3)),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: tierColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
            child: Text(
              target,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBalance(ColorScheme cs, Map<String, double> balance) {
    final total = balance.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final colors = {
      'Physics': const Color(0xFF1565C0),
      'Chemistry': const Color(0xFF2E7D32),
      'Biology': const Color(0xFFC62828),
      'Other': Colors.grey,
    };
    final bioPct = ((balance['Biology'] ?? 0) / total * 100).round();
    final phyPct = ((balance['Physics'] ?? 0) / total * 100).round();
    final chemPct = ((balance['Chemistry'] ?? 0) / total * 100).round();
    String warning = '';
    if (bioPct < 40) warning = 'Biology is under-weighted! NEET needs ~50% focus on Bio.';
    else if (phyPct > 40) warning = 'Too much weight on Physics. Balance with Biology.';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
                    flex: (pct * 100).round(),
                    child: Container(
                      color: color.withOpacity(0.8),
                      child: pct > 0.15
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

  Widget _buildPresetButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                TextButton(
                  onPressed: _resetWhatIf,
                  child: Text('Reset', style: TextStyle(fontSize: 11, color: cs.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetPredictor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            child: Text(
                              difficulty,
                              style: TextStyle(
                                fontSize: 10,
                                color: difficulty == 'Hard' ? Colors.red : difficulty == 'Easy' ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (hours > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                              child: Text('${hours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
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
                    child: Text(
                      _getDaysUntil(examDateMillis),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _urgencyColor(examDateMillis)),
                    ),
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
                    child: Text(
                      'Eff: ${efficiency.toStringAsFixed(1)} pts/hr',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: efficiency >= 5 ? Colors.green : efficiency >= 3 ? Colors.orange : Colors.red,
                      ),
                    ),
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
          if (total > 0) ...[
            Text('Subject Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 12),
            _buildNeetSubjectBar('Physics', _simulatedPhysics, 180, const Color(0xFF1565C0), cs),
            const SizedBox(height: 8),
            _buildNeetSubjectBar('Chemistry', _simulatedChemistry, 180, const Color(0xFF2E7D32), cs),
            const SizedBox(height: 8),
            _buildNeetSubjectBar('Biology', _simulatedBiology, 360, const Color(0xFFC62828), cs),
            const SizedBox(height: 20),
          ],
          if (total > 0) _buildCutoffComparison(total, cs),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addMockTest,
              icon: const Icon(Icons.save),
              label: const Text('Save to Mock Test History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSubjectInput(String label, String hint, Color color, TextEditingController controller, ColorScheme cs) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
      ),
    );
  }

  Widget _buildNeetSubjectBar(String name, int marks, int max, Color color, ColorScheme cs) {
    final pct = marks / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
            Text('$marks / $max (${(pct * 100).toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0), minHeight: 10,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCutoffComparison(int marks, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('College Cutoff Comparison', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          ...NeetData.collegeCutoffs.entries.take(8).map((entry) {
            final college = entry.key;
            final cutoffs = entry.value;
            final latestCutoff = cutoffs['2024'] ?? 0;
            final diff = marks - latestCutoff;
            final isSafe = diff >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: isSafe ? Colors.green : cs.error, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(college, style: TextStyle(fontSize: 12, color: cs.onSurface))),
                  Text(isSafe ? '+$diff' : '$diff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSafe ? Colors.green : cs.error)),
                  const SizedBox(width: 4),
                  Text('($latestCutoff)', style: TextStyle(fontSize: 10, color: cs.outline)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 3: MOCK TESTS
  // ═════════════════════════════════════════════════════════════════

  Widget _buildMockTestsTab(ColorScheme cs) {
    if (_loadingMocks) return const Center(child: CircularProgressIndicator());
    if (_mockTests.isEmpty) return _buildEmptyMockTests(cs);

    final recentTests = _mockTests.take(10).toList();
    final avgScore = recentTests.map((t) => t.totalScore).reduce((a, b) => a + b) / recentTests.length;
    final bestScore = recentTests.map((t) => t.totalScore).reduce((a, b) => a > b ? a : b);
    final latest = recentTests.first;
    final trend = recentTests.length > 1 ? latest.totalScore - recentTests[1].totalScore : 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildMiniStat('Tests', '${_mockTests.length}', cs.primary, cs)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMiniStat('Best', '$bestScore', Colors.green, cs)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMiniStat('Avg', '${avgScore.toStringAsFixed(0)}', cs.secondary, cs)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMiniStat('Trend', trend >= 0 ? '+$trend' : '$trend', trend >= 0 ? Colors.green : cs.error, cs)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildTrendChart(recentTests.reversed.toList(), cs),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Test History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Clear all history?'),
                            content: const Text('Delete all mock test records?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await MockTestStorage.clear();
                          await _loadMockTests();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final test = _mockTests[index];
                final color = NeetData.getMarksColor(test.totalScore);
                final dateStr = '${test.date.day}/${test.date.month}/${test.date.year}';
                return Dismissible(
                  key: ValueKey('mock_${test.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                  ),
                  onDismissed: (_) => _deleteMockTest(test.id),
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
                              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                              child: Center(child: Text('${test.totalScore}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(test.testName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                  Text(dateStr, style: TextStyle(fontSize: 11, color: cs.outline)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${test.percentile.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                                Text('AIR ~${test.air}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSubjectMini('P', test.physicsScore, 180, const Color(0xFF1565C0), cs),
                            const SizedBox(width: 8),
                            _buildSubjectMini('C', test.chemistryScore, 180, const Color(0xFF2E7D32), cs),
                            const SizedBox(width: 8),
                            _buildSubjectMini('B', test.biologyScore, 360, const Color(0xFFC62828), cs),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _mockTests.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<MockTestResult> tests, ColorScheme cs) {
    if (tests.length < 2) return const SizedBox.shrink();
    final maxScore = tests.map((t) => t.totalScore).reduce((a, b) => a > b ? a : b).toDouble();
    final minScore = tests.map((t) => t.totalScore).reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxScore - minScore).clamp(50.0, 720.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score Trend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: tests.asMap().entries.map((entry) {
                final test = entry.value;
                final height = ((test.totalScore - minScore) / range * 80 + 20).clamp(20.0, 100.0);
                final color = NeetData.getMarksColor(test.totalScore);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: double.infinity,
                          height: height,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.7),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${test.totalScore}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectMini(String label, int score, int max, Color color, ColorScheme cs) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 4),
            Text('$score', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMockTests(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.history_edu, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('No mock tests yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Go to NEET Simulator tab and enter your marks to start tracking.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.outline)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.psychology),
              label: const Text('Go to Simulator'),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 4: ANALYTICS
  // ═════════════════════════════════════════════════════════════════

  Widget _buildAnalyticsTab(ColorScheme cs) {
    if (_mockTests.isEmpty) return _buildEmptyAnalytics(cs);

    final allTests = _mockTests;
    final avgPhysics = allTests.map((t) => t.physicsScore).reduce((a, b) => a + b) / allTests.length;
    final avgChemistry = allTests.map((t) => t.chemistryScore).reduce((a, b) => a + b) / allTests.length;
    final avgBiology = allTests.map((t) => t.biologyScore).reduce((a, b) => a + b) / allTests.length;
    final physPct = (avgPhysics / 180) * 100;
    final chemPct = (avgChemistry / 180) * 100;
    final bioPct = (avgBiology / 360) * 100;

    final subjects = {'Physics': physPct, 'Chemistry': chemPct, 'Biology': bioPct};
    final weakest = subjects.entries.reduce((a, b) => a.value < b.value ? a : b);
    final strongest = subjects.entries.reduce((a, b) => a.value > b.value ? a : b);

    final scores = allTests.map((t) => t.totalScore).toList();
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / scores.length;
    final stdDev = math.sqrt(variance);
    final consistency = ((1 - (stdDev / 720)) * 100).clamp(0.0, 100.0);

    final firstScore = allTests.last.totalScore;
    final lastScore = allTests.first.totalScore;
    final improvement = lastScore - firstScore;
    final testsCount = allTests.length;
    final improvementPerTest = testsCount > 1 ? improvement / (testsCount - 1) : 0;

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
              children: [
                Text('Performance Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAnalyticsRing('Consistency', consistency, cs.primary, cs),
                    _buildAnalyticsRing('Avg Score', mean, cs.secondary, cs),
                    _buildAnalyticsRing('Improvement', improvement.toDouble(), improvement >= 0 ? Colors.green : cs.error, cs),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject Averages', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 16),
                _buildAnalyticsSubjectBar('Physics', avgPhysics, 180, const Color(0xFF1565C0), cs),
                const SizedBox(height: 12),
                _buildAnalyticsSubjectBar('Chemistry', avgChemistry, 180, const Color(0xFF2E7D32), cs),
                const SizedBox(height: 12),
                _buildAnalyticsSubjectBar('Biology', avgBiology, 360, const Color(0xFFC62828), cs),
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
                    Icon(Icons.lightbulb, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Smart Recommendations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecommendationCard(
                  'Weakest Subject: ${weakest.key}',
                  NeetData.getSubjectAdvice(weakest.key, weakest.value),
                  Icons.trending_down,
                  cs.error,
                  cs,
                ),
                const SizedBox(height: 10),
                _buildRecommendationCard(
                  'Strongest Subject: ${strongest.key}',
                  'Great! Use this confidence to tackle harder topics.',
                  Icons.trending_up,
                  Colors.green,
                  cs,
                ),
                const SizedBox(height: 10),
                _buildRecommendationCard(
                  'Consistency Score: ${consistency.toStringAsFixed(0)}%',
                  consistency > 80
                    ? 'Your scores are very stable. Great job!'
                    : consistency > 60
                      ? 'Scores fluctuate. Focus on building a steady routine.'
                      : 'High variation detected. Work on time management and revision.',
                  Icons.show_chart,
                  consistency > 80 ? Colors.green : consistency > 60 ? Colors.orange : cs.error,
                  cs,
                ),
                const SizedBox(height: 10),
                _buildRecommendationCard(
                  'Improvement Rate: ${improvementPerTest >= 0 ? '+' : ''}${improvementPerTest.toStringAsFixed(1)} marks/test',
                  improvementPerTest > 5
                    ? 'Excellent improvement trajectory! Keep it up.'
                    : improvementPerTest > 0
                      ? 'Steady improvement. Increase practice to accelerate.'
                      : improvementPerTest > -5
                        ? 'Scores are stable. Push harder for breakthrough.'
                        : 'Scores declining. Revisit basics and test strategy.',
                  improvementPerTest >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  improvementPerTest >= 0 ? Colors.green : cs.error,
                  cs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target Score Calculator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 12),
                _buildTargetRow('AIIMS Delhi', 680, mean, cs),
                _buildTargetRow('Top Govt College', 650, mean, cs),
                _buildTargetRow('Govt College', 610, mean, cs),
                _buildTargetRow('Private College', 550, mean, cs),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRing(String label, double value, Color color, ColorScheme cs) {
    final pct = label == 'Improvement' ? (value / 100).clamp(-1.0, 1.0).abs() : (value / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: 72, height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1.0, strokeWidth: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(Colors.transparent),
              ),
              CircularProgressIndicator(
                value: pct, strokeWidth: 6,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                label == 'Avg Score' ? '${value.toStringAsFixed(0)}' : '${value.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildAnalyticsSubjectBar(String name, double avg, int max, Color color, ColorScheme cs) {
    final pct = (avg / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
            Text('${avg.toStringAsFixed(1)} / $max avg', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct, minHeight: 10,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(String title, String advice, IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(advice, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetRow(String college, int target, double current, ColorScheme cs) {
    final diff = target - current;
    final isAchievable = diff <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(college, style: TextStyle(fontSize: 12, color: cs.onSurface)),
          ),
          Expanded(
            flex: 2,
            child: Text('$target marks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAchievable ? Colors.green.withOpacity(0.12) : cs.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isAchievable ? 'Achieved!' : '+${diff.toStringAsFixed(0)} needed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isAchievable ? Colors.green : cs.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnalytics(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.analytics, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('No data for analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Save some mock tests to see your performance analytics and smart recommendations.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.outline)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.psychology),
              label: const Text('Go to Simulator'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.25)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: onTap,
    );
  }
}
