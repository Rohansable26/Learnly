import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/syllabus.dart';
import '../models/lesson_content.dart';
import '../models/quiz.dart';
import '../models/trend_update.dart';

/// A user-presentable failure from the Learnly backend.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client = http.Client();

  // AI-backed endpoints take a while; keep these generous.
  static const _syllabusTimeout = Duration(seconds: 150);
  static const _lessonTimeout = Duration(seconds: 120);
  static const _chatTimeout = Duration(seconds: 75);
  static const _quizTimeout = Duration(seconds: 90);
  static const _shortTimeout = Duration(seconds: 25);

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    required Duration timeout,
    int retries = 1,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await request().timeout(timeout);
        final body = utf8.decode(response.bodyBytes);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(body);
        }
        final retryable = response.statusCode >= 500;
        if (retryable && attempt < retries) continue;
        throw ApiException(
          _describeServerError(response.statusCode, body),
          statusCode: response.statusCode,
        );
      } on ApiException {
        rethrow;
      } on TimeoutException {
        if (attempt < retries) continue;
        throw const ApiException(
          'The AI is taking too long to respond. Please try again.',
        );
      } on SocketException {
        if (attempt < retries) continue;
        throw ApiException(
          'Can\'t reach the Learnly server at ${ApiConstants.baseUrl}. '
          'Check that the backend is running and you\'re online.',
        );
      } on http.ClientException catch (e) {
        if (attempt < retries) continue;
        throw ApiException('Network error: ${e.message}');
      } on FormatException {
        throw const ApiException('The server sent an unreadable response.');
      }
    }
  }

  String _describeServerError(int status, String body) {
    String? detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
    } catch (_) {}
    debugPrint('API error $status: ${detail ?? body}');
    if (status == 503) {
      return detail ?? 'The AI service is unavailable right now.';
    }
    if (status == 404) return detail ?? 'Not found.';
    return detail ?? 'Server error ($status). Please try again.';
  }

  Future<dynamic> _post(
    String url,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) {
    return _send(
      () => _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      timeout: timeout,
    );
  }

  Future<dynamic> _get(
    String url,
    Map<String, String> queryParams, {
    required Duration timeout,
  }) {
    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    return _send(
      () => _client.get(uri, headers: {'Content-Type': 'application/json'}),
      timeout: timeout,
    );
  }

  // 1. Generate Dynamic Syllabus
  Future<Syllabus> generateSyllabus({
    required String topic,
    required ExperienceLevel experienceLevel,
    required LearningStyle preferredLearningStyle,
    String? goals,
  }) async {
    final data = await _post(ApiConstants.generateSyllabus, {
      'topic': topic,
      'experience_level': experienceLevel.value,
      'preferred_learning_style': preferredLearningStyle.value,
      'goals_or_focus_areas': goals,
    }, timeout: _syllabusTimeout);
    final syllabus = Syllabus.fromJson(data);
    if (syllabus.modules.isEmpty) {
      throw const ApiException('The AI returned an empty syllabus. Try again.');
    }
    return syllabus;
  }

  // 2. Sync Live Web Trends
  Future<SyncTrendsResponse> syncTrends({
    required String syllabusId,
    required String topic,
    required List<String> currentModuleTitles,
  }) async {
    final data = await _post(ApiConstants.syncTrends, {
      'syllabus_id': syllabusId,
      'topic': topic,
      'current_module_titles': currentModuleTitles,
    }, timeout: _quizTimeout);
    return SyncTrendsResponse.fromJson(data);
  }

  // 3. Get Lesson Content
  Future<TopicLessonContent> getLessonContent({
    required String topic,
    required String moduleTitle,
    required String subtopicTitle,
    required LearningStyle style,
  }) async {
    final data = await _get(ApiConstants.getLesson, {
      'topic': topic,
      'module_title': moduleTitle,
      'subtopic_title': subtopicTitle,
      'style': style.value,
    }, timeout: _lessonTimeout);
    return TopicLessonContent.fromJson(data);
  }

  // 4. Ask the AI tutor
  Future<TutorChatMessage> askTutor({
    required String topic,
    required String subtopicTitle,
    required String lessonContext,
    required String studentMessage,
    required List<Map<String, String>> chatHistory,
    required LearningStyle style,
  }) async {
    final data = await _post(ApiConstants.chatTutor, {
      'topic': topic,
      'subtopic_title': subtopicTitle,
      'lesson_context': lessonContext,
      'student_message': studentMessage,
      'chat_history': chatHistory,
      'preferred_style': style.value,
    }, timeout: _chatTimeout);

    final reply = (data['reply_markdown'] as String?)?.trim() ?? '';
    if (reply.isEmpty) {
      throw const ApiException('The tutor returned an empty answer.');
    }
    return TutorChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'tutor',
      text: reply,
      followUpQuestions:
          (data['suggested_followup_questions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      citedResources:
          (data['cited_resources'] as List<dynamic>?)
              ?.map((e) => ResourceItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  // 5. Get Module Quiz
  Future<Quiz> getModuleQuiz({
    required String syllabusId,
    required String topic,
    required String moduleId,
    required String moduleTitle,
  }) async {
    final data = await _get(ApiConstants.getModuleQuiz, {
      'syllabus_id': syllabusId,
      'topic': topic,
      'module_id': moduleId,
      'module_title': moduleTitle,
    }, timeout: _quizTimeout);
    final quiz = Quiz.fromJson(data);
    if (quiz.questions.isEmpty) {
      throw const ApiException('The AI returned an empty quiz. Try again.');
    }
    return quiz;
  }

  // 6. Submit Quiz. Throws ApiException(statusCode: 404) if the server no
  // longer holds the quiz; callers can then grade locally.
  Future<QuizResultResponse> submitQuiz({
    required String quizId,
    required Map<String, int> selectedAnswers,
  }) async {
    final data = await _post(ApiConstants.submitQuiz, {
      'quiz_id': quizId,
      'selected_answers': selectedAnswers,
    }, timeout: _chatTimeout);
    return QuizResultResponse.fromJson(data);
  }

  // 7. Direct YouTube Video Search
  Future<List<ResourceItem>> searchYouTubeVideos({
    required String query,
    int maxResults = 4,
  }) async {
    try {
      final List<dynamic> data = await _get(ApiConstants.searchYouTube, {
        'query': query,
        'max_results': maxResults.toString(),
      }, timeout: _shortTimeout);
      return data.map((json) => ResourceItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('YouTube direct search exception: $e');
      return [];
    }
  }
}

final apiService = ApiService();
