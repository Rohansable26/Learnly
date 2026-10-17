import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/flashcard.dart';

class FlashcardDeckView extends StatefulWidget {
  final List<Flashcard> flashcards;
  final VoidCallback onAllMastered;

  const FlashcardDeckView({
    super.key,
    required this.flashcards,
    required this.onAllMastered,
  });

  @override
  State<FlashcardDeckView> createState() => _FlashcardDeckViewState();
}

class _FlashcardDeckViewState extends State<FlashcardDeckView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _flipAnimation;

  int _currentIndex = 0;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _nextCard(bool markMastered) {
    if (widget.flashcards.isEmpty) return;

    if (markMastered) {
      setState(() {
        widget.flashcards[_currentIndex].isMastered = true;
      });
    }

    if (_currentIndex < widget.flashcards.length - 1) {
      if (!_isFront) {
        _animController.reverse();
        _isFront = true;
      }
      setState(() {
        _currentIndex++;
      });
    } else {
      final allMastered = widget.flashcards.every((fc) => fc.isMastered);
      if (allMastered) {
        widget.onAllMastered();
      }
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      if (!_isFront) {
        _animController.reverse();
        _isFront = true;
      }
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return const EmptyState(
        icon: Icons.style_outlined,
        title: 'No flashcards yet',
        message: 'Flashcards for this topic will appear here.',
      );
    }

    final currentCard = widget.flashcards[_currentIndex];
    final masteredCount = widget.flashcards.where((fc) => fc.isMastered).length;
    final progress = masteredCount / widget.flashcards.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Card ${_currentIndex + 1} of ${widget.flashcards.length}',
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            InfoTag(
              label: '$masteredCount/${widget.flashcards.length} mastered',
              tone: Tone.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, color: context.status.success),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * math.pi;
              final isUnder = angle > (math.pi / 2);

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isUnder
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildCardBack(currentCard),
                      )
                    : _buildCardFront(currentCard),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            if (_currentIndex > 0) ...[
              IconButton.outlined(
                onPressed: _prevCard,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Previous card',
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _nextCard(false),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Review later'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _nextCard(true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Got it'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardShell({
    required Widget child,
    required Color color,
    Color? borderColor,
  }) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor ?? context.colors.outlineVariant),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 280),
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  Widget _flipHint(String text, Color color) {
    return Row(
      children: [
        Icon(Icons.touch_app_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: context.text.labelMedium?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront(Flashcard card) {
    return _cardShell(
      color: context.colors.surfaceContainerLow,
      borderColor: card.isMastered ? context.status.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: InfoTag(label: card.keyConcept, tone: Tone.primary),
              ),
              const Spacer(),
              if (card.isMastered)
                Icon(Icons.verified, color: context.status.success, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Text(card.question, style: context.text.titleLarge),
          const SizedBox(height: 32),
          _flipHint('Tap to reveal answer', context.colors.outline),
        ],
      ),
    );
  }

  Widget _buildCardBack(Flashcard card) {
    final fg = context.colors.onSecondaryContainer;
    return _cardShell(
      color: context.colors.secondaryContainer,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Answer', style: context.text.labelLarge?.copyWith(color: fg)),
          const SizedBox(height: 12),
          Text(card.answer, style: context.text.bodyLarge?.copyWith(color: fg)),
          if (card.codeSnippet != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                card.codeSnippet!,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  height: 1.5,
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _flipHint('Tap to flip back', fg.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}
