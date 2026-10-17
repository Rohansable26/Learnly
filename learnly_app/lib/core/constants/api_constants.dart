class ApiConstants {
  /// The hosted Learnly backend on Render. Override at launch to point at a
  /// local server instead, e.g.
  /// `flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1`
  static const String _override = String.fromEnvironment('API_BASE_URL');
  static const String _hosted = 'https://learnly-api.onrender.com/api/v1';

  static String get baseUrl => _override.isNotEmpty ? _override : _hosted;

  static String get generateSyllabus => '$baseUrl/syllabus/generate';
  static String get syncTrends => '$baseUrl/syllabus/sync-trends';
  static String get getLesson => '$baseUrl/learn/lesson';
  static String get chatTutor => '$baseUrl/learn/chat-tutor';
  static String get getModuleQuiz => '$baseUrl/quiz/module';
  static String get submitQuiz => '$baseUrl/quiz/submit';
  static String get searchYouTube => '$baseUrl/videos/youtube';
  static String get getAiInfo => '$baseUrl/ai/info';
}
