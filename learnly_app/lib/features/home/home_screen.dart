import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/syllabus.dart';
import '../../providers/history_provider.dart';
import '../../providers/syllabus_provider.dart';
import '../learning_studio/learning_studio_screen.dart';
import '../main_scaffold.dart';
import '../onboarding/new_topic_sheet.dart';
import '../profile/student_profile_sheet.dart';
import '../quiz/quiz_screen.dart';
import '../syllabus/syllabus_screen.dart';
import '../trends/trend_radar_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmit(String query) {
    final cleaned = query.trim();
    if (cleaned.isNotEmpty) {
      NewTopicSheet.show(context, initialTopic: cleaned);
    }
  }

  void _openStudio(Syllabus? syllabus, {bool firstSubtopic = false}) {
    if (syllabus == null || syllabus.modules.isEmpty) {
      ref.read(navigationIndexProvider.notifier).setIndex(1);
      return;
    }
    final module = firstSubtopic
        ? syllabus.modules.first
        : syllabus.modules.firstWhere(
            (m) => !m.isPassed,
            orElse: () => syllabus.modules.first,
          );
    if (module.subtopics.isEmpty) {
      ref.read(navigationIndexProvider.notifier).setIndex(1);
      return;
    }
    final subtopic = firstSubtopic
        ? module.subtopics.first
        : module.subtopics.firstWhere(
            (s) => !s.isCompleted,
            orElse: () => module.subtopics.first,
          );
    LearningStudioScreen.navigate(
      context,
      syllabusId: syllabus.id,
      topic: syllabus.topic,
      moduleId: module.id,
      moduleTitle: module.title,
      subtopic: subtopic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syllabusProvider);
    final active = state.activeSyllabus;
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Learnly AI',
                style: context.text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '${history.streakDays}-day learning streak',
            icon: Badge(
              isLabelVisible: history.streakDays > 0,
              label: Text('${history.streakDays}'),
              backgroundColor: context.status.warning,
              textColor: context.status.onWarning,
              child: Icon(
                Icons.local_fire_department_outlined,
                color: context.status.warning,
              ),
            ),
            onPressed: () => StudentProfileSheet.show(context),
          ),
          IconButton(
            tooltip: 'Trend radar',
            icon: Badge(
              isLabelVisible:
                  active?.latestTrendsIdentified.isNotEmpty ?? false,
              child: const Icon(Icons.radar),
            ),
            onPressed: () => TrendRadarSheet.show(context),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => StudentProfileSheet.show(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => NewTopicSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New syllabus'),
      ),
      body: state.isLoading
          ? const EmptyState(
              loading: true,
              icon: Icons.auto_awesome,
              title: 'Building your curriculum',
              message:
                  'Gathering recent papers, docs and videos, then structuring them into modules.',
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(syllabusProvider.notifier).syncLiveTrends(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  SearchBar(
                    controller: _searchController,
                    hintText: 'What do you want to learn?',
                    leading: const Icon(Icons.search),
                    trailing: [
                      IconButton(
                        tooltip: 'Generate syllabus',
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () =>
                            _onSearchSubmit(_searchController.text),
                      ),
                    ],
                    onSubmitted: _onSearchSubmit,
                  ),
                  const SizedBox(height: 12),
                  if (state.enrolledSyllabi.isNotEmpty) ...[
                    _buildRecentTopicChips(state.enrolledSyllabi),
                    const SizedBox(height: 24),
                  ],

                  if (active != null) ...[
                    SectionHeader(
                      title: 'Continue learning',
                      action: TextButton(
                        onPressed: () => ref
                            .read(navigationIndexProvider.notifier)
                            .setIndex(1),
                        child: const Text('View roadmap'),
                      ),
                    ),
                    _buildActiveMissionCard(active),
                    const SizedBox(height: 24),
                  ],

                  const SectionHeader(title: 'This week'),
                  _buildWeeklyProgressCard(history),
                  const SizedBox(height: 24),

                  const SectionHeader(title: 'Study modes'),
                  _buildModeGrid(active),
                  const SizedBox(height: 24),

                  SectionHeader(
                    title: 'What\'s new in your field',
                    action: TextButton(
                      onPressed: () => TrendRadarSheet.show(context),
                      child: const Text('See all'),
                    ),
                  ),
                  _buildTrendFeed(active),

                  if (state.enrolledSyllabi.length > 1) ...[
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Your roadmaps (${state.enrolledSyllabi.length})',
                    ),
                    _buildEnrolledRoadmapsList(state.enrolledSyllabi, active),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRecentTopicChips(List<Syllabus> roadmaps) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roadmaps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return ActionChip(
            avatar: const Icon(Icons.history, size: 18),
            label: Text(roadmaps[i].topic),
            onPressed: () => ref
                .read(syllabusProvider.notifier)
                .setActiveSyllabus(roadmaps[i]),
          );
        },
      ),
    );
  }

  Widget _buildActiveMissionCard(Syllabus syllabus) {
    final progress = syllabus.overallProgress;
    final activeModule = syllabus.modules.isNotEmpty
        ? syllabus.modules.firstWhere(
            (m) => !m.isPassed,
            orElse: () => syllabus.modules.first,
          )
        : null;
    final activeSubtopic =
        activeModule != null && activeModule.subtopics.isNotEmpty
        ? activeModule.subtopics.firstWhere(
            (s) => !s.isCompleted,
            orElse: () => activeModule.subtopics.first,
          )
        : null;

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
                  icon: Icons.auto_mode,
                  tone: Tone.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              syllabus.topic,
              style: context.text.headlineSmall?.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              syllabus.industryStandardsSummary,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onPrimaryContainer.withValues(alpha: 0.8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (activeModule != null && activeSubtopic != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const IconBadge(icon: Icons.school_outlined, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next up · ${activeModule.title}',
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeSubtopic.title,
                            style: context.text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            LabeledProgress(label: 'Course progress', value: progress),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (activeSubtopic != null) {
                        _openStudio(syllabus);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SyllabusScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Continue'),
                  ),
                ),
                if (activeModule != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => QuizScreen.navigate(
                        context,
                        syllabusId: syllabus.id,
                        topic: syllabus.topic,
                        moduleId: activeModule.id,
                        moduleTitle: activeModule.title,
                      ),
                      icon: const Icon(Icons.quiz_outlined, size: 18),
                      label: const Text('Quiz'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressCard(HistoryState history) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final completed = history.currentWeekActivity;
    final doneCount = completed.where((d) => d).length;
    final todayIndex = DateTime.now().weekday - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const IconBadge(icon: Icons.bolt, tone: Tone.warning, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Study days', style: context.text.titleMedium),
                ),
                Text(
                  '$doneCount / 7 days',
                  style: context.text.labelLarge?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: doneCount / 7),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final isDone = completed[i];
                final isToday = i == todayIndex;
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? context.colors.primary
                            : context.colors.surfaceContainerHighest,
                        border: isToday
                            ? Border.all(
                                color: context.colors.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: isDone
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: context.colors.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i],
                      style: context.text.labelMedium?.copyWith(
                        color: isToday
                            ? context.colors.primary
                            : context.colors.onSurfaceVariant,
                        fontWeight: isToday ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeGrid(Syllabus? syllabus) {
    final modes = [
      (
        'AI tutor',
        'Ask questions and get step-by-step answers',
        Icons.forum_outlined,
        Tone.primary,
        () => _openStudio(syllabus, firstSubtopic: true),
      ),
      (
        'Flashcards',
        'Review key concepts with spaced repetition',
        Icons.style_outlined,
        Tone.tertiary,
        () => ref.read(navigationIndexProvider.notifier).setIndex(2),
      ),
      (
        'Videos',
        'Curated YouTube lessons for each topic',
        Icons.play_circle_outline,
        Tone.error,
        () => _openStudio(syllabus, firstSubtopic: true),
      ),
      (
        'Papers & docs',
        'Research papers and technical docs',
        Icons.menu_book_outlined,
        Tone.secondary,
        () => _openStudio(syllabus, firstSubtopic: true),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 148,
      ),
      itemCount: modes.length,
      itemBuilder: (context, i) {
        final (title, desc, icon, tone, action) = modes[i];
        return Card(
          child: InkWell(
            onTap: action,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: icon, tone: tone, size: 40),
                  const Spacer(),
                  Text(title, style: context.text.titleSmall, maxLines: 1),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendFeed(Syllabus? active) {
    final trends = active?.latestTrendsIdentified ?? const <String>[];
    if (trends.isEmpty) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const IconBadge(icon: Icons.radar, size: 36),
          title: const Text('No developments yet'),
          subtitle: const Text(
            'Sync the trend radar to check the web for updates.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => TrendRadarSheet.show(context),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < trends.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: InfoTag(label: 'Trend', tone: Tone.primary),
              ),
              subtitle: Text(
                trends[i],
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => TrendRadarSheet.show(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnrolledRoadmapsList(List<Syllabus> roadmaps, Syllabus? active) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < roadmaps.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            Builder(
              builder: (context) {
                final s = roadmaps[i];
                final isCurrent = s.id == active?.id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: s.overallProgress,
                      strokeWidth: 4,
                      backgroundColor: context.colors.surfaceContainerHighest,
                    ),
                  ),
                  title: Text(
                    s.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${s.modules.length} modules · ${(s.overallProgress * 100).toStringAsFixed(0)}% complete',
                  ),
                  trailing: isCurrent
                      ? const InfoTag(label: 'Active', tone: Tone.primary)
                      : TextButton(
                          onPressed: () => ref
                              .read(syllabusProvider.notifier)
                              .setActiveSyllabus(s),
                          child: const Text('Switch'),
                        ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
