import 'syllabus.dart';
import 'flashcard.dart';

class TutorChatMessage {
  final String id;
  final String sender; // 'tutor' or 'student'
  final String text;
  final List<String> followUpQuestions;
  final List<ResourceItem> citedResources;
  final DateTime timestamp;

  /// True when the answer was served from the on-device Q&A cache.
  final bool fromCache;

  /// True for local error notices that should not be cached or sent as history.
  final bool isError;

  TutorChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.followUpQuestions = const [],
    this.citedResources = const [],
    DateTime? timestamp,
    this.fromCache = false,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isTutor => sender == 'tutor';

  factory TutorChatMessage.fromJson(Map<String, dynamic> json) {
    return TutorChatMessage(
      id: json['id'] ?? '',
      sender: json['sender'] ?? 'tutor',
      text: json['text'] ?? '',
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
      timestamp: DateTime.tryParse(json['timestamp'] ?? ''),
      fromCache: json['from_cache'] ?? false,
      isError: json['is_error'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'text': text,
    'follow_up_questions': followUpQuestions,
    'cited_resources': citedResources.map((r) => r.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
    'from_cache': fromCache,
    'is_error': isError,
  };
}

class CodeSnippet {
  final String language;
  final String title;
  final String code;

  CodeSnippet({
    required this.language,
    required this.title,
    required this.code,
  });

  factory CodeSnippet.fromJson(Map<String, dynamic> json) {
    return CodeSnippet(
      language: json['language'] ?? 'python',
      title: json['title'] ?? 'Code Example',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'language': language,
    'title': title,
    'code': code,
  };
}

class TopicLessonContent {
  final String subtopicId;
  final String title;
  final String moduleTitle;
  final LearningStyle format;
  final String coreMarkdownContent;
  final List<Map<String, String>> socraticDialogue;
  final List<ResourceItem> recommendedVideos;
  final List<ResourceItem> researchPapers;
  final List<ResourceItem> curatedArticles;
  final List<CodeSnippet> codeSnippets;
  final List<String> keyCheatSheetPoints;
  final List<Flashcard> flashcards;

  TopicLessonContent({
    required this.subtopicId,
    required this.title,
    required this.moduleTitle,
    required this.format,
    required this.coreMarkdownContent,
    required this.socraticDialogue,
    required this.recommendedVideos,
    required this.researchPapers,
    required this.curatedArticles,
    required this.codeSnippets,
    required this.keyCheatSheetPoints,
    this.flashcards = const [],
  });

  TopicLessonContent copyWith({List<ResourceItem>? recommendedVideos}) {
    return TopicLessonContent(
      subtopicId: subtopicId,
      title: title,
      moduleTitle: moduleTitle,
      format: format,
      coreMarkdownContent: coreMarkdownContent,
      socraticDialogue: socraticDialogue,
      recommendedVideos: recommendedVideos ?? this.recommendedVideos,
      researchPapers: researchPapers,
      curatedArticles: curatedArticles,
      codeSnippets: codeSnippets,
      keyCheatSheetPoints: keyCheatSheetPoints,
      flashcards: flashcards,
    );
  }

  factory TopicLessonContent.fromJson(Map<String, dynamic> json) {
    return TopicLessonContent(
      subtopicId: json['subtopic_id'] ?? '',
      title: json['title'] ?? '',
      moduleTitle: json['module_title'] ?? '',
      format: LearningStyle.fromString(json['format'] ?? 'balanced_hybrid'),
      coreMarkdownContent: json['core_markdown_content'] ?? '',
      socraticDialogue:
          (json['socratic_dialogue'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      recommendedVideos:
          (json['recommended_videos'] as List<dynamic>?)
              ?.map((e) => ResourceItem.fromJson(e))
              .toList() ??
          [],
      researchPapers:
          (json['research_papers'] as List<dynamic>?)
              ?.map((e) => ResourceItem.fromJson(e))
              .toList() ??
          [],
      curatedArticles:
          (json['curated_articles'] as List<dynamic>?)
              ?.map((e) => ResourceItem.fromJson(e))
              .toList() ??
          [],
      codeSnippets:
          (json['code_snippets'] as List<dynamic>?)
              ?.map((e) => CodeSnippet.fromJson(e))
              .toList() ??
          [],
      keyCheatSheetPoints:
          (json['key_cheat_sheet_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      flashcards:
          (json['flashcards'] as List<dynamic>?)
              ?.map((e) => Flashcard.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'subtopic_id': subtopicId,
    'title': title,
    'module_title': moduleTitle,
    'format': format.value,
    'core_markdown_content': coreMarkdownContent,
    'socratic_dialogue': socraticDialogue,
    'recommended_videos': recommendedVideos.map((e) => e.toJson()).toList(),
    'research_papers': researchPapers.map((e) => e.toJson()).toList(),
    'curated_articles': curatedArticles.map((e) => e.toJson()).toList(),
    'code_snippets': codeSnippets.map((e) => e.toJson()).toList(),
    'key_cheat_sheet_points': keyCheatSheetPoints,
    'flashcards': flashcards.map((e) => e.toJson()).toList(),
  };
}
