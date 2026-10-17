import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../providers/history_provider.dart';
import '../../services/learning_cache.dart';
import '../../providers/syllabus_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(syllabusProvider).activeSyllabus;
    final history = ref.watch(historyProvider);

    final Map<String, QuizAttempt> bestByModule = active == null
        ? {}
        : history.bestAttemptsFor(active.topic);
    final scores = bestByModule.values
        .map((a) => a.scorePercentage)
        .toList(growable: false);
    final readiness = active == null
        ? 0.0
        : _readiness(active.overallProgress, scores);
    final hasAnyData =
        history.quizAttempts.isNotEmpty || history.activeDays.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: !history.isLoaded
          ? const SizedBox.shrink()
          : !hasAnyData && active == null
          ? const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No progress yet',
              message:
                  'Study a lesson or take a module quiz and your progress will appear here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (active != null)
                  Card.filled(
                    color: context.colors.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Readiness',
                                  style: context.text.labelLarge?.copyWith(
                                    color: context.colors.onTertiaryContainer,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.workspace_premium_outlined,
                                color: context.colors.onTertiaryContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            active.topic,
                            style: context.text.headlineSmall?.copyWith(
                              color: context.colors.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on completed modules and quiz scores.',
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.onTertiaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          LabeledProgress(
                            label: 'Readiness',
                            value: readiness,
                            color: context.colors.tertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (active != null) const SizedBox(height: 16),

                StatGrid(
                  children: [
                    StatTile(
                      label: 'Streak',
                      value: '${history.streakDays} days',
                      caption: 'Consecutive active days',
                      icon: Icons.local_fire_department_outlined,
                      tone: Tone.warning,
                    ),
                    StatTile(
                      label: 'Quiz average',
                      value: history.quizzesTaken == 0
                          ? '—'
                          : '${history.averageQuizScore.toStringAsFixed(0)}%',
                      caption:
                          '${history.quizzesPassed} of ${history.quizzesTaken} passed',
                      icon: Icons.check_circle_outline,
                      tone: Tone.success,
                    ),
                    StatTile(
                      label: 'Questions asked',
                      value: '${history.answers.length}',
                      caption: 'Saved on this device',
                      icon: Icons.forum_outlined,
                      tone: Tone.secondary,
                    ),
                    StatTile(
                      label: 'Active days',
                      value: '${history.activeDays.length}',
                      caption: 'Total study days',
                      icon: Icons.event_available_outlined,
                      tone: Tone.tertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (active != null && active.modules.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Modules',
                    subtitle: 'Best quiz score per module',
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final (i, m) in active.modules.indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        m.title,
                                        style: context.text.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InfoTag(
                                      label: m.isPassed
                                          ? 'Passed'
                                          : (bestByModule[m.id] == null
                                                ? 'Not attempted'
                                                : 'In progress'),
                                      tone: m.isPassed
                                          ? Tone.success
                                          : Tone.neutral,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value:
                                            (bestByModule[m.id]
                                                    ?.scorePercentage ??
                                                0) /
                                            100,
                                        color: _scoreColor(
                                          context,
                                          (bestByModule[m.id]
                                                  ?.scorePercentage ??
                                              0) /
                                              100,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      bestByModule[m.id] == null
                                          ? '—'
                                          : '${bestByModule[m.id]!.scorePercentage.toStringAsFixed(0)}%',
                                      style: context.text.labelLarge,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Blends course completion (60%) with average best module score (40%).
  static double _readiness(double completion, List<double> scores) {
    if (scores.isEmpty) return completion * 0.6;
    final avg = scores.reduce((a, b) => a + b) / scores.length / 100;
    return (completion * 0.6 + avg * 0.4).clamp(0.0, 1.0);
  }

  Color _scoreColor(BuildContext context, double score) {
    if (score >= 0.8) return context.status.success;
    if (score >= 0.7) return context.colors.primary;
    return context.status.warning;
  }
}
