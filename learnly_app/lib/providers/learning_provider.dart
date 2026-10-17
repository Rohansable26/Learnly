import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/syllabus.dart';
import '../models/lesson_content.dart';
import '../services/api_service.dart';
import '../services/learning_cache.dart';
import '../services/youtube_service.dart';
import 'history_provider.dart';

class LearningState {
  final TopicLessonContent? lessonContent;
  final LearningStyle activeStyle;
  final bool isLoading;
  final String? errorMessage;
  final List<TutorChatMessage> chatMessages;
  final bool isSendingMessage;

  /// True when the lesson shown came from the on-device cache.
  final bool lessonFromCache;

  LearningState({
    this.lessonContent,
    this.activeStyle = LearningStyle.balancedHybrid,
    this.isLoading = false,
    this.errorMessage,
    this.chatMessages = const [],
    this.isSendingMessage = false,
    this.lessonFromCache = false,
  });

  LearningState copyWith({
    TopicLessonContent? lessonContent,
    LearningStyle? activeStyle,
    bool? isLoading,
    String? errorMessage,
    List<TutorChatMessage>? chatMessages,
    bool? isSendingMessage,
    bool? lessonFromCache,
  }) {
    return LearningState(
      lessonContent: lessonContent ?? this.lessonContent,
      activeStyle: activeStyle ?? this.activeStyle,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      chatMessages: chatMessages ?? this.chatMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      lessonFromCache: lessonFromCache ?? this.lessonFromCache,
    );
  }
}

class LearningNotifier extends Notifier<LearningState> {
  String? _topic;
  String? _subtopic;

  @override
  LearningState build() {
    return LearningState();
  }

  Future<void> loadLesson({
    required String topic,
    required String moduleTitle,
    required String subtopicTitle,
    LearningStyle? preferredStyle,
    bool forceRefresh = false,
  }) async {
    final style = preferredStyle ?? state.activeStyle;
    _topic = topic;
    _subtopic = subtopicTitle;
    state = LearningState(isLoading: true, activeStyle: style);
    ref.read(historyProvider.notifier).recordActivity();

    try {
      TopicLessonContent? content;
      var fromCache = false;
      if (!forceRefresh) {
        content = await learningCache.loadLesson(
          topic,
          moduleTitle,
          subtopicTitle,
        );
        fromCache = content != null;
      }

      if (content == null) {
        // Fetch the lesson and search YouTube directly in parallel.
        final lessonFuture = apiService.getLessonContent(
          topic: topic,
          moduleTitle: moduleTitle,
          subtopicTitle: subtopicTitle,
          style: style,
        );
        final videosFuture = youTubeService.searchLearningVideos(
          '$topic $subtopicTitle',
        );
        content = await lessonFuture;
        final videos = await videosFuture;
        if (videos.isNotEmpty) {
          content = content.copyWith(recommendedVideos: videos);
        }
        await learningCache.saveLesson(
          topic,
          moduleTitle,
          subtopicTitle,
          content,
        );
      }

      // Bail out if the user navigated to another lesson meanwhile.
      if (_subtopic != subtopicTitle || _topic != topic) return;

      var messages = await learningCache.loadChat(topic, subtopicTitle);
      if (messages.isEmpty) {
        messages = [
          for (final (i, turn) in content.socraticDialogue.indexed)
            TutorChatMessage(
              id: 'intro_$i',
              sender: turn['speaker'] == 'student' ? 'student' : 'tutor',
              text: turn['text'] ?? '',
            ),
        ];
      }

      state = state.copyWith(
        lessonContent: content,
        isLoading: false,
        chatMessages: messages,
        lessonFromCache: fromCache,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e is ApiException ? e.message : 'Failed to load lesson: $e',
      );
    }
  }

  void switchFormat(LearningStyle newStyle) {
    state = state.copyWith(activeStyle: newStyle);
  }

  /// Sends a question to the tutor. Previously answered questions in this
  /// lesson are served from the on-device cache unless [bypassCache] is set.
  Future<void> sendStudentMessage({
    required String topic,
    required String subtopicTitle,
    required String studentText,
    bool bypassCache = false,
  }) async {
    final question = studentText.trim();
    if (question.isEmpty || state.isSendingMessage) return;

    final history = ref.read(historyProvider.notifier);
    final priorMessages = state.chatMessages.where((m) => !m.isError).toList();
    final userMsg = TutorChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'student',
      text: question,
    );

    final cached = bypassCache
        ? null
        : history.findAnswer(
            topic: topic,
            subtopic: subtopicTitle,
            question: question,
          );
    if (cached != null) {
      final reply = TutorChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}_cached',
        sender: 'tutor',
        text: cached.answer,
        followUpQuestions: cached.followUpQuestions,
        citedResources: cached.citedResources,
        fromCache: true,
      );
      state = state.copyWith(
        chatMessages: [...state.chatMessages, userMsg, reply],
      );
      history.markAnswerReused(cached);
      history.recordActivity();
      _persistChat(topic, subtopicTitle);
      return;
    }

    state = state.copyWith(
      chatMessages: [...state.chatMessages, userMsg],
      isSendingMessage: true,
    );

    try {
      final reply = await apiService.askTutor(
        topic: topic,
        subtopicTitle: subtopicTitle,
        lessonContext: state.lessonContent?.coreMarkdownContent ?? '',
        studentMessage: question,
        chatHistory: priorMessages
            .map((m) => {'role': m.sender, 'content': m.text})
            .toList(),
        style: state.activeStyle,
      );

      state = state.copyWith(
        chatMessages: [...state.chatMessages, reply],
        isSendingMessage: false,
      );
      await history.saveAnswer(
        topic: topic,
        subtopic: subtopicTitle,
        question: question,
        reply: reply,
      );
    } catch (e) {
      final errorMsg = TutorChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}_error',
        sender: 'tutor',
        text: e is ApiException
            ? e.message
            : 'Something went wrong reaching the tutor. Please try again.',
        isError: true,
      );
      state = state.copyWith(
        chatMessages: [...state.chatMessages, errorMsg],
        isSendingMessage: false,
      );
    }
    _persistChat(topic, subtopicTitle);
  }

  /// Asks the tutor again for a fresh answer to the student question that
  /// preceded the message at [tutorMessageIndex], replacing the cached one.
  Future<void> regenerateAnswer({
    required String topic,
    required String subtopicTitle,
    required int tutorMessageIndex,
  }) async {
    final messages = state.chatMessages;
    for (var i = tutorMessageIndex - 1; i >= 0; i--) {
      if (!messages[i].isTutor) {
        await sendStudentMessage(
          topic: topic,
          subtopicTitle: subtopicTitle,
          studentText: messages[i].text,
          bypassCache: true,
        );
        return;
      }
    }
  }

  Future<void> clearConversation({
    required String topic,
    required String subtopicTitle,
  }) async {
    await learningCache.clearChat(topic, subtopicTitle);
    final content = state.lessonContent;
    state = state.copyWith(
      chatMessages: [
        if (content != null)
          for (final (i, turn) in content.socraticDialogue.indexed)
            TutorChatMessage(
              id: 'intro_$i',
              sender: turn['speaker'] == 'student' ? 'student' : 'tutor',
              text: turn['text'] ?? '',
            ),
      ],
    );
  }

  Future<void> _persistChat(String topic, String subtopicTitle) async {
    try {
      await learningCache.saveChat(topic, subtopicTitle, state.chatMessages);
    } catch (e) {
      debugPrint('Failed to persist chat: $e');
    }
  }
}

final learningProvider = NotifierProvider<LearningNotifier, LearningState>(
  LearningNotifier.new,
);
