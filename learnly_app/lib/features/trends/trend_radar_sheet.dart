import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../providers/syllabus_provider.dart';

class TrendRadarSheet extends ConsumerWidget {
  const TrendRadarSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const TrendRadarSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syllabusProvider);
    final active = state.activeSyllabus;
    final trends = active?.latestTrendsIdentified ?? const <String>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trend radar', style: context.text.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        active != null
                            ? 'New developments in ${active.topic}'
                            : 'No active topic',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: state.isSyncingTrends
                      ? null
                      : () => ref
                            .read(syllabusProvider.notifier)
                            .syncLiveTrends(),
                  icon: state.isSyncingTrends
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(state.isSyncingTrends ? 'Syncing…' : 'Sync'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (state.lastTrendSyncResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.status.successContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: context.status.onSuccessContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.lastTrendSyncResult!.updateMessage,
                        style: context.text.bodySmall?.copyWith(
                          color: context.status.onSuccessContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: trends.isEmpty
                  ? const EmptyState(
                      icon: Icons.radar,
                      title: 'Nothing here yet',
                      message:
                          'Tap Sync to check the web for new developments.',
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: trends.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: const IconBadge(
                            icon: Icons.bolt,
                            tone: Tone.warning,
                            size: 36,
                          ),
                          title: Text(trends[idx]),
                          subtitle: const Text('Found in recent web sources'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
