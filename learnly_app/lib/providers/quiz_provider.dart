import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import '../services/learning_cache.dart';
import 'history_provider.dart';

class QuizState {
  final Quiz? activeQuiz;
  final int currentQuestionIndex;
  final Map<String, int> selectedAnswers; // questionId -> optionIndex
  final bool isLoading;
  final bool isSubmitting;
  final QuizResultResponse? result;
  final String? errorMessage;
  final String topic;

  QuizState({
    this.activeQuiz,
    this.currentQuestionIndex = 0,
    this.selectedAnswers = const {},
    this.isLoading = false,
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.topic = '',
  });

  QuizState copyWith({
    Quiz? activeQuiz,
    int? currentQuestionIndex,
    Map<String, int>? selectedAnswers,
    bool? isLoading,
    bool? isSubmitting,
    QuizResultResponse? result,
    String? errorMessage,
    String? topic,
  }) {
    return QuizState(
      activeQuiz: activeQuiz ?? this.activeQuiz,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result,
      errorMessage: errorMessage,
      topic: topic ?? this.topic,
    );
  }
}

class QuizNotifier extends Notifier<QuizState> {
  @override
  QuizState build() {
    return QuizState();
  }

  Future<void> loadQuiz({
    required String syllabusId,
    required String topic,
    required String moduleId,
    required String moduleTitle,
  }) async {
    state = state.copyWith(
      isLoading: true,
      topic: topic,
      currentQuestionIndex: 0,
      selectedAnswers: {},
      result: null,
      errorMessage: null,
    );

    try {
      final quiz = await apiService.getModuleQuiz(
        syllabusId: syllabusId,
        topic: topic,
        moduleId: moduleId,
        moduleTitle: moduleTitle,
      );

      state = state.copyWith(activeQuiz: quiz, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e is ApiException ? e.message : 'Failed to load quiz: $e',
      );
    }
  }

  void selectOption(String questionId, int optionIndex) {
    final updated = Map<String, int>.from(state.selectedAnswers);
    updated[questionId] = optionIndex;
    state = state.copyWith(selectedAnswers: updated);
  }

  void goToQuestion(int index) {
    if (state.activeQuiz != null &&
        index >= 0 &&
        index < state.activeQuiz!.questions.length) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  void nextQuestion() {
    if (state.activeQuiz != null &&
        state.currentQuestionIndex < state.activeQuiz!.questions.length - 1) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  void previousQuestion() {
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  Future<QuizResultResponse?> submitQuiz() async {
    final quiz = state.activeQuiz;
    if (quiz == null) return null;

    state = state.copyWith(isSubmitting: true);
    try {
      final result = await apiService.submitQuiz(
        quizId: quiz.id,
        selectedAnswers: state.selectedAnswers,
      );

      state = state.copyWith(isSubmitting: false, result: result);
      await ref
          .read(historyProvider.notifier)
          .recordQuiz(
            QuizAttempt(
              topic: state.topic,
              moduleId: quiz.moduleId,
              moduleTitle: quiz.moduleTitle,
              scorePercentage: result.scorePercentage,
              passed: result.passed,
              takenAt: DateTime.now(),
            ),
          );
      return result;
    } catch (e) {
      // A 404 means the server restarted and forgot the quiz. Grading locally
      // would be inaccurate, so ask the student to retake it instead.
      final message = e is ApiException && e.isNotFound
          ? 'This quiz expired. Go back and start it again.'
          : e is ApiException
          ? e.message
          : 'Failed to submit quiz. Please try again.';
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return null;
    }
  }

  void retryQuiz() {
    state = state.copyWith(
      currentQuestionIndex: 0,
      selectedAnswers: {},
      result: null,
    );
  }
}

final quizProvider = NotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);
