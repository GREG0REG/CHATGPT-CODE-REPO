// FILE: lib/screens/flashcard_screen.dart
// COMPLETE REPLACEMENT — Professional dark-mode flashcard screen
// Redesigned: larger images, 3D flip, interval hints, glassmorphism, session summary
// NEET FEATURES: Formula reference, Mnemonics, Active Recall Timer, Concept Links,
//                Difficulty Heatmap, Daily NEET Fact, Image Zoom, TTS, Annotation

import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../database_helper.dart';
import '../models/flashcard.dart';
import '../models/flashcard_review_history.dart';
import '../services/streak_service.dart';
import 'main_screen.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final AnimationController _flipController;
  late final AnimationController _slideController;
  late final AnimationController _confettiController;
  late final AnimationController _scaleController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  List<Flashcard> _allCards = [];
  List<Flashcard> _dueCards = [];
  List<Flashcard> _filteredCards = [];
  List<String> _subjects = [];
  String? _filterSubject;
  String _searchQuery = '';
  bool _loading = true;
  bool _showingBack = false;

  String _studyMode = 'normal';

  int _totalCards = 0;
  int _dueTodayCount = 0;
  int _masteredCount = 0;
  int _currentStreak = 0;
  double _overallMastery = 0.0;

  int _currentCardIndex = 0;

  final List<_ConfettiParticle> _confettiParticles = [];
  bool _showConfetti = false;

  // Session tracking
  int _sessionCardsReviewed = 0;
  int _sessionCorrect = 0;
  DateTime? _sessionStartTime;

  // NEET Features
  late final FlutterTts _flutterTts;
  bool _ttsEnabled = false;
  bool _showMnemonic = false;
  bool _showFormula = false;
  bool _showConceptLinks = false;
  bool _isAnnotationMode = false;
  bool _showDailyFact = true;
  final List<Offset> _annotationPoints = [];
  int _activeRecallSeconds = 0;
  bool _recallTimerRunning = false;
  String? _generatedMnemonic;

  // NEET Formula Database (client-side)
  final Map<String, Map<String, String>> _neetFormulas = {
    'Physics': {
      'Kinematics': 'v = u + at\ns = ut + ½at²\nv² = u² + 2as',
      'Newton\'s Laws': 'F = ma\nF₁₂ = -F₂₁ (Action-Reaction)',
      'Work & Energy': 'W = F·d·cosθ\nKE = ½mv²\nPE = mgh',
      'Gravitation': 'F = G(m₁m₂)/r²\ng = GM/R²',
      'Electrostatics': 'F = k(q₁q₂)/r²\nE = kQ/r²\nV = kQ/r',
      'Current Electricity': 'V = IR\nP = VI = I²R\nR = ρL/A',
      'Magnetism': 'F = qvBsinθ\nF = ILBsinθ\nB = μ₀I/2πr',
      'Optics': '1/f = 1/v + 1/u\nn = c/v\nδ = (μ-1)A',
      'Modern Physics': 'E = hf = hc/λ\nλ = h/p (de Broglie)\nE = mc²',
    },
    'Chemistry': {
      'Atomic Structure': 'E = -13.6Z²/n² eV\nλ = h/mv\nΔx·Δp ≥ h/4π',
      'Chemical Bonding': 'Bond Order = (N_b - N_a)/2\nDipole moment = q × d',
      'Thermodynamics': 'ΔG = ΔH - TΔS\nΔS = q_rev/T\nK_p = K_c(RT)^Δn',
      'Equilibrium': 'K_w = [H⁺][OH⁻] = 10⁻¹⁴\npH = -log[H⁺]\npOH = -log[OH⁻]',
      'Electrochemistry': 'E°cell = E°cathode - E°anode\nΔG° = -nFE°cell\nΛ_m = κ × 1000/M',
      'Kinetics': 'Rate = k[A]ⁿ\nk = Ae^(-Ea/RT)\nt½ = 0.693/k (1st order)',
      'Solutions': 'π = CRT\nΔT_b = iK_bm\nΔT_f = iK_fm',
      'Organic': 'Markovnikov: H to C with more H\nAnti-Markovnikov: Peroxide effect',
    },
    'Biology': {
      'Cell Biology': 'Cell cycle: G1 → S → G2 → M\nMitosis: Prophase → Metaphase → Anaphase → Telophase',
      'Photosynthesis': '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂\nZ-scheme & Chemiosmosis',
      'Respiration': 'C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + 38 ATP\nGlycolysis → Krebs → ETC',
      'Genetics': 'Hardy-Weinberg: p² + 2pq + q² = 1\nChi-square: Σ(O-E)²/E',
      'Ecology': 'NPP = GPP - R\n10% Law: Energy transfer ~10%',
      'Human Physiology': 'Cardiac Output = HR × SV\nGFR ~125 mL/min\nTidal Volume ~500 mL',
    },
  };

  // NEET Mnemonic Database
  final Map<String, Map<String, String>> _neetMnemonics = {
    'Biology': {
      'cranial nerves': 'Some Say Marry Money But My Brother Says Big Brains Matter More\n(I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII)',
      'taxonomy order': 'Dear King Philip Came Over For Good Soup\n(Domain, Kingdom, Phylum, Class, Order, Family, Genus, Species)',
      'mitosis phases': 'PMAT - Please Make Another Taco\n(Prophase, Metaphase, Anaphase, Telophase)',
      'essential amino acids': 'PVT TIM HALL\n(Phe, Val, Thr, Trp, Ile, Met, His, Arg, Leu, Lys)',
      'krebs cycle': 'Citrate Is Krebs Starting Substrate For Making Oxaloacetate\n(Citrate → Isocitrate → α-KG → Succinyl-CoA → Succinate → Fumarate → Malate → Oxaloacetate)',
      'ecological succession': 'Pioneer → Grasses → Shrubs → Climax\n(Remember: Grass grows before trees)',
      'blood flow heart': 'Superior Vena Cava → Right Atrium → Tricuspid → Right Ventricle → Pulmonary Valve → Lungs → Left Atrium → Mitral → Left Ventricle → Aortic Valve → Body',
      'menstrual cycle': 'Follicular (Days 1-14) → Ovulation (Day 14) → Luteal (Days 15-28)\nFSH rises first, LH surge triggers ovulation',
      'plant hormones': 'Gibberellins Grow, Cytokinins Cell divide, Ethylene ripens, Abscisic acid arrests',
      'nitrogen cycle': 'Nitrogen Fixation → Ammonification → Nitrification → Denitrification\n(Rhizobium fixes, Nitrosomonas oxidizes, Nitrobacter converts)',
    },
    'Chemistry': {
      'electrochemical series': 'K Na Ca Mg Al Zn Fe Ni Sn Pb H Cu Hg Ag Pt Au\n(Kings Never Can Make Any Zebra Feel Happy Like Silly People Having Curly Hair And Pretty Teeth)',
      'periodic trends': 'Across period: size ↓, IE ↑, EN ↑, EA ↑\nDown group: size ↑, IE ↓, EN ↓, EA ↓',
      'organic reagents': 'Lucas Test: ZnCl₂/HCl (3° > 2° > 1°)\nTollen\'s: [Ag(NH₃)₂]⁺ (Aldehydes only)',
      'buffer solutions': 'Weak acid + its salt (acidic buffer)\nWeak base + its salt (basic buffer)\npH = pKa + log([salt]/[acid])',
    },
    'Physics': {
      'right hand rules': 'Fleming\'s Right Hand: Thumb-Motion, Fore-Field, Middle-Current (Generator)\nFleming\'s Left Hand: Thumb-Force, Fore-Field, Middle-Current (Motor)',
      'lens sign convention': 'Real is positive, Virtual is negative\nConverging: f positive, Diverging: f negative',
      'electromagnetic spectrum': 'Radio → Micro → IR → Visible → UV → X-ray → Gamma\n(Remember: Rabbits Mate In Very Unusual eXpensive Gardens)',
    },
  };

  // Daily NEET Facts (high-yield)
  final List<Map<String, String>> _dailyNeetFacts = [
    {'subject': 'Biology', 'fact': 'The human body has 206 bones at adulthood, but babies are born with ~270.'},
    {'subject': 'Biology', 'fact': 'Mitochondria contain their own DNA (circular, like bacteria) - evidence for endosymbiotic theory.'},
    {'subject': 'Biology', 'fact': 'RBCs have no nucleus in mammals, allowing more space for hemoglobin (~270 million per RBC).'},
    {'subject': 'Biology', 'fact': 'The liver is the largest gland and performs over 500 functions including detoxification and bile production.'},
    {'subject': 'Biology', 'fact': 'Action potential: Na⁺ rushes IN (depolarization), K⁺ rushes OUT (repolarization), Na⁺/K⁺ pump restores.'},
    {'subject': 'Biology', 'fact': 'DNA replication is semiconservative - each new DNA has one old and one new strand.'},
    {'subject': 'Biology', 'fact': 'Restriction enzymes cut DNA at specific palindromic sequences (e.g., EcoRI at GAATTC).'},
    {'subject': 'Chemistry', 'fact': 'Benzene has 3 delocalized π electrons forming a ring of electron density above and below the plane.'},
    {'subject': 'Chemistry', 'fact': 'SN1 reactions favor 3° alkyl halides; SN2 favors 1° and methyl halides.'},
    {'subject': 'Chemistry', 'fact': 'd-block elements show variable oxidation states due to participation of both (n-1)d and ns electrons.'},
    {'subject': 'Chemistry', 'fact': 'H₂O₂ acts as both oxidizing and reducing agent. As oxidizer: H₂O₂ + 2H⁺ + 2e⁻ → 2H₂O'},
    {'subject': 'Physics', 'fact': 'In projectile motion, time of flight depends only on vertical component: T = 2u·sinθ/g'},
    {'subject': 'Physics', 'fact': 'For a satellite, orbital velocity v = √(GM/r). Escape velocity = √2 × orbital velocity.'},
    {'subject': 'Physics', 'fact': 'In AC circuits, power factor = cosφ = R/Z. For pure L or C, power factor = 0 (no power dissipation).'},
    {'subject': 'Physics', 'fact': 'Photoelectric effect: KEmax = h(f - f₀) = hf - φ. Threshold frequency f₀ = φ/h.'},
  ];

  // Concept linking map
  final Map<String, List<String>> _conceptLinks = {
    'photosynthesis': ['respiration', 'calvin cycle', 'light reaction', 'chlorophyll', 'photophosphorylation'],
    'respiration': ['photosynthesis', 'krebs cycle', 'glycolysis', 'etc', 'fermentation'],
    'genetics': ['dna replication', 'transcription', 'translation', 'mutation', 'mendel'],
    'cell': ['cell cycle', 'mitosis', 'meiosis', 'organelles', 'membrane transport'],
    'human physiology': ['digestion', 'respiration', 'circulation', 'excretion', 'nervous system'],
    'ecology': ['ecosystem', 'biodiversity', 'population', 'succession', 'pyramid'],
    'organic chemistry': ['reaction mechanism', 'isomerism', 'hydrocarbons', 'biomolecules', 'polymers'],
    'physical chemistry': ['thermodynamics', 'equilibrium', 'electrochemistry', 'kinetics', 'solutions'],
    'inorganic chemistry': ['periodic table', 'chemical bonding', 'coordination compounds', 'p-block', 'd-block'],
    'mechanics': ['kinematics', 'newton laws', 'work energy', 'rotation', 'gravitation'],
    'electromagnetism': ['electrostatics', 'current electricity', 'magnetism', 'emi', 'ac circuits'],
    'modern physics': ['atoms', 'nuclei', 'semiconductors', 'communication', 'dual nature'],
  };

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.5, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _flutterTts = FlutterTts();
    _initTts();
    _loadData();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    _scaleController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (_ttsEnabled) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  String _generateMnemonic(String text) {
    final lower = text.toLowerCase();
    for (final subjectMap in _neetMnemonics.values) {
      for (final entry in subjectMap.entries) {
        if (lower.contains(entry.key.toLowerCase())) {
          return entry.value;
        }
      }
    }
    // Fallback: create acronym from first letters
    final words = text.split(' ').where((w) => w.length > 2).toList();
    if (words.length >= 3) {
      final acronym = words.map((w) => w[0].toUpperCase()).join('');
      return 'Acronym: $acronym\n(${words.map((w) => w[0].toUpperCase() + w.substring(1)).join(', ')})';
    }
    return 'No mnemonic found. Try creating one using the first letters of key terms!';
  }

  List<String> _getRelatedConcepts(String text) {
    final lower = text.toLowerCase();
    final results = <String>[];
    for (final entry in _conceptLinks.entries) {
      if (lower.contains(entry.key)) {
        results.addAll(entry.value);
      }
    }
    // Also check reverse
    for (final entry in _conceptLinks.entries) {
      for (final concept in entry.value) {
        if (lower.contains(concept)) {
          results.add(entry.key);
        }
      }
    }
    return results.toSet().toList()..take(5);
  }

  Map<String, String> _getDailyFact() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return _dailyNeetFacts[dayOfYear % _dailyNeetFacts.length];
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final allCards = await DatabaseHelper.instance.getFlashcards();
    final dueCards = await DatabaseHelper.instance.getFlashcardsDueForReview(
      DateTime.now().millisecondsSinceEpoch,
    );

    final subjects = allCards.map((c) => c.subjectTag).toSet().toList()..sort();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dueToday = allCards.where((c) {
      if (c.nextReviewMillis == null) return true;
      return c.nextReviewMillis! <= todayStart + 86400000;
    }).length;

    final mastered = allCards.where((c) => c.boxLevel >= 4).length;
    final avgBox = allCards.isEmpty ? 0.0 : allCards.map((c) => c.boxLevel).reduce((a, b) => a + b) / allCards.length;

    final streakInfo = await StreakService.instance.getStreakInfo();

    setState(() {
      _allCards = allCards;
      _dueCards = dueCards;
      _filteredCards = _applyFilters(dueCards);
      _subjects = subjects;
      _totalCards = allCards.length;
      _dueTodayCount = dueToday;
      _masteredCount = mastered;
      _currentStreak = streakInfo.currentStreak;
      _overallMastery = avgBox / 5.0;
      _loading = false;
      _showingBack = false;
      _currentCardIndex = 0;
      _flipController.value = 0;
      _sessionCardsReviewed = 0;
      _sessionCorrect = 0;
      _sessionStartTime = DateTime.now();
      _showMnemonic = false;
      _showFormula = false;
      _showConceptLinks = false;
      _isAnnotationMode = false;
      _annotationPoints.clear();
      _generatedMnemonic = null;
      _activeRecallSeconds = 0;
      _recallTimerRunning = false;
    });
  }

  List<Flashcard> _applyFilters(List<Flashcard> cards) {
    var result = cards;

    if (_filterSubject != null) {
      result = result.where((c) => c.subjectTag == _filterSubject).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) =>
        c.frontText.toLowerCase().contains(query) ||
        c.backText.toLowerCase().contains(query) ||
        c.subjectTag.toLowerCase().contains(query) ||
        (c.tagsJson.toLowerCase().contains(query))
      ).toList();
    }

    if (_studyMode == 'shuffle') {
      result = result.toList()..shuffle();
    }

    return result;
  }

  void _setStudyMode(String mode) {
    setState(() {
      _studyMode = mode;
      if (mode == 'cram' && _filterSubject != null) {
        _filteredCards = _allCards.where((c) => c.subjectTag == _filterSubject).toList()..shuffle();
      } else if (mode == 'shuffle') {
        _filteredCards = _allCards.toList()..shuffle();
      } else if (mode == 'favorites') {
        _filteredCards = _allCards.where((c) => c.isFavorite).toList();
      } else {
        _filteredCards = _applyFilters(_dueCards);
      }
      _currentCardIndex = 0;
      _showingBack = false;
      _flipController.value = 0;
      _sessionCardsReviewed = 0;
      _sessionCorrect = 0;
      _sessionStartTime = DateTime.now();
      _showMnemonic = false;
      _showFormula = false;
      _showConceptLinks = false;
      _generatedMnemonic = null;
      _activeRecallSeconds = 0;
      _recallTimerRunning = false;
    });
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    if (_flipController.isCompleted) {
      _flipController.reverse();
      setState(() => _showingBack = false);
    } else {
      _flipController.forward();
      setState(() => _showingBack = true);
      // Start recall timer when answer is revealed
      if (!_recallTimerRunning && _filteredCards.isNotEmpty) {
        _startRecallTimer();
      }
    }
  }

  void _startRecallTimer() {
    setState(() => _recallTimerRunning = true);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_recallTimerRunning) return false;
      setState(() => _activeRecallSeconds++);
      return true;
    });
  }

  void _stopRecallTimer() {
    setState(() => _recallTimerRunning = false);
  }

  String _getIntervalHint(String difficulty, int currentBox) {
    final baseIntervals = [0, 600000, 3600000, 86400000, 259200000, 604800000];
    final multiplier = switch(difficulty) {
      'again' => 0.5,
      'hard' => 0.75,
      'good' => 1.0,
      'easy' => 1.5,
      _ => 1.0,
    };

    int newBox;
    switch (difficulty) {
      case 'again': newBox = 1; break;
      case 'hard': newBox = max(currentBox - 1, 1); break;
      case 'good': newBox = min(currentBox + 1, 5); break;
      case 'easy': newBox = min(currentBox + 2, 5); break;
      default: newBox = currentBox;
    }

    final ms = (baseIntervals[newBox] * multiplier).round();
    if (ms < 60000) return '<1m';
    if (ms < 3600000) return '${(ms / 60000).round()}m';
    if (ms < 86400000) return '${(ms / 3600000).round()}h';
    return '${(ms / 86400000).round()}d';
  }

  Future<void> _answer({required String difficulty}) async {
    if (_filteredCards.isEmpty) return;

    if (_currentCardIndex < 0 || _currentCardIndex >= _filteredCards.length) {
      _currentCardIndex = 0;
      if (_filteredCards.isEmpty) {
        await _loadData();
        return;
      }
    }

    final card = _filteredCards[_currentCardIndex];
    _stopRecallTimer();

    await _slideController.forward();

    _flipController.value = 0;
    setState(() => _showingBack = false);

    final now = DateTime.now().millisecondsSinceEpoch;

    int newBox;
    switch (difficulty) {
      case 'again':
        newBox = 1;
        break;
      case 'hard':
        newBox = max(card.boxLevel - 1, 1);
        break;
      case 'good':
        newBox = min(card.boxLevel + 1, 5);
        break;
      case 'easy':
        newBox = min(card.boxLevel + 2, 5);
        break;
      default:
        newBox = card.boxLevel;
    }

    final baseIntervals = [0, 600000, 3600000, 86400000, 259200000, 604800000];
    final intervalMultiplier = switch(difficulty) {
      'again' => 0.5,
      'hard' => 0.75,
      'good' => 1.0,
      'easy' => 1.5,
      _ => 1.0,
    };

    final nextReview = now + (baseIntervals[newBox] * intervalMultiplier).round();

    double newDifficulty = card.difficultyRating;
    final diffMap = {'again': 5.0, 'hard': 4.0, 'good': 2.5, 'easy': 1.0};
    newDifficulty = (newDifficulty + (diffMap[difficulty] ?? 3.0)) / 2;

    final updated = card.copyWith(
      boxLevel: newBox,
      lastReviewedMillis: now,
      nextReviewMillis: nextReview,
      difficultyRating: newDifficulty,
    );

    await DatabaseHelper.instance.updateFlashcard(updated);

    // Track session stats
    _sessionCardsReviewed++;
    if (difficulty == 'good' || difficulty == 'easy') {
      _sessionCorrect++;
    }

    // Record review history
    final sessionId = _sessionStartTime != null
        ? _sessionStartTime!.millisecondsSinceEpoch.toString()
        : now.toString();
    await DatabaseHelper.instance.insertFlashcardReviewHistory(
      FlashcardReviewHistory(
        cardId: card.id!,
        reviewedAtMillis: now,
        difficulty: difficulty,
        timeSpentSeconds: _activeRecallSeconds,
        boxLevelBefore: card.boxLevel,
        boxLevelAfter: newBox,
        sessionId: sessionId,
      ),
    );

    final streakInfo = await StreakService.instance.recordStudySession();
    setState(() => _currentStreak = streakInfo.currentStreak);

    HapticFeedback.mediumImpact();

    _slideController.value = 0;
    _activeRecallSeconds = 0;

    final wasLastCard = _currentCardIndex >= _filteredCards.length - 1;

    setState(() {
      if (wasLastCard) {
        _currentCardIndex = 0;
        _triggerConfetti();
        _filteredCards = [];
      } else {
        _currentCardIndex++;
      }
    });

    if (wasLastCard) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadData();
    }
  }

  Future<void> _toggleFavorite(Flashcard card) async {
    final updated = card.copyWith(isFavorite: !card.isFavorite);
    await DatabaseHelper.instance.updateFlashcard(updated);
    HapticFeedback.lightImpact();
    await _loadData();
  }

  void _triggerConfetti() {
    setState(() {
      _showConfetti = true;
      _confettiParticles.clear();
      final random = Random();
      for (int i = 0; i < 60; i++) {
        _confettiParticles.add(_ConfettiParticle(
          x: random.nextDouble() * 400 - 200,
          y: random.nextDouble() * -350 - 100,
          color: [
            const Color(0xFF14B8A6), const Color(0xFF34D399),
            const Color(0xFFF59E0B), const Color(0xFFFBBF24),
            const Color(0xFFEF4444), const Color(0xFFF87171),
            const Color(0xFF8B5CF6), const Color(0xFFA78BFA),
            const Color(0xFF3B82F6), const Color(0xFF60A5FA),
          ][random.nextInt(10)],
          size: random.nextDouble() * 10 + 4,
          speed: random.nextDouble() * 4 + 2,
          angle: random.nextDouble() * 6.28,
          rotationSpeed: random.nextDouble() * 10 - 5,
        ));
      }
    });
    _confettiController.forward(from: 0).then((_) {
      setState(() => _showConfetti = false);
    });
  }

  Future<void> _deleteCard(Flashcard card) async {
    if (card.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1f),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete card?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteFlashcard(card.id!);
      _loadData();
    }
  }

  Future<void> _pickImage(Function(String?) onImagePicked) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        onImagePicked(picked.path);
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _showCardDialog({Flashcard? existing}) async {
    final subjects = _subjects;
    String subject = existing?.subjectTag ?? (subjects.isNotEmpty ? subjects.first : '');
    final frontController = TextEditingController(text: existing?.frontText ?? '');
    final backController = TextEditingController(text: existing?.backText ?? '');
    final tagsController = TextEditingController(
      text: _tagsFromJson(existing?.tagsJson ?? '[]'),
    );
    String? imagePath = existing?.imagePath;
    bool isNewSubject = !subjects.contains(subject) && subjects.isNotEmpty;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a1f),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(existing == null ? 'New Card' : 'Edit Card', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: isNewSubject ? null : (subjects.contains(subject) ? subject : null),
                      hint: const Text('Subject', style: TextStyle(color: Colors.grey)),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1a1a1f),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                      ),
                      items: [
                        ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white)))),
                        const DropdownMenuItem(value: '__new__', child: Text('+ New subject', style: TextStyle(color: Color(0xFF14B8A6)))),
                      ],
                      onChanged: (v) {
                        if (v == '__new__') {
                          setDialogState(() => isNewSubject = true);
                        } else if (v != null) {
                          setDialogState(() {
                            isNewSubject = false;
                            subject = v;
                          });
                        }
                      },
                    ),
                    if (isNewSubject) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'New subject name',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                        ),
                        onChanged: (v) => subject = v,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: frontController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Front (Question)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: backController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Back (Answer)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tagsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tags (comma separated)',
                        hintText: 'e.g. vocabulary, chapter 3',
                        hintStyle: const TextStyle(color: Colors.white24),
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                        prefixIcon: const Icon(Icons.label_outline, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _pickImage((path) => setDialogState(() => imagePath = path)),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              imagePath != null ? Icons.image : Icons.add_photo_alternate_outlined,
                              color: const Color(0xFF14B8A6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                imagePath != null ? 'Image added' : 'Add image (optional)',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            if (imagePath != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                onPressed: () => setDialogState(() => imagePath = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (imagePath != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(imagePath!),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    final frontText = frontController.text.trim();
                    final backText = backController.text.trim();
                    final subjectText = subject.trim();

                    if (frontText.isEmpty || backText.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Both front and back fields are required'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (subjectText.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Subject is required'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    subject = subjectText;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final finalSubject = subject.trim().isEmpty ? 'General' : subject.trim();
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      final tagsText = tagsController.text.trim();
      final tagsJson = tagsText.isEmpty ? '[]' : _tagsToJson(tagsText);

      final newCard = Flashcard(
        id: existing?.id,
        subjectTag: finalSubject,
        frontText: frontController.text.trim(),
        backText: backController.text.trim(),
        boxLevel: existing?.boxLevel ?? 1,
        lastReviewedMillis: existing?.lastReviewedMillis,
        nextReviewMillis: existing?.nextReviewMillis,
        createdAtMillis: existing?.createdAtMillis ?? nowMillis,
        imagePath: imagePath,
        tagsJson: tagsJson,
        isFavorite: existing?.isFavorite ?? false,
        difficultyRating: existing?.difficultyRating ?? 3.0,
      );

      if (existing != null && existing.id != null) {
        await DatabaseHelper.instance.updateFlashcard(newCard);
      } else {
        final insertedId = await DatabaseHelper.instance.insertFlashcard(newCard);
        debugPrint('Flashcard inserted with ID: $insertedId');
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing != null ? 'Card updated!' : 'Card added!'),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    frontController.dispose();
    backController.dispose();
    tagsController.dispose();
  }

  String _tagsToJson(String commaSeparated) {
    final tags = commaSeparated.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    return jsonEncode(tags);
  }

  String _tagsFromJson(String jsonStr) {
    try {
      final List<dynamic> tags = jsonDecode(jsonStr);
      return tags.join(', ');
    } catch (e) {
      return jsonStr;
    }
  }

  List<String> _getTagsList(Flashcard card) {
    if (card.tagsJson.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(card.tagsJson);
      return decoded.map((t) => t.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _showBulkImportDialog() async {
    final controller = TextEditingController();
    String? selectedSubject;
    if (_subjects.isNotEmpty) selectedSubject = _subjects.first;
    bool isNewSubject = false;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a1f),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Bulk Import Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Format: question | answer (one per line)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    if (_subjects.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: isNewSubject ? null : selectedSubject,
                        hint: const Text('Select Subject', style: TextStyle(color: Colors.grey)),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1a1a1f),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                        ),
                        items: [
                          ..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white)))),
                          const DropdownMenuItem(value: '__new__', child: Text('+ New subject', style: TextStyle(color: Color(0xFF14B8A6)))),
                        ],
                        onChanged: (v) {
                          if (v == '__new__') {
                            setDialogState(() => isNewSubject = true);
                          } else {
                            setDialogState(() {
                              isNewSubject = false;
                              selectedSubject = v;
                            });
                          }
                        },
                      ),
                    ],
                    if (isNewSubject || _subjects.isEmpty) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'New subject name',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                        ),
                        onChanged: (v) => selectedSubject = v,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: 'What is the capital of France? | Paris\n2 + 2 = ? | 4',
                        hintStyle: const TextStyle(color: Colors.white24),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty || selectedSubject == null || selectedSubject!.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter cards and select a subject'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'text': controller.text,
                    'subject': selectedSubject,
                  });
                },
                child: const Text('Import', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();

    if (result != null) {
      final lines = (result['text'] as String).split('\n');
      int imported = 0;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          final card = Flashcard(
            subjectTag: (result['subject'] as String).trim(),
            frontText: parts[0].trim(),
            backText: parts[1].trim(),
            createdAtMillis: nowMillis,
          );
          await DatabaseHelper.instance.insertFlashcard(card);
          imported++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $imported cards!'),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      await _loadData();
    }
  }

  void _showImageZoom(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            color: Colors.black.withOpacity(0.95),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFormulaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a1f),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NEET Formula Quick Reference',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'High-yield formulas for quick revision',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: _neetFormulas.entries.map((subjectEntry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14B8A6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              subjectEntry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14B8A6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...subjectEntry.value.entries.map((formulaEntry) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10, left: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formulaEntry.key,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formulaEntry.value,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade400,
                                      fontFamily: 'monospace',
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white70),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Flashcards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.functions, color: Colors.white70),
            tooltip: 'NEET Formula Sheet',
            onPressed: _showFormulaSheet,
          ),
          IconButton(
            icon: Icon(
              _ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: _ttsEnabled ? const Color(0xFF14B8A6) : Colors.white70,
            ),
            tooltip: 'Text-to-Speech',
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) _flutterTts.stop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_ttsEnabled ? 'TTS Enabled' : 'TTS Disabled'),
                  backgroundColor: const Color(0xFF14B8A6),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70),
            tooltip: 'Add card',
            onPressed: () => _showCardDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white70),
            tooltip: 'Bulk import',
            onPressed: _showBulkImportDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : _allCards.isEmpty
              ? _buildEmptyState(cs)
              : _buildMainContent(cs),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.2)),
              ),
              child: Icon(Icons.style_outlined, size: 38, color: cs.primary),
            ),
            const SizedBox(height: 28),
            Text(
              'No flashcards yet!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              'Create cards to start studying with spaced repetition.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.outline),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _showCardDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Card'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _showBulkImportDialog,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Bulk Import'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ColorScheme cs) {
    return Column(
      children: [
        _buildDashboard(cs),
        _buildSearchBar(cs),
        _buildModeChips(cs),
        if (_showDailyFact && _filteredCards.isEmpty && _searchQuery.isEmpty && _studyMode == 'normal')
          _buildDailyNeetFact(cs),
        Expanded(
          child: _filteredCards.isEmpty && _searchQuery.isEmpty && _studyMode != 'favorites'
              ? _buildSubjectDecks(cs)
              : _buildReviewState(cs),
        ),
      ],
    );
  }

  Widget _buildDashboard(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(Icons.style_outlined, _totalCards.toString(), 'Total', cs),
              _buildStatItem(Icons.today_outlined, _dueTodayCount.toString(), 'Due', cs),
              _buildStatItem(Icons.emoji_events_outlined, _masteredCount.toString(), 'Mastered', cs),
              _buildStatItem(Icons.local_fire_department_outlined, _currentStreak.toString(), 'Streak', cs),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                Text('Overall Mastery', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${(_overallMastery * 100).round()}%', style: const TextStyle(fontSize: 12, color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _overallMastery.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF14B8A6)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyNeetFact(ColorScheme cs) {
    final fact = _getDailyFact();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF14B8A6).withOpacity(0.15),
            const Color(0xFF3B82F6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Daily NEET Fact',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showDailyFact = false),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getSubjectColor(fact['subject']!).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fact['subject']!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _getSubjectColor(fact['subject']!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fact['fact']!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade300, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('physics')) return const Color(0xFF3B82F6);
    if (lower.contains('chemistry')) return const Color(0xFFF59E0B);
    if (lower.contains('biology')) return const Color(0xFF22C55E);
    return const Color(0xFF14B8A6);
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          onChanged: (v) {
            setState(() {
              _searchQuery = v;
              _filteredCards = _applyFilters(_dueCards);
            });
          },
          decoration: InputDecoration(
            hintText: 'Search cards, subjects, tags...',
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _filteredCards = _applyFilters(_dueCards);
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChips(ColorScheme cs) {
    final modes = [
      ('normal', 'Due'),
      ('shuffle', 'Shuffle'),
      ('favorites', 'Favorites'),
      ('cram', 'Cram'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: modes.map((mode) {
            final isSelected = _studyMode == mode.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _setStudyMode(mode.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF14B8A6).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF14B8A6).withOpacity(0.3) : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Text(
                    mode.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF14B8A6) : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectDecks(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              Text(
                'Your Decks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade300),
              ),
              const Spacer(),
              Text(
                'Long-press for Cram Mode',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _subjects.length,
            itemBuilder: (context, index) {
              final subject = _subjects[index];
              final subjectCards = _allCards.where((c) => c.subjectTag == subject).toList();
              final dueCount = subjectCards.where((c) {
                if (c.nextReviewMillis == null) return true;
                return c.nextReviewMillis! <= DateTime.now().millisecondsSinceEpoch;
              }).length;
              final avgBox = subjectCards.isEmpty ? 0.0 : subjectCards.map((c) => c.boxLevel).reduce((a, b) => a + b) / subjectCards.length;
              final progress = avgBox / 5.0;
              final favCount = subjectCards.where((c) => c.isFavorite).length;

              // Calculate box distribution for heatmap
              final boxDistribution = List.generate(5, (i) => subjectCards.where((c) => c.boxLevel == i + 1).length);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _filterSubject = subject;
                      _filteredCards = _applyFilters(_dueCards);
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      _filterSubject = subject;
                      _studyMode = 'cram';
                      _filteredCards = _allCards.where((c) => c.subjectTag == subject).toList()..shuffle();
                    });
                    HapticFeedback.heavyImpact();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 5,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                              ),
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF14B8A6)),
                                strokeCap: StrokeCap.round,
                              ),
                              Center(
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    subject,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (dueCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$dueCount DUE',
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${subjectCards.length} cards • Box avg: ${avgBox.toStringAsFixed(1)}${favCount > 0 ? ' • $favCount star' : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              // Box Distribution Heatmap
                              Row(
                                children: List.generate(5, (i) {
                                  final boxCount = boxDistribution[i];
                                  final maxCount = boxDistribution.reduce((a, b) => a > b ? a : b);
                                  final intensity = maxCount > 0 ? boxCount / maxCount : 0.0;
                                  return Expanded(
                                    child: Container(
                                      height: 6,
                                      margin: const EdgeInsets.only(right: 3),
                                      decoration: BoxDecoration(
                                        color: boxCount > 0
                                          ? Color.lerp(
                                              const Color(0xFFEF4444),
                                              const Color(0xFF22C55E),
                                              i / 4.0,
                                            )?.withOpacity(0.3 + (intensity * 0.7))
                                          : Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: boxCount > 0 ? Center(
                                        child: Text(
                                          '$boxCount',
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ),
                                      ) : null,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Box 1', style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
                                  const Spacer(),
                                  Text('Box 5', style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade700, size: 22),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

    Widget _buildReviewState(ColorScheme cs) {
    if (_filteredCards.isEmpty) {
      return _buildAllCaughtUp(cs);
    }

    if (_currentCardIndex < 0 || _currentCardIndex >= _filteredCards.length) {
      _currentCardIndex = 0;
      if (_filteredCards.isEmpty) {
        return _buildAllCaughtUp(cs);
      }
    }

    final card = _filteredCards[_currentCardIndex];
    final relatedConcepts = _getRelatedConcepts(card.frontText + ' ' + card.backText);
    final subjectFormulas = _neetFormulas[card.subjectTag] ?? {};

    return Stack(
      children: [
        Column(
          children: [
            // Card Counter Header with NEET Tools
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Card ${_currentCardIndex + 1} of ${_filteredCards.length}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  // Active Recall Timer
                  if (_recallTimerRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            '${_activeRecallSeconds}s',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _studyMode == 'cram' ? 'Cram Mode' : _studyMode == 'shuffle' ? 'Shuffle' : _studyMode == 'favorites' ? 'Favorites' : 'Due Cards',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF14B8A6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _toggleFavorite(card),
                    child: Icon(
                      card.isFavorite ? Icons.star : Icons.star_border,
                      color: card.isFavorite ? const Color(0xFFF59E0B) : Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: List.generate(5, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < card.boxLevel ? const Color(0xFF14B8A6) : Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Box ${card.boxLevel}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_filterSubject != null || _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterSubject = null;
                        _searchQuery = '';
                        _studyMode = 'normal';
                        _filteredCards = _dueCards;
                        _currentCardIndex = 0;
                      });
                    },
                    icon: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF14B8A6)),
                    label: const Text('Back to Decks', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.w600)),
                  ),
                ),
              ),

            // NEET Feature Bar (Mnemonic, Formula, Concept Links, TTS)
            if (_showingBack)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildNeetToolChip(
                        icon: Icons.psychology,
                        label: 'Mnemonic',
                        isActive: _showMnemonic,
                        onTap: () {
                          setState(() {
                            _showMnemonic = !_showMnemonic;
                            if (_showMnemonic && _generatedMnemonic == null) {
                              _generatedMnemonic = _generateMnemonic(card.frontText + ' ' + card.backText);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      if (subjectFormulas.isNotEmpty)
                        _buildNeetToolChip(
                          icon: Icons.functions,
                          label: 'Formula',
                          isActive: _showFormula,
                          onTap: () => setState(() => _showFormula = !_showFormula),
                        ),
                      const SizedBox(width: 8),
                      if (relatedConcepts.isNotEmpty)
                        _buildNeetToolChip(
                          icon: Icons.account_tree,
                          label: 'Links',
                          isActive: _showConceptLinks,
                          onTap: () => setState(() => _showConceptLinks = !_showConceptLinks),
                        ),
                      const SizedBox(width: 8),
                      _buildNeetToolChip(
                        icon: Icons.volume_up,
                        label: 'Speak',
                        isActive: false,
                        onTap: () => _speak('${card.frontText}. Answer: ${card.backText}'),
                      ),
                      if (card.imagePath != null) ...[
                        const SizedBox(width: 8),
                        _buildNeetToolChip(
                          icon: _isAnnotationMode ? Icons.edit_off : Icons.edit,
                          label: _isAnnotationMode ? 'Done' : 'Annotate',
                          isActive: _isAnnotationMode,
                          onTap: () => setState(() {
                            _isAnnotationMode = !_isAnnotationMode;
                            if (!_isAnnotationMode) _annotationPoints.clear();
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Mnemonic Panel
            if (_showMnemonic && _showingBack)
              _buildMnemonicPanel(card),

            // Formula Panel
            if (_showFormula && _showingBack && subjectFormulas.isNotEmpty)
              _buildFormulaPanel(subjectFormulas),

            // Concept Links Panel
            if (_showConceptLinks && _showingBack && relatedConcepts.isNotEmpty)
              _buildConceptLinksPanel(relatedConcepts),

            const SizedBox(height: 4),

            // 3D Flip Card with Larger Image
            Expanded(
              child: GestureDetector(
                onTap: _isAnnotationMode ? null : _toggleFlip,
                onHorizontalDragEnd: _isAnnotationMode ? null : (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < -250) {
                    _answer(difficulty: 'again');
                  } else if (details.primaryVelocity! > 250) {
                    _answer(difficulty: 'good');
                  }
                },
                onPanUpdate: _isAnnotationMode && card.imagePath != null
                    ? (details) {
                        setState(() {
                          _annotationPoints.add(details.localPosition);
                        });
                      }
                    : null,
                child: AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _slideAnimation,
                      child: AnimatedBuilder(
                        animation: _flipController,
                        builder: (context, child) {
                          final angle = _flipController.value * 3.1415926535897932;
                          final isFrontVisible = angle < 1.5708;

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isFrontVisible
                                ? _buildCardFace(card, cs, isFront: true)
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(3.1415926535897932),
                                    alignment: Alignment.center,
                                    child: _buildCardFace(card, cs, isFront: false),
                                  ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // Difficulty + Hints
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Difficulty: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        Text(
                          '${card.difficultyRating.toStringAsFixed(1)}/5',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _difficultyColor(card.difficultyRating),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (card.difficultyRating / 5).clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withOpacity(0.05),
                              valueColor: AlwaysStoppedAnimation(_difficultyColor(card.difficultyRating)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap card to flip • Swipe left = Again • Swipe right = Good',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    // Answer Buttons with Interval Hints
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnswerButton(
                            'Again',
                            Icons.close,
                            const Color(0xFFEF4444),
                            () => _answer(difficulty: 'again'),
                            _getIntervalHint('again', card.boxLevel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAnswerButton(
                            'Hard',
                            Icons.trending_down,
                            const Color(0xFFF59E0B),
                            () => _answer(difficulty: 'hard'),
                            _getIntervalHint('hard', card.boxLevel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAnswerButton(
                            'Good',
                            Icons.check,
                            const Color(0xFF14B8A6),
                            () => _answer(difficulty: 'good'),
                            _getIntervalHint('good', card.boxLevel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAnswerButton(
                            'Easy',
                            Icons.star,
                            const Color(0xFF22C55E),
                            () => _answer(difficulty: 'easy'),
                            _getIntervalHint('easy', card.boxLevel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (_showConfetti) _buildConfettiOverlay(),
      ],
    );
  }

  Widget _buildNeetToolChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF14B8A6).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF14B8A6).withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? const Color(0xFF14B8A6) : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF14B8A6) : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMnemonicPanel(Flashcard card) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.15),
            const Color(0xFFA78BFA).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              const Text(
                'Memory Aid',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _generatedMnemonic = _generateMnemonic(card.frontText + ' ' + card.backText + ' ' + DateTime.now().toString());
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Text('Regenerate', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _generatedMnemonic ?? _generateMnemonic(card.frontText + ' ' + card.backText),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade300,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaPanel(Map<String, String> formulas) {
    // Find best matching formula
    String? matchedTitle;
    String? matchedFormula;
    if (_filteredCards.isNotEmpty && _currentCardIndex < _filteredCards.length) {
      final cardText = (_filteredCards[_currentCardIndex].frontText + ' ' + _filteredCards[_currentCardIndex].backText).toLowerCase();
      for (final entry in formulas.entries) {
        if (cardText.contains(entry.key.toLowerCase())) {
          matchedTitle = entry.key;
          matchedFormula = entry.value;
          break;
        }
      }
    }
    // Show first formula if no match
    matchedTitle ??= formulas.keys.first;
    matchedFormula ??= formulas.values.first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.15),
            const Color(0xFF60A5FA).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions, size: 16, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              const Text(
                'Related Formula',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
              ),
              const Spacer(),
              Text(
                matchedTitle!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            matchedFormula!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade300,
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptLinksPanel(List<String> concepts) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF14B8A6).withOpacity(0.1),
            const Color(0xFF34D399).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree, size: 16, color: Color(0xFF14B8A6)),
              const SizedBox(width: 6),
              const Text(
                'Related Concepts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: concepts.take(6).map((concept) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  concept,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _difficultyColor(double rating) {
    if (rating <= 2) return const Color(0xFF22C55E);
    if (rating <= 3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildAnswerButton(String label, IconData icon, Color color, VoidCallback onPressed, String intervalHint) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        onPressed();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    intervalHint,
                    style: TextStyle(fontSize: 10, color: color.withOpacity(0.6), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllCaughtUp(ColorScheme cs) {
    final accuracy = _sessionCardsReviewed > 0
        ? (_sessionCorrect / _sessionCardsReviewed * 100).round()
        : 0;

    // Calculate predicted readiness
    final predictedReadiness = _allCards.isEmpty ? 0 : (_allCards.where((c) => c.boxLevel >= 3).length / _allCards.length * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF34D399)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.check, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 28),
            Text(
              _studyMode == 'cram' ? 'Cram session complete!' : 'You\'re all caught up!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _studyMode == 'cram'
                ? 'Great job reviewing everything!'
                : 'No cards due for review right now.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            if (_sessionCardsReviewed > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSessionStat('Reviewed', _sessionCardsReviewed.toString(), const Color(0xFF14B8A6)),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                        _buildSessionStat('Accuracy', '$accuracy%', const Color(0xFFF59E0B)),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                        _buildSessionStat('Streak', _currentStreak.toString(), const Color(0xFF22C55E)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up, size: 20, color: Color(0xFF14B8A6)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'NEET Readiness Score',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: predictedReadiness / 100,
                                    backgroundColor: Colors.white.withOpacity(0.05),
                                    valueColor: const AlwaysStoppedAnimation(Color(0xFF14B8A6)),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$predictedReadiness% of your cards are in Box 3+ (exam-ready)',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$predictedReadiness%',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _filterSubject = null;
                  _searchQuery = '';
                  _studyMode = 'normal';
                });
                _loadData();
              },
              icon: const Icon(Icons.home),
              label: const Text('Back to Decks'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildCardFace(Flashcard card, ColorScheme cs, {required bool isFront}) {
    final tags = _getTagsList(card);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isFront ? Colors.white.withOpacity(0.08) : const Color(0xFF14B8A6).withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFront ? Colors.black.withOpacity(0.3) : const Color(0xFF14B8A6).withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Annotation overlay
          if (_isAnnotationMode && !isFront && card.imagePath != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _AnnotationPainter(_annotationPoints),
              ),
            ),

          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (card.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.star, color: Color(0xFFF59E0B), size: 22),
                  ),
                PopupMenuButton<String>(
                  color: const Color(0xFF1a1a1f),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showCardDialog(existing: card);
                    } else if (value == 'delete') {
                      _deleteCard(card);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, color: Colors.white70),
                        title: Text('Edit', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      card.subjectTag,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14B8A6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // MUCH LARGER IMAGE with tap-to-zoom
                  if (isFront && card.imagePath != null) ...[
                    GestureDetector(
                      onTap: () => _showImageZoom(card.imagePath!),
                      child: Hero(
                        tag: 'card_image_${card.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight: 320,
                              minHeight: 200,
                              maxWidth: double.infinity,
                            ),
                            child: Image.file(
                              File(card.imagePath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Zoom hint
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Tap image to zoom',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!isFront && card.imagePath != null) ...[
                    GestureDetector(
                      onTap: () => _showImageZoom(card.imagePath!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 220,
                            minHeight: 120,
                            maxWidth: double.infinity,
                          ),
                          child: Image.file(
                            File(card.imagePath!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            opacity: const AlwaysStoppedAnimation(0.25),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    isFront ? card.frontText : card.backText,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isFront && tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAnnotationMode ? Icons.edit : Icons.touch_app_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isAnnotationMode
                              ? 'Draw on image to annotate'
                              : isFront
                                  ? 'Tap to reveal answer'
                                  : 'Tap to see question',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfettiOverlay() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        return Stack(
          children: _confettiParticles.map((particle) {
            final progress = _confettiController.value;
            final y = particle.y + (progress * 450 * particle.speed);
            final x = particle.x + (sin(progress * 10 + particle.angle) * 60);
            final opacity = 1.0 - progress;
            final rotation = progress * particle.rotationSpeed * 50;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: MediaQuery.of(context).size.height / 3 + y,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: rotation,
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      color: particle.color,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final Color color;
  final double size;
  final double speed;
  final double angle;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
    required this.angle,
    required this.rotationSpeed,
  });
}

// Annotation painter for drawing on flashcard images
class _AnnotationPainter extends CustomPainter {
  final List<Offset> points;

  _AnnotationPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
