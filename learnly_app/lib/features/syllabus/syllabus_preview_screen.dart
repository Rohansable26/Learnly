import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/syllabus.dart';
import '../../providers/syllabus_provider.dart';

/// Shows a freshly generated syllabus before the student commits to it.
/// Accepting enrolls it; regenerating asks the AI again; discarding drops it.
class SyllabusPreviewScreen extends ConsumerWidget {
  const SyllabusPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syllabusProvider);
    final syllabus = state.pendingSyllabus;

    if (syllabus == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const EmptyState(
          icon: Icons.route_outlined,
          title: 'Nothing to preview',
          message: 'Generate a syllabus from the Home tab first.',
        ),
      );
    }

    final notifier = ref.read(syllabusProvider.notifier);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Leaving without accepting discards the draft.
        if (didPop) notifier.discardPendingSyllabus();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Review your roadmap')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _Overview(syllabus: syllabus),
            const SizedBox(height: 16),
            if (syllabus.prerequisites.isNotEmpty) ...[
              _BulletCard(
                title: 'Before you start',
                items: syllabus.prerequisites,
                icon: Icons.checklist_outlined,
              ),
              const SizedBox(height: 12),
            ],
            if (syllabus.learningOutcomes.isNotEmpty) ...[
              _BulletCard(
                title: 'You will be able to',
                items: syllabus.learningOutcomes,
                icon: Icons.emoji_objects_outlined,
              ),
              const SizedBox(height: 12),
            ],
            if (syllabus.latestTrendsIdentified.isNotEmpty) ...[
              _BulletCard(
                title: 'Current developments covered',
                items: syllabus.latestTrendsIdentified,
                icon: Icons.bolt,
                tone: Tone.warning,
              ),
              const SizedBox(height: 12),
            ],
            const SectionHeader(title: 'Modules'),
            for (final (i, m) in syllabus.modules.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModulePreview(index: i, module: m),
              ),
            const SizedBox(height: 8),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: context.colors.error),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Discard',
                  onPressed: state.isLoading
                      ? null
                      : () {
                          notifier.discardPendingSyllabus();
                          Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () => notifier.regeneratePending(),
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            await notifier.acceptPendingSyllabus();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Start roadmap'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final Syllabus syllabus;

  const _Overview({required this.syllabus});

  @override
  Widget build(BuildContext context) {
    final hours = syllabus.totalEstimatedMinutes / 60;
    return Card.filled(
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
                  label: syllabus.userExperienceLevel.label,
                  tone: Tone.secondary,
                ),
                InfoTag(
                  label: syllabus.primaryLearningStyle.label,
                  tone: Tone.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              syllabus.topic,
              style: context.text.headlineSmall?.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              syllabus.industryStandardsSummary,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onPrimaryContainer.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${syllabus.modules.length} modules · '
              '${syllabus.totalSubtopics} subtopics · '
              '~${hours.toStringAsFixed(hours < 10 ? 1 : 0)} h',
              style: context.text.labelLarge?.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Tone tone;

  const _BulletCard({
    required this.title,
    required this.items,
    required this.icon,
    this.tone = Tone.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, tone: tone, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: context.text.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: context.text.bodyMedium),
                    Expanded(
                      child: Text(item, style: context.text.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModulePreview extends StatelessWidget {
  final int index;
  final Module module;

  const _ModulePreview({required this.index, required this.module});

  @override
  Widget build(BuildContext context) {
    final minutes = module.subtopics.fold<int>(
      0,
      (sum, s) => sum + s.estimatedMinutes,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: IconBadge(
          icon: Icons.layers_outlined,
          tone: Tone.primary,
          size: 36,
        ),
        title: Text(module.title, style: context.text.titleSmall),
        subtitle: Text(
          'Module ${index + 1} · ${module.subtopics.length} subtopics · $minutes min',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        children: [
          Text(
            module.summary,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (module.learningObjectives.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final objective in module.learningObjectives)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('✓  $objective', style: context.text.bodySmall),
              ),
          ],
          const SizedBox(height: 12),
          for (final sub in module.subtopics)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radio_button_unchecked, size: 20),
              title: Text(sub.title),
              subtitle: Text(sub.description),
              trailing: Text(
                '${sub.estimatedMinutes} min',
                style: context.text.labelMedium,
              ),
            ),
        ],
      ),
    );
  }
}
