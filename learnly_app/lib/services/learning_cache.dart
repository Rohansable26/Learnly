import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lesson_content.dart';
import '../models/syllabus.dart';

/// A tutor answer the student received before, kept on-device so the same
/// question can be answered instantly (and offline) and reviewed later.
class CachedAnswer {
  final String id;
  final String topic;
  final String subtopic;
  final String question;
  final String answer;
  final List<String> followUpQuestions;
  final List<ResourceItem> citedResources;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int useCount;

  CachedAnswer({
    required this.id,
    required this.topic,
    required this.subtopic,
    required this.question,
    required this.answer,
    this.followUpQuestions = const [],
    this.citedResources = const [],
    required this.createdAt,
    required this.lastUsedAt,
    this.useCount = 1,
  });

  CachedAnswer touched() => CachedAnswer(
    id: id,
    topic: topic,
    subtopic: subtopic,
    question: question,
    answer: answer,
    followUpQuestions: followUpQuestions,
    citedResources: citedResources,
    createdAt: createdAt,
    lastUsedAt: DateTime.now(),
    useCount: useCount + 1,
  );

  factory CachedAnswer.fromJson(Map<String, dynamic> json) => CachedAnswer(
    id: json['id'] ?? '',
    topic: json['topic'] ?? '',
    subtopic: json['subtopic'] ?? '',
    question: json['question'] ?? '',
    answer: json['answer'] ?? '',
    followUpQuestions:
        (json['follow_up_questions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    citedResources:
        (json['cited_resources'] as List<dynamic>?)
            ?.map((e) => ResourceItem.fromJson(e))
            .toList() ??
        [],
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    lastUsedAt: DateTime.tryParse(json['last_used_at'] ?? '') ?? DateTime.now(),
    useCount: json['use_count'] ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'topic': topic,
    'subtopic': subtopic,
    'question': question,
    'answer': answer,
    'follow_up_questions': followUpQuestions,
    'cited_resources': citedResources.map((r) => r.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'last_used_at': lastUsedAt.toIso8601String(),
    'use_count': useCount,
  };
}

/// One finished module quiz.
class QuizAttempt {
  final String topic;
  final String moduleId;
  final String moduleTitle;
  final double scorePercentage;
  final bool passed;
  final DateTime takenAt;

  QuizAttempt({
    required this.topic,
    required this.moduleId,
    required this.moduleTitle,
    required this.scorePercentage,
    required this.passed,
    required this.takenAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
    topic: json['topic'] ?? '',
    moduleId: json['module_id'] ?? '',
    moduleTitle: json['module_title'] ?? '',
    scorePercentage: (json['score_percentage'] as num?)?.toDouble() ?? 0,
    passed: json['passed'] ?? false,
    takenAt: DateTime.tryParse(json['taken_at'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'module_id': moduleId,
    'module_title': moduleTitle,
    'score_percentage': scorePercentage,
    'passed': passed,
    'taken_at': takenAt.toIso8601String(),
  };
}

/// Persistent, on-device store for everything the student has learned:
/// tutor Q&A, chat transcripts, generated lessons, quiz attempts and study days.
class LearningCache {
  static const _qaKey = 'learnly_qa_cache_v1';
  static const _chatPrefix = 'learnly_chat_v1::';
  static const _lessonPrefix = 'learnly_lesson_v1::';
  static const _lessonIndexKey = 'learnly_lesson_index_v1';
  static const _quizKey = 'learnly_quiz_attempts_v1';
  static const _activityKey = 'learnly_active_days_v1';

  static const maxAnswers = 500;
  static const maxChatMessages = 120;
  static const maxLessons = 60;

  static const _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'to', 'of', 'in', 'on',
    'for', 'and', 'or', 'what', 'why', 'how', 'when', 'which', 'who', 'do',
    'does', 'did', 'can', 'could', 'would', 'should', 'i', 'me', 'my', 'you',
    'your', 'please', 'explain', 'tell', 'about', 'with', 'it', 'this', 'that',
    'between', 'vs', 'versus',
  };

  // Questions whose meaning depends on the preceding conversation.
  static final _contextualPattern = RegExp(
    r'\b(this|that|it|above|previous|elaborate|more|again|continue|same|those|these)\b',
  );

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static String _scope(String topic, String subtopic) =>
      '${topic.trim().toLowerCase()}||${subtopic.trim().toLowerCase()}';

  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> _contentTokens(String text) => normalize(
    text,
  ).split(' ').where((w) => w.length > 1 && !_stopWords.contains(w)).toSet();

  // ---------------------------------------------------------------------------
  // Q&A cache
  // ---------------------------------------------------------------------------

  Future<List<CachedAnswer>> loadAnswers() async {
    try {
      final raw = (await _prefs).getString(_qaKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CachedAnswer.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('LearningCache: failed to read Q&A cache: $e');
      return [];
    }
  }

  Future<void> saveAnswers(List<CachedAnswer> answers) async {
    final trimmed = answers.length > maxAnswers
        ? (List<CachedAnswer>.from(answers)
                ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt)))
              .take(maxAnswers)
              .toList()
        : answers;
    await (await _prefs).setString(
      _qaKey,
      jsonEncode(trimmed.map((a) => a.toJson()).toList()),
    );
  }

  /// Finds a previously answered question in the same lesson.
  ///
  /// Exact (normalized) matches always hit. Near-duplicates hit when they share
  /// almost all content words. Context-dependent questions ("explain that
  /// again") only hit on an exact match with enough content to be unambiguous.
  static CachedAnswer? match(
    List<CachedAnswer> answers, {
    required String topic,
    required String subtopic,
    required String question,
  }) {
    final scope = _scope(topic, subtopic);
    final normalized = normalize(question);
    final tokens = _contentTokens(question);
    final contextual = _contextualPattern.hasMatch(normalized);

    if (contextual && tokens.length < 4) return null;

    CachedAnswer? best;
    double bestScore = 0;
    for (final a in answers) {
      if (_scope(a.topic, a.subtopic) != scope) continue;
      if (normalize(a.question) == normalized) return a;
      if (contextual || tokens.length < 3) continue;

      final other = _contentTokens(a.question);
      if (other.isEmpty) continue;
      final overlap = tokens.intersection(other).length;
      final score = overlap / tokens.union(other).length;
      if (score > bestScore) {
        bestScore = score;
        best = a;
      }
    }
    return bestScore >= 0.8 ? best : null;
  }

  // ---------------------------------------------------------------------------
  // Chat transcripts (per lesson)
  // ---------------------------------------------------------------------------

  Future<List<TutorChatMessage>> loadChat(String topic, String subtopic) async {
    try {
      final raw = (await _prefs).getString(
        _chatPrefix + _scope(topic, subtopic),
      );
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => TutorChatMessage.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('LearningCache: failed to read chat: $e');
      return [];
    }
  }

  Future<void> saveChat(
    String topic,
    String subtopic,
    List<TutorChatMessage> messages,
  ) async {
    final kept = messages.length > maxChatMessages
        ? messages.sublist(messages.length - maxChatMessages)
        : messages;
    await (await _prefs).setString(
      _chatPrefix + _scope(topic, subtopic),
      jsonEncode(kept.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> clearChat(String topic, String subtopic) async {
    await (await _prefs).remove(_chatPrefix + _scope(topic, subtopic));
  }

  // ---------------------------------------------------------------------------
  // Generated lessons
  // ---------------------------------------------------------------------------

  static String _lessonKey(String topic, String module, String subtopic) =>
      '$_lessonPrefix${topic.trim().toLowerCase()}||'
      '${module.trim().toLowerCase()}||${subtopic.trim().toLowerCase()}';

  Future<TopicLessonContent?> loadLesson(
    String topic,
    String module,
    String subtopic,
  ) async {
    try {
      final raw = (await _prefs).getString(_lessonKey(topic, module, subtopic));
      if (raw == null) return null;
      return TopicLessonContent.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('LearningCache: failed to read lesson: $e');
      return null;
    }
  }

  Future<void> saveLesson(
    String topic,
    String module,
    String subtopic,
    TopicLessonContent lesson,
  ) async {
    final prefs = await _prefs;
    final key = _lessonKey(topic, module, subtopic);
    final index = prefs.getStringList(_lessonIndexKey) ?? [];
    index
      ..remove(key)
      ..add(key);
    while (index.length > maxLessons) {
      await prefs.remove(index.removeAt(0));
    }
    await prefs.setString(key, jsonEncode(lesson.toJson()));
    await prefs.setStringList(_lessonIndexKey, index);
  }

  /// All cached lessons, optionally limited to one course topic.
  Future<List<TopicLessonContent>> loadAllLessons({String? topic}) async {
    final prefs = await _prefs;
    final index = prefs.getStringList(_lessonIndexKey) ?? [];
    final prefix = topic == null
        ? _lessonPrefix
        : '$_lessonPrefix${topic.trim().toLowerCase()}||';
    final lessons = <TopicLessonContent>[];
    for (final key in index.reversed) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        lessons.add(TopicLessonContent.fromJson(jsonDecode(raw)));
      } catch (_) {}
    }
    return lessons;
  }

  // ---------------------------------------------------------------------------
  // Progress: quiz attempts and active study days
  // ---------------------------------------------------------------------------

  Future<List<QuizAttempt>> loadQuizAttempts() async {
    try {
      final raw = (await _prefs).getString(_quizKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => QuizAttempt.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQuizAttempts(List<QuizAttempt> attempts) async {
    await (await _prefs).setString(
      _quizKey,
      jsonEncode(attempts.map((a) => a.toJson()).toList()),
    );
  }

  Future<Set<String>> loadActiveDays() async {
    return ((await _prefs).getStringList(_activityKey) ?? []).toSet();
  }

  Future<void> saveActiveDays(Set<String> days) async {
    final sorted = days.toList()..sort();
    // Keep a year of history.
    final kept = sorted.length > 366
        ? sorted.sublist(sorted.length - 366)
        : sorted;
    await (await _prefs).setStringList(_activityKey, kept);
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final learningCache = LearningCache();
