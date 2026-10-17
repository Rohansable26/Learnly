enum LearningStyle {
  chatTutor(
    'chat_tutor',
    'Conversational AI Tutor',
    'ChatGPT-style Socratic dialogue & Q&A',
  ),
  videoLecture(
    'video_lecture',
    'Video Masterclasses',
    'Curated YouTube videos & visual breakdowns',
  ),
  deepArticle(
    'deep_article',
    'Technical Deep Dives',
    'In-depth engineering articles & RFC docs',
  ),
  researchPaper(
    'research_paper',
    'ArXiv & Academic Papers',
    'Mathematical rigor, abstracts & architecture papers',
  ),
  handsOn(
    'hands_on',
    'Interactive Coding Labs',
    'Hands-on code snippets & implementation challenges',
  ),
  balancedHybrid(
    'balanced_hybrid',
    'Balanced Multi-Modal',
    'Smart combination of all learning modes',
  );

  final String value;
  final String label;
  final String description;

  const LearningStyle(this.value, this.label, this.description);

  static LearningStyle fromString(String val) {
    return LearningStyle.values.firstWhere(
      (e) => e.value == val,
      orElse: () => LearningStyle.balancedHybrid,
    );
  }
}

enum ExperienceLevel {
  beginner('beginner', 'Beginner', 'Foundations & intuitive mental models'),
  intermediate(
    'intermediate',
    'Intermediate',
    'Core implementation & real-world patterns',
  ),
  advanced(
    'advanced',
    'Advanced',
    'High performance, scale & production edge-cases',
  ),
  expert(
    'expert',
    'Staff / Research',
    'Frontier research & architectural paradigms',
  );

  final String value;
  final String label;
  final String description;

  const ExperienceLevel(this.value, this.label, this.description);

  static ExperienceLevel fromString(String val) {
    return ExperienceLevel.values.firstWhere(
      (e) => e.value == val,
      orElse: () => ExperienceLevel.beginner,
    );
  }
}

class ResourceItem {
  final String id;
  final String title;
  final String type; // video, article, paper, documentation, course
  final String url;
  final String snippet;
  final String sourceName;
  final String? authorOrChannel;
  final String? publishedDate;
  final List<String> keyTakeaways;

  ResourceItem({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.snippet,
    required this.sourceName,
    this.authorOrChannel,
    this.publishedDate,
    required this.keyTakeaways,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'article',
      url: json['url'] ?? '',
      snippet: json['snippet'] ?? '',
      sourceName: json['source_name'] ?? 'Web Resource',
      authorOrChannel: json['author_or_channel'],
      publishedDate: json['published_date'],
      keyTakeaways:
          (json['key_takeaways'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'url': url,
    'snippet': snippet,
    'source_name': sourceName,
    'author_or_channel': authorOrChannel,
    'published_date': publishedDate,
    'key_takeaways': keyTakeaways,
  };
}

class Subtopic {
  final String id;
  final String title;
  final String description;
  final int estimatedMinutes;
  final List<ResourceItem> resources;
  bool isCompleted;
  bool isTrendUpdated;
  String? trendNote;

  Subtopic({
    required this.id,
    required this.title,
    required this.description,
    this.estimatedMinutes = 15,
    required this.resources,
    this.isCompleted = false,
    this.isTrendUpdated = false,
    this.trendNote,
  });

  factory Subtopic.fromJson(Map<String, dynamic> json) {
    return Subtopic(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      estimatedMinutes: json['estimated_minutes'] ?? 15,
      resources:
          (json['resources'] as List<dynamic>?)
              ?.map((r) => ResourceItem.fromJson(r))
              .toList() ??
          [],
      isCompleted: json['is_completed'] ?? false,
      isTrendUpdated: json['is_trend_updated'] ?? false,
      trendNote: json['trend_note'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'estimated_minutes': estimatedMinutes,
    'resources': resources.map((r) => r.toJson()).toList(),
    'is_completed': isCompleted,
    'is_trend_updated': isTrendUpdated,
    'trend_note': trendNote,
  };
}

class Module {
  final String id;
  final String title;
  final String summary;
  final List<String> learningObjectives;
  final int orderIndex;
  final List<Subtopic> subtopics;
  final String? quizId;
  bool isUnlocked;
  bool isPassed;

  Module({
    required this.id,
    required this.title,
    required this.summary,
    this.learningObjectives = const [],
    required this.orderIndex,
    required this.subtopics,
    this.quizId,
    this.isUnlocked = false,
    this.isPassed = false,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      learningObjectives:
          (json['learning_objectives'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      orderIndex: json['order_index'] ?? 1,
      subtopics:
          (json['subtopics'] as List<dynamic>?)
              ?.map((s) => Subtopic.fromJson(s))
              .toList() ??
          [],
      quizId: json['quiz_id'],
      isUnlocked: json['is_unlocked'] ?? false,
      isPassed: json['is_passed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'learning_objectives': learningObjectives,
    'order_index': orderIndex,
    'subtopics': subtopics.map((s) => s.toJson()).toList(),
    'quiz_id': quizId,
    'is_unlocked': isUnlocked,
    'is_passed': isPassed,
  };

  double get progress {
    if (subtopics.isEmpty) return 0.0;
    final completed = subtopics.where((s) => s.isCompleted).length;
    return completed / subtopics.length;
  }
}

class Syllabus {
  final String id;
  final String topic;
  final ExperienceLevel userExperienceLevel;
  final LearningStyle primaryLearningStyle;
  final String industryStandardsSummary;
  final List<String> prerequisites;
  final List<String> learningOutcomes;
  final List<String> latestTrendsIdentified;
  final List<Module> modules;
  final String createdAt;
  final String updatedAt;

  Syllabus({
    required this.id,
    required this.topic,
    required this.userExperienceLevel,
    required this.primaryLearningStyle,
    required this.industryStandardsSummary,
    this.prerequisites = const [],
    this.learningOutcomes = const [],
    required this.latestTrendsIdentified,
    required this.modules,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Syllabus.fromJson(Map<String, dynamic> json) {
    return Syllabus(
      id: json['id'] ?? '',
      topic: json['topic'] ?? '',
      userExperienceLevel: ExperienceLevel.fromString(
        json['user_experience_level'] ?? 'beginner',
      ),
      primaryLearningStyle: LearningStyle.fromString(
        json['primary_learning_style'] ?? 'balanced_hybrid',
      ),
      industryStandardsSummary: json['industry_standards_summary'] ?? '',
      prerequisites:
          (json['prerequisites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      learningOutcomes:
          (json['learning_outcomes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      latestTrendsIdentified:
          (json['latest_trends_identified'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      modules:
          (json['modules'] as List<dynamic>?)
              ?.map((m) => Module.fromJson(m))
              .toList() ??
          [],
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'topic': topic,
    'user_experience_level': userExperienceLevel.value,
    'primary_learning_style': primaryLearningStyle.value,
    'industry_standards_summary': industryStandardsSummary,
    'prerequisites': prerequisites,
    'learning_outcomes': learningOutcomes,
    'latest_trends_identified': latestTrendsIdentified,
    'modules': modules.map((m) => m.toJson()).toList(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Syllabus copyWith({
    List<Module>? modules,
    List<String>? latestTrendsIdentified,
  }) {
    return Syllabus(
      id: id,
      topic: topic,
      userExperienceLevel: userExperienceLevel,
      primaryLearningStyle: primaryLearningStyle,
      industryStandardsSummary: industryStandardsSummary,
      prerequisites: prerequisites,
      learningOutcomes: learningOutcomes,
      latestTrendsIdentified:
          latestTrendsIdentified ?? this.latestTrendsIdentified,
      modules: modules ?? this.modules,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  int get totalSubtopics =>
      modules.fold(0, (sum, m) => sum + m.subtopics.length);

  int get totalEstimatedMinutes => modules.fold(
    0,
    (sum, m) => sum + m.subtopics.fold(0, (s, t) => s + t.estimatedMinutes),
  );

  double get overallProgress {
    int totalSubtopics = 0;
    int completedSubtopics = 0;
    for (final m in modules) {
      totalSubtopics += m.subtopics.length;
      completedSubtopics += m.subtopics.where((s) => s.isCompleted).length;
    }
    if (totalSubtopics == 0) return 0.0;
    return completedSubtopics / totalSubtopics;
  }
}
