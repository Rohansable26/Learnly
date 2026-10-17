import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/flashcard.dart';
import '../../providers/syllabus_provider.dart';
import '../../services/learning_cache.dart';
import '../learning_studio/widgets/flashcard_deck_view.dart';

/// Flashcards from every lesson the student has studied, newest first.
final reviewDeckProvider = FutureProvider.autoDispose<List<Flashcard>>((
  ref,
) async {
  final active = ref.watch(syllabusProvider).activeSyllabus;
  final lessons = await learningCache.loadAllLessons(topic: active?.topic);
  final seen = <String>{};
  return [
    for (final lesson in lessons)
      for (final card in lesson.flashcards)
        if (seen.add(card.question)) card,
  ];
});

class RecallCenterScreen extends ConsumerWidget {
  const RecallCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(syllabusProvider).activeSyllabus;
    final deck = ref.watch(reviewDeckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: const IconBadge(
                  icon: Icons.psychology_outlined,
                  tone: Tone.tertiary,
                ),
                title: const Text('Spaced repetition'),
                subtitle: Text(
                  active != null
                      ? 'Cards from ${active.topic}'
                      : 'Cards from lessons you studied',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: InfoTag(
                  label: '${deck.asData?.value.length ?? 0} cards',
                  tone: Tone.success,
                ),
              ),
            ),
          ),
          Expanded(
            child: deck.when(
              loading: () => const EmptyState(
                loading: true,
                icon: Icons.style_outlined,
                title: 'Loading your cards',
              ),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Couldn\'t load cards',
                message: '$e',
              ),
              data: (cards) => cards.isEmpty
                  ? const EmptyState(
                      icon: Icons.style_outlined,
                      title: 'No cards yet',
                      message:
                          'Study a lesson and its flashcards will appear here for review.',
                    )
                  : FlashcardDeckView(
                      flashcards: cards,
                      onAllMastered: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Deck complete.')),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
