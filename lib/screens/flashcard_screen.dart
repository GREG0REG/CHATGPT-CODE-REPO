import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/flashcard.dart';

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

  List<Flashcard> _cards = [];
  List<String> _subjects = [];
  String? _filterSubject;
  bool _loading = true;
  bool _showingBack = false;

  // Slide animation for card exit
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final allCards = await DatabaseHelper.instance.getFlashcards();
    final dueCards = await DatabaseHelper.instance.getFlashcardsDueForReview();

    final subjects = allCards.map((c) => c.subjectTag).toSet().toList()..sort();

    final filtered = _filterSubject == null
        ? dueCards
        : dueCards.where((c) => c.subjectTag == _filterSubject).toList();

    if (!mounted) return;
    setState(() {
      _cards = filtered;
      _subjects = subjects;
      _loading = false;
      _showingBack = false;
      _flipController.value = 0;
    });
  }

  void _setFilter(String? subject) {
    if (_filterSubject == subject) return;
    setState(() => _filterSubject = subject);
    _loadData();
  }

  void _toggleFlip() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
      _showingBack = false;
    } else {
      _flipController.forward();
      _showingBack = true;
    }
  }

  Future<void> _answer({required bool gotIt}) async {
    if (_cards.isEmpty) return;
    final card = _cards.first;

    // Reset flip instantly before removing
    _flipController.value = 0;
    _showingBack = false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final newBox = gotIt ? (card.boxLevel + 1).clamp(1, 5) : 1;

    // Intervals in milliseconds: 1h, 1d, 3d, 7d, 14d
    const intervals = [0, 3600000, 86400000, 259200000, 604800000, 1209600000];
    final nextReview = now + intervals[newBox];

    final updated = card.copyWith(
      boxLevel: newBox,
      lastReviewedMillis: now,
      nextReviewMillis: nextReview,
    );

    await DatabaseHelper.instance.updateFlashcard(updated);

    HapticFeedback.lightImpact();

    setState(() => _cards.removeAt(0));

    if (_cards.isEmpty) {
      await _loadData(); // Check if more became due
    }
  }

  void _onGotIt() => _answer(gotIt: true);
  void _onAgain() => _answer(gotIt: false);

  Future<void> _deleteCard(Flashcard card) async {
    if (card.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              title: Text(existing == null ? 'New Card' : 'Edit Card'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: isNewSubject ? null : subject,
                      hint: const Text('Subject'),
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
                        decoration: const InputDecoration(labelText: 'New subject name', border: OutlineInputBorder()),
                        onChanged: (v) => subject = v,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: frontController,
                      decoration: const InputDecoration(labelText: 'Front (Question)', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: backController,
                      decoration: const InputDecoration(labelText: 'Back (Answer)', border: OutlineInputBorder()),
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
        ],
        bottom: _subjects.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _filterSubject == null,
                          onSelected: (_) => _setFilter(null),
                        ),
                        ..._subjects.map((s) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(s),
                                selected: _filterSubject == s,
                                onSelected: (_) => _setFilter(s),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _buildEmptyState(cs)
              : _buildReviewState(cs),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              _filterSubject == null ? 'You\'re all caught up!' : 'No due cards for this subject.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Great job reviewing today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCardDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Card'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewState(ColorScheme cs) {
    final card = _cards.first;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _toggleFlip,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -250) {
                _onAgain(); // Swipe left
              } else if (details.primaryVelocity! > 250) {
                _onGotIt(); // Swipe right
              }
            },
            child: AnimatedBuilder(
              animation: _flipController,
              builder: (context, child) {
                final angle = _flipController.value * 3.1415926535897932;
                final isFrontVisible = angle < 1.5708;

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
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
                  'Tap card to flip • Swipe to answer',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _onAgain,
                        icon: const Icon(Icons.close),
                        label: const Text('Again'),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.errorContainer,
                          foregroundColor: cs.onErrorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _onGotIt,
                        icon: const Icon(Icons.check),
                        label: const Text('Got it'),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFace(Flashcard card, ColorScheme cs, {required bool isFront}) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
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
                Chip(
                  label: Text(card.subjectTag),
                  backgroundColor: cs.primaryContainer,
                  side: BorderSide.none,
                ),
                const SizedBox(height: 32),
                Text(
                  isFront ? card.frontText : card.backText,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        i < card.boxLevel ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: cs.primary,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  'Box ${card.boxLevel}',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
