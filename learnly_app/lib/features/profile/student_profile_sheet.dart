import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../providers/history_provider.dart';
import '../../providers/syllabus_provider.dart';

class StudentProfileSheet extends ConsumerWidget {
  const StudentProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const StudentProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syllabusProvider);
    final history = ref.watch(historyProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: context.colors.primaryContainer,
                foregroundColor: context.colors.onPrimaryContainer,
                child: const Icon(Icons.person, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your progress', style: context.text.titleLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        InfoTag(
                          label: '${state.enrolledSyllabi.length} roadmaps',
                          tone: Tone.primary,
                        ),
                        InfoTag(
                          label: '${history.answers.length} questions',
                          icon: Icons.forum_outlined,
                          tone: Tone.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          StatGrid(
            children: [
              StatTile(
                label: 'Streak',
                value: '${history.streakDays} days',
                icon: Icons.local_fire_department_outlined,
                tone: Tone.warning,
              ),
              StatTile(
                label: 'Active days',
                value: '${history.activeDays.length}',
                icon: Icons.event_available_outlined,
                tone: Tone.secondary,
              ),
              StatTile(
                label: 'Quizzes passed',
                value: '${history.quizzesPassed}/${history.quizzesTaken}',
                icon: Icons.verified_outlined,
                tone: Tone.success,
              ),
              StatTile(
                label: 'Average score',
                value: history.quizzesTaken == 0
                    ? '—'
                    : '${history.averageQuizScore.toStringAsFixed(0)}%',
                icon: Icons.insights,
                tone: Tone.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Modules passed'),
          Builder(
            builder: (context) {
              final passed = [
                for (final syl in state.enrolledSyllabi)
                  for (final m in syl.modules)
                    if (m.isPassed) '${m.title} · ${syl.topic}',
              ];
              if (passed.isEmpty) {
                return Text(
                  'Pass a module quiz to see it here.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: passed
                    .map(
                      (label) => Chip(
                        avatar: Icon(
                          Icons.check,
                          size: 18,
                          color: context.status.success,
                        ),
                        label: Text(label),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Your roadmaps'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < state.enrolledSyllabi.length; i++) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  Builder(
                    builder: (context) {
                      final syl = state.enrolledSyllabi[i];
                      final progress = syl.overallProgress;
                      return ListTile(
                        title: Text(
                          syl.topic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${syl.modules.length} modules · ${(progress * 100).toStringAsFixed(0)}% complete',
                        ),
                        trailing: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4,
                            backgroundColor:
                                context.colors.surfaceContainerHighest,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: Column(
              children: [
                const AppLogo(size: 40),
                const SizedBox(height: 8),
                Text('Learnly', style: context.text.titleSmall),
                Text(
                  'AI-powered learning roadmaps',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
