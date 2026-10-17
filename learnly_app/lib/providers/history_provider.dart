import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson_content.dart';
import '../services/learning_cache.dart';

/// Everything the student has actually done, persisted on-device.
class HistoryState {
  final bool isLoaded;
  final List<CachedAnswer> answers;
  final List<QuizAttempt> quizAttempts;
  final Set<String> activeDays;

  const HistoryState({
    this.isLoaded = false,
    this.answers = const [],
    this.quizAttempts = const [],
    this.activeDays = const {},
  });

  HistoryState copyWith({
    bool? isLoaded,
    List<CachedAnswer>? answers,
    List<QuizAttempt>? quizAttempts,
    Set<String>? activeDays,
  }) {
    return HistoryState(
      isLoaded: isLoaded ?? this.isLoaded,
      answers: answers ?? this.answers,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      activeDays: activeDays ?? this.activeDays,
    );
  }

  /// Consecutive days with activity, ending today (or yesterday if today has
  /// no activity yet, so the streak isn't shown as broken mid-day).
  int get streakDays {
    var day = DateTime.now();
    if (!activeDays.contains(LearningCache.dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (activeDays.contains(LearningCache.dayKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Activity flags for Monday..Sunday of the current week.
  List<bool> get currentWeekActivity {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return List.generate(
      7,
      (i) => activeDays.contains(
        LearningCache.dayKey(monday.add(Duration(days: i))),
      ),
    );
  }

  int get quizzesTaken => quizAttempts.length;
  int get quizzesPassed => quizAttempts.where((a) => a.passed).length;

  double get averageQuizScore => quizAttempts.isEmpty
      ? 0
      : quizAttempts.fold<double>(0, (s, a) => s + a.scorePercentage) /
            quizAttempts.length;

  /// Best score per module for a course topic.
  Map<String, QuizAttempt> bestAttemptsFor(String topic) {
    final best = <String, QuizAttempt>{};
    for (final a in quizAttempts) {
      if (a.topic.toLowerCase() != topic.toLowerCase()) continue;
      final current = best[a.moduleId];
      if (current == null || a.scorePercentage > current.scorePercentage) {
        best[a.moduleId] = a;
      }
    }
    return best;
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    _load();
    return const HistoryState();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      learningCache.loadAnswers(),
      learningCache.loadQuizAttempts(),
      learningCache.loadActiveDays(),
    ]);
    state = state.copyWith(
      isLoaded: true,
      answers: results[0] as List<CachedAnswer>,
      quizAttempts: results[1] as List<QuizAttempt>,
      activeDays: results[2] as Set<String>,
    );
  }

  /// Returns a cached answer for [question] in this lesson, if one exists.
  CachedAnswer? findAnswer({
    required String topic,
    required String subtopic,
    required String question,
  }) {
    return LearningCache.match(
      state.answers,
      topic: topic,
      subtopic: subtopic,
      question: question,
    );
  }

  Future<void> markAnswerReused(CachedAnswer answer) async {
    final updated = state.answers
        .map((a) => a.id == answer.id ? a.touched() : a)
        .toList();
    state = state.copyWith(answers: updated);
    await _persistAnswers();
  }

  Future<void> saveAnswer({
    required String topic,
    required String subtopic,
    required String question,
    required TutorChatMessage reply,
  }) async {
    final now = DateTime.now();
    final normalized = LearningCache.normalize(question);
    // Replace any older answer to the same question in the same lesson.
    final others = state.answers.where(
      (a) =>
          !(a.topic == topic &&
              a.subtopic == subtopic &&
              LearningCache.normalize(a.question) == normalized),
    );
    final entry = CachedAnswer(
      id: now.microsecondsSinceEpoch.toString(),
      topic: topic,
      subtopic: subtopic,
      question: question.trim(),
      answer: reply.text,
      followUpQuestions: reply.followUpQuestions,
      citedResources: reply.citedResources,
      createdAt: now,
      lastUsedAt: now,
    );
    state = state.copyWith(answers: [entry, ...others]);
    await _persistAnswers();
    await recordActivity();
  }

  Future<void> deleteAnswer(String id) async {
    state = state.copyWith(
      answers: state.answers.where((a) => a.id != id).toList(),
    );
    await _persistAnswers();
  }

  Future<void> clearAnswers() async {
    state = state.copyWith(answers: []);
    await _persistAnswers();
  }

  Future<void> recordQuiz(QuizAttempt attempt) async {
    state = state.copyWith(quizAttempts: [...state.quizAttempts, attempt]);
    try {
      await learningCache.saveQuizAttempts(state.quizAttempts);
    } catch (e) {
      debugPrint('Failed to persist quiz attempt: $e');
    }
    await recordActivity();
  }

  Future<void> recordActivity() async {
    final today = LearningCache.dayKey(DateTime.now());
    if (state.activeDays.contains(today)) return;
    state = state.copyWith(activeDays: {...state.activeDays, today});
    try {
      await learningCache.saveActiveDays(state.activeDays);
    } catch (e) {
      debugPrint('Failed to persist activity: $e');
    }
  }

  Future<void> _persistAnswers() async {
    try {
      await learningCache.saveAnswers(state.answers);
    } catch (e) {
      debugPrint('Failed to persist Q&A cache: $e');
    }
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);
