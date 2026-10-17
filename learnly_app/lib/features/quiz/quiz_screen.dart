import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/syllabus_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String syllabusId;
  final String topic;
  final String moduleId;
  final String moduleTitle;

  const QuizScreen({
    super.key,
    required this.syllabusId,
    required this.topic,
    required this.moduleId,
    required this.moduleTitle,
  });

  static Future<void> navigate(
    BuildContext context, {
    required String syllabusId,
    required String topic,
    required String moduleId,
    required String moduleTitle,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          syllabusId: syllabusId,
          topic: topic,
          moduleId: moduleId,
          moduleTitle: moduleTitle,
        ),
      ),
    );
  }

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(quizProvider.notifier)
          .loadQuiz(
            syllabusId: widget.syllabusId,
            topic: widget.topic,
            moduleId: widget.moduleId,
            moduleTitle: widget.moduleTitle,
          );
    });
  }

  void _handleSubmit() async {
    final quizState = ref.read(quizProvider);
    final quiz = quizState.activeQuiz;
    if (quiz == null) return;

    if (quizState.selectedAnswers.length < quiz.questions.length) {
      final unanswered =
          quiz.questions.length - quizState.selectedAnswers.length;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.help_outline),
          title: const Text('Submit with unanswered questions?'),
          content: Text(
            'You have $unanswered unanswered question${unanswered == 1 ? '' : 's'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final result = await ref.read(quizProvider.notifier).submitQuiz();
    if (result != null && result.passed) {
      ref
          .read(syllabusProvider.notifier)
          .markModulePassedAndUnlockNext(widget.moduleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Module quiz', style: context.text.titleMedium),
            Text(
              widget.moduleTitle,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: state.isLoading
          ? const EmptyState(
              loading: true,
              icon: Icons.quiz_outlined,
              title: 'Generating questions',
              message: 'Building a quiz based on this module.',
            )
          : state.result != null
          ? _buildResultView(state.result!)
          : _buildQuizView(state),
    );
  }

  Widget _buildQuizView(QuizState state) {
    final quiz = state.activeQuiz;
    if (quiz == null || quiz.questions.isEmpty) {
      return EmptyState(
        icon: Icons.quiz_outlined,
        title: 'No questions available',
        message: state.errorMessage,
      );
    }

    final currentQuestion = quiz.questions[state.currentQuestionIndex];
    final selectedOption = state.selectedAnswers[currentQuestion.id];
    final progress = (state.currentQuestionIndex + 1) / quiz.questions.length;
    final isLast = state.currentQuestionIndex == quiz.questions.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          borderRadius: BorderRadius.zero,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Text(
                    'Question ${state.currentQuestionIndex + 1} of ${quiz.questions.length}',
                    style: context.text.labelLarge?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: InfoTag(
                      label: currentQuestion.conceptTested,
                      tone: Tone.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(currentQuestion.question, style: context.text.titleLarge),
              const SizedBox(height: 24),
              ...currentQuestion.options.asMap().entries.map((entry) {
                final idx = entry.key;
                final isSelected = selectedOption == idx;
                final letter = String.fromCharCode(65 + idx);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: isSelected
                        ? context.colors.secondaryContainer
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => ref
                          .read(quizProvider.notifier)
                          .selectOption(currentQuestion.id, idx),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? context.colors.primary
                                  : context.colors.surfaceContainerHighest,
                              foregroundColor: isSelected
                                  ? context.colors.onPrimary
                                  : context.colors.onSurfaceVariant,
                              child: Text(
                                letter,
                                style: context.text.labelLarge?.copyWith(
                                  color: null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  entry.value,
                                  style: context.text.bodyLarge?.copyWith(
                                    color: isSelected
                                        ? context.colors.onSecondaryContainer
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Material(
          color: context.colors.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (state.currentQuestionIndex > 0)
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(quizProvider.notifier).previousQuestion(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  if (!isLast)
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(quizProvider.notifier).nextQuestion(),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: state.isSubmitting ? null : _handleSubmit,
                      icon: state.isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(state.isSubmitting ? 'Checking…' : 'Submit'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(QuizResultResponse result) {
    final passTone = result.passed ? Tone.success : Tone.error;
    final passColor = passTone.accent(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: IconBadge(
            icon: result.passed ? Icons.emoji_events_outlined : Icons.replay,
            tone: passTone,
            size: 80,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          result.passed ? 'Module passed' : 'Not quite there yet',
          style: context.text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${result.scorePercentage.toStringAsFixed(0)}% · ${result.correctCount} of ${result.totalQuestions} correct',
          style: context.text.titleMedium?.copyWith(color: passColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        Card.filled(
          color: context.colors.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text('Feedback', style: context.text.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(result.aiCoachingFeedback, style: context.text.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Question review'),
        ...result.evaluations.asMap().entries.map((entry) {
          final ev = entry.value;
          final tone = ev.isCorrect ? Tone.success : Tone.error;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Question ${entry.key + 1}',
                          style: context.text.titleSmall,
                        ),
                        const Spacer(),
                        InfoTag(
                          label: ev.isCorrect ? 'Correct' : 'Incorrect',
                          icon: ev.isCorrect ? Icons.check : Icons.close,
                          tone: tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(ev.explanation, style: context.text.bodyMedium),
                    if (ev.remediationRecommendation != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.status.warningContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: context.status.onWarningContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ev.remediationRecommendation!,
                                style: context.text.bodySmall?.copyWith(
                                  color: context.status.onWarningContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref.read(quizProvider.notifier).retryQuiz(),
                child: const Text('Retry'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(result.passed ? 'Continue' : 'Back to lesson'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
