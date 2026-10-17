class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String conceptTested;
  final String? referenceNote;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.conceptTested,
    this.referenceNote,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctOptionIndex: json['correct_option_index'] ?? 0,
      explanation: json['explanation'] ?? '',
      conceptTested: json['concept_tested'] ?? 'Concept',
      referenceNote: json['reference_note'],
    );
  }
}

class Quiz {
  final String id;
  final String syllabusId;
  final String moduleId;
  final String moduleTitle;
  final List<QuizQuestion> questions;
  final int passingScorePercentage;

  Quiz({
    required this.id,
    required this.syllabusId,
    required this.moduleId,
    required this.moduleTitle,
    required this.questions,
    this.passingScorePercentage = 75,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? '',
      syllabusId: json['syllabus_id'] ?? '',
      moduleId: json['module_id'] ?? '',
      moduleTitle: json['module_title'] ?? '',
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map((q) => QuizQuestion.fromJson(q))
              .toList() ??
          [],
      passingScorePercentage: json['passing_score_percentage'] ?? 75,
    );
  }
}

class QuestionEvaluation {
  final String questionId;
  final bool isCorrect;
  final int userAnswerIndex;
  final int correctAnswerIndex;
  final String explanation;
  final String? remediationRecommendation;

  QuestionEvaluation({
    required this.questionId,
    required this.isCorrect,
    required this.userAnswerIndex,
    required this.correctAnswerIndex,
    required this.explanation,
    this.remediationRecommendation,
  });

  factory QuestionEvaluation.fromJson(Map<String, dynamic> json) {
    return QuestionEvaluation(
      questionId: json['question_id'] ?? '',
      isCorrect: json['is_correct'] ?? false,
      userAnswerIndex: json['user_answer_index'] ?? -1,
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
      explanation: json['explanation'] ?? '',
      remediationRecommendation: json['remediation_recommendation'],
    );
  }
}

class QuizResultResponse {
  final String quizId;
  final double scorePercentage;
  final bool passed;
  final int correctCount;
  final int totalQuestions;
  final List<QuestionEvaluation> evaluations;
  final String aiCoachingFeedback;

  QuizResultResponse({
    required this.quizId,
    required this.scorePercentage,
    required this.passed,
    required this.correctCount,
    required this.totalQuestions,
    required this.evaluations,
    required this.aiCoachingFeedback,
  });

  factory QuizResultResponse.fromJson(Map<String, dynamic> json) {
    return QuizResultResponse(
      quizId: json['quiz_id'] ?? '',
      scorePercentage: (json['score_percentage'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] ?? false,
      correctCount: json['correct_count'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      evaluations:
          (json['evaluations'] as List<dynamic>?)
              ?.map((e) => QuestionEvaluation.fromJson(e))
              .toList() ??
          [],
      aiCoachingFeedback: json['ai_coaching_feedback'] ?? '',
    );
  }
}
