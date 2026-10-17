import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/syllabus.dart';
import '../../providers/syllabus_provider.dart';
import '../learning_studio/learning_studio_screen.dart';
import '../quiz/quiz_screen.dart';
import '../trends/trend_radar_sheet.dart';

class SyllabusScreen extends ConsumerWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syllabusProvider);
    final active = state.activeSyllabus;

    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Roadmap')),
        body: const EmptyState(
          icon: Icons.route_outlined,
          title: 'No roadmap yet',
          message:
              'Create a syllabus from the Home tab to see your learning roadmap here.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(active.topic, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Trend radar',
            icon: Badge(
              isLabelVisible: active.latestTrendsIdentified.isNotEmpty,
              child: const Icon(Icons.radar),
            ),
            onPressed: () => TrendRadarSheet.show(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Overview
          Card.filled(
            color: context.colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoTag(
                        label: active.userExperienceLevel.label,
                        tone: Tone.secondary,
                      ),
                      InfoTag(
                        label: active.primaryLearningStyle.label,
                        tone: Tone.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    active.topic,
                    style: context.text.headlineSmall?.copyWith(
                      color: context.colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${active.modules.length} modules',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledProgress(
                    label: 'Course progress',
                    value: active.overallProgress,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Live-sync banner
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const IconBadge(
                icon: Icons.bolt,
                tone: Tone.warning,
                size: 40,
              ),
              title: const Text('Live updates on'),
              subtitle: const Text(
                'Updated as new papers and releases appear.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => TrendRadarSheet.show(context),
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Modules'),
          for (var i = 0; i < active.modules.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleCard(
                syllabus: active,
                module: active.modules[i],
                index: i,
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final Syllabus syllabus;
  final Module module;
  final int index;

  const _ModuleCard({
    required this.syllabus,
    required this.module,
    required this.index,
  });

  static const _compactButton = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    visualDensity: VisualDensity.compact,
  );

  void _openQuiz(BuildContext context) {
    QuizScreen.navigate(
      context,
      syllabusId: syllabus.id,
      topic: syllabus.topic,
      moduleId: module.id,
      moduleTitle: module.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = module.isUnlocked;
    final isPassed = module.isPassed;
    final doneCount = module.subtopics.where((s) => s.isCompleted).length;

    final Tone tone = isPassed
        ? Tone.success
        : (isUnlocked ? Tone.primary : Tone.neutral);
    final IconData statusIcon = isPassed
        ? Icons.check
        : (isUnlocked ? Icons.play_arrow : Icons.lock_outline);
    final muted = context.colors.onSurface.withValues(alpha: 0.38);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnlocked && !isPassed
              ? context.colors.primary
              : context.colors.outlineVariant,
          width: isUnlocked && !isPassed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: statusIcon, tone: tone, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Module ${index + 1} · $doneCount/${module.subtopics.length} done',
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        module.title,
                        style: context.text.titleMedium?.copyWith(
                          color: isUnlocked ? null : muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        module.summary,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ...module.subtopics.map((sub) {
            return ListTile(
              enabled: isUnlocked,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(
                sub.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: sub.isCompleted ? context.status.success : null,
              ),
              title: Text(sub.title),
              subtitle: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${sub.estimatedMinutes} min · ${sub.resources.length} resources',
                  ),
                  if (sub.isTrendUpdated)
                    const InfoTag(label: 'New', tone: Tone.warning),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => LearningStudioScreen.navigate(
                context,
                syllabusId: syllabus.id,
                topic: syllabus.topic,
                moduleId: module.id,
                moduleTitle: module.title,
                subtopic: sub,
              ),
            );
          }),
          Container(
            color: context.colors.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Icon(
                  isPassed
                      ? Icons.verified
                      : (isUnlocked ? Icons.quiz_outlined : Icons.lock_outline),
                  color: isPassed
                      ? context.status.success
                      : context.colors.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPassed
                        ? 'Quiz passed'
                        : (isUnlocked
                              ? 'Pass the quiz to unlock the next module'
                              : 'Locked'),
                    style: context.text.bodySmall?.copyWith(
                      color: isPassed
                          ? context.status.success
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isUnlocked && isPassed)
                  OutlinedButton(
                    onPressed: () => _openQuiz(context),
                    style: _compactButton,
                    child: const Text('Retake'),
                  )
                else if (isUnlocked)
                  FilledButton.tonal(
                    onPressed: () => _openQuiz(context),
                    style: _compactButton,
                    child: const Text('Take quiz'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
