import 'syllabus.dart';

class TrendUpdate {
  final String detectedTrendTitle;
  final String summary;
  final String? affectedModuleId;
  final Subtopic? suggestedSubtopicAddition;
  final List<ResourceItem> sources;

  TrendUpdate({
    required this.detectedTrendTitle,
    required this.summary,
    this.affectedModuleId,
    this.suggestedSubtopicAddition,
    required this.sources,
  });

  factory TrendUpdate.fromJson(Map<String, dynamic> json) {
    return TrendUpdate(
      detectedTrendTitle: json['detected_trend_title'] ?? '',
      summary: json['summary'] ?? '',
      affectedModuleId: json['affected_module_id'],
      suggestedSubtopicAddition: json['suggested_subtopic_addition'] != null
          ? Subtopic.fromJson(json['suggested_subtopic_addition'])
          : null,
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((s) => ResourceItem.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class SyncTrendsResponse {
  final String syllabusId;
  final bool newTrendsFound;
  final List<TrendUpdate> updates;
  final String updateMessage;

  SyncTrendsResponse({
    required this.syllabusId,
    required this.newTrendsFound,
    required this.updates,
    required this.updateMessage,
  });

  factory SyncTrendsResponse.fromJson(Map<String, dynamic> json) {
    return SyncTrendsResponse(
      syllabusId: json['syllabus_id'] ?? '',
      newTrendsFound: json['new_trends_found'] ?? false,
      updates:
          (json['updates'] as List<dynamic>?)
              ?.map((u) => TrendUpdate.fromJson(u))
              .toList() ??
          [],
      updateMessage: json['update_message'] ?? '',
    );
  }
}
