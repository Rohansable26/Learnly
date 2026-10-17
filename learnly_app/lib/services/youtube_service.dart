import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/syllabus.dart';

/// Searches YouTube directly from the device via the YouTube Data API v3,
/// so videos work without the Learnly backend running.
///
/// The key is supplied at build time (never hardcoded):
///   flutter run --dart-define-from-file=config/keys.json
/// where config/keys.json contains {"YOUTUBE_API_KEY": "AIza..."}.
class YouTubeService {
  static const String _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String _searchUrl =
      'https://www.googleapis.com/youtube/v3/search';

  final http.Client _client = http.Client();

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Returns up to [maxResults] embeddable tutorial videos for [query],
  /// or an empty list if no key is configured or the request fails.
  Future<List<ResourceItem>> searchLearningVideos(
    String query, {
    int maxResults = 3,
  }) async {
    if (!isConfigured) return [];

    final params = {
      'key': _apiKey,
      'q': '$query tutorial',
      'part': 'snippet',
      'type': 'video',
      'maxResults': '$maxResults',
      'relevanceLanguage': 'en',
      'videoDuration': 'medium', // 4–20 min
      'videoEmbeddable': 'true',
      'safeSearch': 'strict',
      'order': 'relevance',
    };

    try {
      var items = await _search(params);
      // Niche topics may have no medium-length videos; retry without the filter.
      if (items.isEmpty) {
        params.remove('videoDuration');
        items = await _search(params);
      }
      return items
          .map((item) => _toResource(item, query))
          .whereType<ResourceItem>()
          .toList();
    } catch (e) {
      debugPrint('YouTube search failed: $e');
      return [];
    }
  }

  Future<List<dynamic>> _search(Map<String, String> params) async {
    final uri = Uri.parse(_searchUrl).replace(queryParameters: params);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>?) ?? [];
  }

  ResourceItem? _toResource(dynamic item, String query) {
    final videoId = item['id']?['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;
    final snippet = (item['snippet'] as Map<String, dynamic>?) ?? {};
    final description = _unescape(snippet['description'] as String? ?? '');

    return ResourceItem(
      id: 'yt_$videoId',
      title: _unescape(snippet['title'] as String? ?? '$query tutorial'),
      type: 'video',
      url: 'https://www.youtube.com/watch?v=$videoId',
      snippet: description.isNotEmpty
          ? description
          : 'Video tutorial on $query.',
      sourceName: 'YouTube',
      authorOrChannel: _unescape(snippet['channelTitle'] as String? ?? ''),
      publishedDate: (snippet['publishedAt'] as String? ?? '').split('T').first,
      keyTakeaways: const [],
    );
  }

  /// The API HTML-escapes titles/descriptions (e.g. `&#39;`, `&amp;`).
  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

final youTubeService = YouTubeService();
