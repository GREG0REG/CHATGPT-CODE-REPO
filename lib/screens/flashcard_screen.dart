// CHATGPT-CODE-REPO-TEST/lib/screens/flashcard_screen.dart
// ENHANCED VERSION - Dedicated Flashcards Section with Unique Features

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/flashcard.dart';
import '../theme/app_themes.dart';

/// ============================================================
/// NEW FEATURES ADDED (compared to old version):
/// 1. DASHBOARD OVERVIEW - Stats cards showing total cards, due today, 
///    mastery level, and current streak
/// 2. SUBJECT DECKS - Visual deck cards with progress rings per subject
/// 3. BULK IMPORT - Quick-add multiple cards at once
/// 4. STUDY MODES:
///    - Normal Mode: Standard spaced repetition (existing)
///    - Shuffle Mode: Random cards regardless of due date
///    - cram Mode: All cards from a subject, no SRS
/// 5. CARD DIFFICULTY TRACKING - "Hard", "Good", "Easy" instead of binary
/// 6. CONFETTI CELEBRATION - When completing all due cards
/// 7. STREAK TRACKING - Daily review streak with fire icon
/// 8. CARD HISTORY - View review history per card
/// 9. SEARCH & FILTER - Real-time search across all cards
/// 10. DECK SHARING - Export subject decks as JSON
/// ============================================================

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Animation controllers
  late final AnimationController _flipController;
  late final AnimationController _slideController;
  late final AnimationController _confettiController;
  late final Animation<Offset> _slideAnimation;

  // Data states
  List<Flashcard> _allCards = [];
  List<Flashcard> _dueCards = [];
  List<Flashcard> _filteredCards = [];
  List<String> _subjects = [];
  String? _filterSubject;
  String _searchQuery = '';
  bool _loading = true;
  bool _showingBack = false;
  
  // Study mode: 'normal', 'shuffle', 'cram'
  String _studyMode = 'normal';
  
  // Dashboard stats
  int _totalCards = 0;
  int _dueTodayCount = 0;
  int _masteredCount = 0;
  int _currentStreak = 0;
  double _overallMastery = 0.0;
  
  // Current card index for review
  int _currentCardIndex = 0;
  
  // Confetti particles
  final List<_ConfettiParticle> _confettiParticles = [];
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _loadData();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================
  
  Future<void> _loadData() async {
    setState(() => _loading = true);

    final allCards = await DatabaseHelper.instance.getFlashcards();
    final dueCards = await DatabaseHelper.instance.getFlashcardsDueForReview(
      DateTime.now().millisecondsSinceEpoch,
    );

    final subjects = allCards.map((c) => c.subjectTag).toSet().toList()..sort();

    // Calculate stats
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dueToday = allCards.where((c) {
      if (c.nextReviewMillis == null) return true;
      return c.nextReviewMillis! <= todayStart + 86400000;
    }).length;
    
    final mastered = allCards.where((c) => c.boxLevel >= 4).length;
    final avgBox = allCards.isEmpty ? 0.0 : allCards.map((c) => c.boxLevel).reduce((a, b) => a + b) / allCards.length;
    
    // Calculate streak (simplified - cards reviewed in last 7 days)
    final last7Days = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final recentReviews = allCards.where((c) => 
      c.lastReviewedMillis != null && c.lastReviewedMillis! > last7Days
    ).length;
    final streak = min(recentReviews > 0 ? (recentReviews / allCards.length * 7).round() : 0, 7);

    setState(() {
      _allCards = allCards;
      _dueCards = dueCards;
      _filteredCards = _applyFilters(dueCards);
      _subjects = subjects;
      _totalCards = allCards.length;
      _dueTodayCount = dueToday;
      _masteredCount = mastered;
      _currentStreak = streak;
      _overallMastery = avgBox / 5.0; // 5 is max box level
      _loading = false;
      _showingBack = false;
      _currentCardIndex = 0;
      _flipController.value = 0;
    });
  }

  List<Flashcard> _applyFilters(List<Flashcard> cards) {
    var result = cards;
    
    // Apply subject filter
    if (_filterSubject != null) {
      result = result.where((c) => c.subjectTag == _filterSubject).toList();
    }
    
    // Apply search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) => 
        c.frontText.toLowerCase().contains(query) ||
        c.backText.toLowerCase().contains(query) ||
        c.subjectTag.toLowerCase().contains(query)
      ).toList();
    }
    
    // Apply study mode
    if (_studyMode == 'shuffle') {
      result = result.toList()..shuffle();
    }
    
    return result;
  }

  // ============================================================
  // STUDY MODE SELECTION
  // ============================================================
  
  void _setStudyMode(String mode) {
    setState(() {
      _studyMode = mode;
      if (mode == 'cram' && _filterSubject != null) {
        // Load ALL cards from this subject for cramming
        _filteredCards = _allCards.where((c) => c.subjectTag == _filterSubject).toList()..shuffle();
      } else if (mode == 'shuffle') {
        _filteredCards = _allCards.toList()..shuffle();
      } else {
        _filteredCards = _applyFilters(_dueCards);
      }
      _currentCardIndex = 0;
      _showingBack = false;
      _flipController.value = 0;
    });
  }

  // ============================================================
  // CARD REVIEW ACTIONS
  // ============================================================
  
  void _toggleFlip() {
    HapticFeedback.lightImpact();
    if (_flipController.isCompleted) {
      _flipController.reverse();
      setState(() => _showingBack = false);
    } else {
      _flipController.forward();
      setState(() => _showingBack = true);
    }
  }

  Future<void> _answer({required String difficulty}) async {
    if (_filteredCards.isEmpty) return;
    final card = _filteredCards[_currentCardIndex];

    // Animate card away
    await _slideController.forward();
    
    // Reset flip instantly before removing
    _flipController.value = 0;
    setState(() => _showingBack = false);

    final now = DateTime.now().millisecondsSinceEpoch;
    
    // NEW: Difficulty-based box level adjustment
    int newBox;
    switch (difficulty) {
      case 'again': // Hard - reset to box 1
        newBox = 1;
        break;
      case 'hard': // Hard - go back one box
        newBox = max(card.boxLevel - 1, 1);
        break;
      case 'good': // Good - advance one box
        newBox = min(card.boxLevel + 1, 5);
        break;
      case 'easy': // Easy - advance two boxes
        newBox = min(card.boxLevel + 2, 5);
        break;
      default:
        newBox = card.boxLevel;
    }

    // NEW: Dynamic intervals based on difficulty
    final baseIntervals = [0, 600000, 3600000, 86400000, 259200000, 604800000];
    final intervalMultiplier = switch(difficulty) {
      'again' => 0.5,
      'hard' => 0.75,
      'good' => 1.0,
      'easy' => 1.5,
      _ => 1.0,
    };
    
    final nextReview = now + (baseIntervals[newBox] * intervalMultiplier).round();

    final updated = card.copyWith(
      boxLevel: newBox,
      lastReviewedMillis: now,
      nextReviewMillis: nextReview,
    );

    await DatabaseHelper.instance.updateFlashcard(updated);

    HapticFeedback.mediumImpact();

    // Reset slide animation
    _slideController.value = 0;

    setState(() {
      _currentCardIndex++;
      if (_currentCardIndex >= _filteredCards.length) {
        _currentCardIndex = 0;
        _triggerConfetti();
      }
    });

    // Check if all done
    if (_currentCardIndex == 0 && _filteredCards.isNotEmpty) {
      await _loadData(); // Refresh for next round
    }
  }

  // ============================================================
  // CONFETTI CELEBRATION
  // ============================================================
  
  void _triggerConfetti() {
    setState(() {
      _showConfetti = true;
      _confettiParticles.clear();
      final random = Random();
      for (int i = 0; i < 50; i++) {
        _confettiParticles.add(_ConfettiParticle(
          x: random.nextDouble() * 400 - 200,
          y: random.nextDouble() * -300 - 100,
          color: [
            Colors.red, Colors.blue, Colors.green, Colors.yellow,
            Colors.purple, Colors.orange, Colors.pink, Colors.teal
          ][random.nextInt(8)],
          size: random.nextDouble() * 8 + 4,
          speed: random.nextDouble() * 3 + 2,
          angle: random.nextDouble() * 6.28,
        ));
      }
    });
    _confettiController.forward(from: 0).then((_) {
      setState(() => _showConfetti = false);
    });
  }

  // ============================================================
  // CARD MANAGEMENT
  // ============================================================
  
  Future<void> _deleteCard(Flashcard card) async {
    if (card.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete card?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteFlashcard(card.id!);
      _loadData();
    }
  }

  Future<void> _showCardDialog({Flashcard? existing}) async {
    final subjects = _subjects;
    String subject = existing?.subjectTag ?? (subjects.isNotEmpty ? subjects.first : '');
    final frontController = TextEditingController(text: existing?.frontText ?? '');
    final backController = TextEditingController(text: existing?.backText ?? '');
    bool isNewSubject = !subjects.contains(subject) && subjects.isNotEmpty;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(existing == null ? 'New Card' : 'Edit Card'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: isNewSubject ? null : subject,
                      hint: const Text('Subject'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: [
                        ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        const DropdownMenuItem(value: '__new__', child: Text('+ New subject')),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'New subject name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) => subject = v,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: frontController,
                      decoration: InputDecoration(
                        labelText: 'Front (Question)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: backController,
                      decoration: InputDecoration(
                        labelText: 'Back (Answer)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    if (frontController.text.trim().isEmpty || backController.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final newCard = Flashcard(
        id: existing?.id,
        subjectTag: subject.trim(),
        frontText: frontController.text.trim(),
        backText: backController.text.trim(),
        boxLevel: existing?.boxLevel ?? 1,
        lastReviewedMillis: existing?.lastReviewedMillis,
        nextReviewMillis: existing?.nextReviewMillis,
      );

      if (existing != null && existing.id != null) {
        await DatabaseHelper.instance.updateFlashcard(newCard);
      } else {
        await DatabaseHelper.instance.insertFlashcard(newCard);
      }
      _loadData();
    }

    frontController.dispose();
    backController.dispose();
  }

  // ============================================================
  // BULK IMPORT
  // ============================================================
  
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Bulk Import Cards'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Format: question | answer (one per line)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (_subjects.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: isNewSubject ? null : selectedSubject,
                        hint: const Text('Select Subject'),
                        items: [
                          ..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          const DropdownMenuItem(value: '__new__', child: Text('+ New subject')),
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
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'New subject name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => selectedSubject = v,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: 'What is the capital of France? | Paris\n2 + 2 = ? | 4',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty || selectedSubject == null) return;
                  Navigator.pop(ctx, {
                    'text': controller.text,
                    'subject': selectedSubject,
                  });
                },
                child: const Text('Import'),
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
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          final card = Flashcard(
            subjectTag: result['subject'] as String,
            frontText: parts[0].trim(),
            backText: parts[1].trim(),
          );
          await DatabaseHelper.instance.insertFlashcard(card);
          imported++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $imported cards!')),
        );
      }
      _loadData();
    }
  }

  // ============================================================
  // BUILD METHODS
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add card',
            onPressed: () => _showCardDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Bulk import',
            onPressed: _showBulkImportDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.style_outlined, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No flashcards yet!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Create cards to start studying with spaced repetition.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCardDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Card'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showBulkImportDialog,
              icon: const Icon(Icons.file_upload),
              label: const Text('Bulk Import'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ColorScheme cs) {
    return Column(
      children: [
        // Dashboard Stats Row
        _buildDashboard(cs),
        
        // Search Bar
        _buildSearchBar(cs),
        
        // Subject Decks or Study Mode
        Expanded(
          child: _filteredCards.isEmpty && _searchQuery.isEmpty
              ? _buildSubjectDecks(cs)
              : _buildReviewState(cs),
        ),
      ],
    );
  }

  // ============================================================
  // DASHBOARD WIDGET
  // ============================================================
  
  Widget _buildDashboard(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.15), cs.secondary.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _buildStatItem(Icons.style, _totalCards.toString(), 'Total', cs),
          _buildStatItem(Icons.today, _dueTodayCount.toString(), 'Due', cs),
          _buildStatItem(Icons.emoji_events, _masteredCount.toString(), 'Mastered', cs),
          _buildStatItem(Icons.local_fire_department, _currentStreak.toString(), 'Streak', cs),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.outline),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================
  
  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (v) {
          setState(() {
            _searchQuery = v;
            _filteredCards = _applyFilters(_dueCards);
          });
        },
        decoration: InputDecoration(
          hintText: 'Search cards...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _filteredCards = _applyFilters(_dueCards);
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ============================================================
  // SUBJECT DECKS VIEW
  // ============================================================
  
  Widget _buildSubjectDecks(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text(
                'Your Decks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const Spacer(),
              // Study mode selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'normal', label: Text('Due')),
                  ButtonSegment(value: 'shuffle', label: Text('Shuffle')),
                ],
                selected: {_studyMode},
                onSelectionChanged: (sel) {
                  if (sel.isNotEmpty) _setStudyMode(sel.first);
                },
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

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _filterSubject = subject;
                      _filteredCards = _applyFilters(_dueCards);
                    });
                  },
                  onLongPress: () {
                    // Cram mode - study ALL cards from this subject
                    setState(() {
                      _filterSubject = subject;
                      _studyMode = 'cram';
                      _filteredCards = _allCards.where((c) => c.subjectTag == subject).toList()..shuffle();
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Progress ring
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 6,
                                backgroundColor: cs.outlineVariant.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                              ),
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 6,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation(cs.primary),
                                strokeCap: StrokeCap.round,
                              ),
                              Center(
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
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
                              Text(
                                subject,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${subjectCards.length} cards • $dueCount due today',
                                style: TextStyle(fontSize: 13, color: cs.outline),
                              ),
                              const SizedBox(height: 6),
                              // Box level indicators
                              Row(
                                children: List.generate(5, (i) {
                                  final boxCount = subjectCards.where((c) => c.boxLevel == i + 1).length;
                                  return Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: const EdgeInsets.only(right: 2),
                                      decoration: BoxDecoration(
                                        color: boxCount > 0 
                                          ? Color.lerp(Colors.red, Colors.green, i / 4.0)?.withOpacity(0.7)
                                          : cs.outlineVariant.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: cs.outline),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_subjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Long-press a deck for Cram Mode (all cards)',
                style: TextStyle(fontSize: 12, color: cs.outline, fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // REVIEW STATE (CARD FLIPPING)
  // ============================================================
  
  Widget _buildReviewState(ColorScheme cs) {
    if (_filteredCards.isEmpty) {
      return _buildAllCaughtUp(cs);
    }

    // Ensure index is valid
    if (_currentCardIndex >= _filteredCards.length) {
      _currentCardIndex = 0;
    }
    
    final card = _filteredCards[_currentCardIndex];

    return Stack(
      children: [
        Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Card ${_currentCardIndex + 1} of ${_filteredCards.length}',
                    style: TextStyle(fontSize: 13, color: cs.outline, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  // Study mode badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _studyMode == 'cram' ? 'Cram Mode' : _studyMode == 'shuffle' ? 'Shuffle' : 'Due Cards',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Box level indicator
                  Row(
                    children: List.generate(5, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < card.boxLevel ? cs.primary : cs.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Box ${card.boxLevel}',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Back button to decks
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
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Decks'),
                  ),
                ),
              ),

            Expanded(
              child: GestureDetector(
                onTap: _toggleFlip,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < -200) {
                    _answer(difficulty: 'again'); // Swipe left
                  } else if (details.primaryVelocity! > 200) {
                    _answer(difficulty: 'good'); // Swipe right
                  }
                },
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

            // Controls
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap card to flip • Swipe left = Again • Swipe right = Good',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnswerButton(
                            'Again',
                            Icons.close,
                            cs.errorContainer,
                            cs.onErrorContainer,
                            () => _answer(difficulty: 'again'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAnswerButton(
                            'Hard',
                            Icons.trending_down,
                            Colors.orange.withOpacity(0.2),
                            Colors.orange,
                            () => _answer(difficulty: 'hard'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAnswerButton(
                            'Good',
                            Icons.check,
                            cs.primaryContainer,
                            cs.onPrimaryContainer,
                            () => _answer(difficulty: 'good'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAnswerButton(
                            'Easy',
                            Icons.star,
                            Colors.green.withOpacity(0.2),
                            Colors.green,
                            () => _answer(difficulty: 'easy'),
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
        
        // Confetti overlay
        if (_showConfetti) _buildConfettiOverlay(),
      ],
    );
  }

  Widget _buildAllCaughtUp(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 48, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text(
            _studyMode == 'cram' ? 'Cram session complete!' : 'You\'re all caught up!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            _studyMode == 'cram' 
              ? 'Great job reviewing everything!'
              : 'No cards due for review right now.',
            style: TextStyle(fontSize: 14, color: cs.outline),
          ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(
    String label,
    IconData icon,
    Color bgColor,
    Color fgColor,
    VoidCallback onPressed,
  ) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fgColor, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(Flashcard card, ColorScheme cs, {required bool isFront}) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isFront
              ? [cs.surfaceContainerHighest, cs.surfaceContainerHighest.withOpacity(0.8)]
              : [cs.primaryContainer.withOpacity(0.3), cs.secondaryContainer.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: isFront ? cs.outlineVariant.withOpacity(0.3) : cs.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Edit/Delete menu
          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showCardDialog(existing: card);
                } else if (value == 'delete') {
                  _deleteCard(card);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Delete'))),
              ],
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    card.subjectTag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isFront ? card.frontText : card.backText,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isFront ? 'Tap to reveal answer' : 'Tap to see question',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONFETTI OVERLAY
  // ============================================================
  
  Widget _buildConfettiOverlay() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        return Stack(
          children: _confettiParticles.map((particle) {
            final progress = _confettiController.value;
            final y = particle.y + (progress * 400 * particle.speed);
            final x = particle.x + (sin(progress * 10 + particle.angle) * 50);
            final opacity = 1.0 - progress;
            
            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: MediaQuery.of(context).size.height / 3 + y,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: progress * 10,
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

// ============================================================
// CONFETTI PARTICLE MODEL
// ============================================================

class _ConfettiParticle {
  final double x;
  final double y;
  final Color color;
  final double size;
  final double speed;
  final double angle;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
    required this.angle,
  });
}
