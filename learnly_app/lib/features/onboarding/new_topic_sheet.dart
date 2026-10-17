import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/syllabus.dart';
import '../../providers/syllabus_provider.dart';

class NewTopicSheet extends ConsumerStatefulWidget {
  final String? initialTopic;

  const NewTopicSheet({super.key, this.initialTopic});

  static Future<void> show(BuildContext context, {String? initialTopic}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => NewTopicSheet(initialTopic: initialTopic),
    );
  }

  @override
  ConsumerState<NewTopicSheet> createState() => _NewTopicSheetState();
}

class _NewTopicSheetState extends ConsumerState<NewTopicSheet> {
  late final TextEditingController _topicController;
  final _goalsController = TextEditingController();

  ExperienceLevel _selectedLevel = ExperienceLevel.beginner;
  LearningStyle _selectedStyle = LearningStyle.balancedHybrid;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
  }

  @override
  void dispose() {
    _topicController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  void _submit() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a topic to continue')),
      );
      return;
    }

    Navigator.of(context).pop();

    await ref
        .read(syllabusProvider.notifier)
        .createNewSyllabus(
          topic: topic,
          level: _selectedLevel,
          style: _selectedStyle,
          goals: _goalsController.text.trim().isNotEmpty
              ? _goalsController.text.trim()
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = ref
        .watch(syllabusProvider)
        .enrolledSyllabi
        .map((s) => s.topic)
        .toSet()
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Start a new topic', style: context.text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'We\'ll build a roadmap from current docs, papers and videos.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _topicController,
              autofocus: widget.initialTopic == null,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'e.g. Building agentic workflows',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            if (enrolled.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: enrolled
                    .map(
                      (t) => ActionChip(
                        label: Text(t),
                        onPressed: () =>
                            setState(() => _topicController.text = t),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),

            Text('Experience level', style: context.text.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ExperienceLevel>(
                showSelectedIcon: false,
                segments: ExperienceLevel.values
                    .map(
                      (level) => ButtonSegment(
                        value: level,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(level.label),
                        ),
                      ),
                    )
                    .toList(),
                selected: {_selectedLevel},
                onSelectionChanged: (s) =>
                    setState(() => _selectedLevel = s.first),
              ),
            ),
            const SizedBox(height: 24),

            Text('Preferred format', style: context.text.titleSmall),
            const SizedBox(height: 8),
            RadioGroup<LearningStyle>(
              groupValue: _selectedStyle,
              onChanged: (v) =>
                  setState(() => _selectedStyle = v ?? _selectedStyle),
              child: Column(
                children: LearningStyle.values.map((style) {
                  return RadioListTile<LearningStyle>(
                    value: style,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    secondary: Icon(_getStyleIcon(style)),
                    title: Text(style.label),
                    subtitle: Text(style.description),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate syllabus'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStyleIcon(LearningStyle style) {
    switch (style) {
      case LearningStyle.chatTutor:
        return Icons.forum_outlined;
      case LearningStyle.videoLecture:
        return Icons.play_circle_outline;
      case LearningStyle.deepArticle:
        return Icons.article_outlined;
      case LearningStyle.researchPaper:
        return Icons.menu_book_outlined;
      case LearningStyle.handsOn:
        return Icons.style_outlined;
      case LearningStyle.balancedHybrid:
        return Icons.auto_awesome_motion_outlined;
    }
  }
}
