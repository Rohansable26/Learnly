import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/syllabus.dart';
import '../models/trend_update.dart';
import '../services/api_service.dart';

/// The inputs used to generate a syllabus, kept so it can be regenerated.
class SyllabusRequest {
  final String topic;
  final ExperienceLevel level;
  final LearningStyle style;
  final String? goals;

  const SyllabusRequest({
    required this.topic,
    required this.level,
    required this.style,
    this.goals,
  });
}

class SyllabusState {
  final List<Syllabus> enrolledSyllabi;
  final Syllabus? activeSyllabus;
  final bool isLoading;
  final bool isSyncingTrends;
  final String? errorMessage;
  final SyncTrendsResponse? lastTrendSyncResult;

  /// A freshly generated syllabus awaiting the student's review. It is not
  /// enrolled until accepted.
  final Syllabus? pendingSyllabus;
  final SyllabusRequest? pendingRequest;

  SyllabusState({
    this.enrolledSyllabi = const [],
    this.activeSyllabus,
    this.isLoading = false,
    this.isSyncingTrends = false,
    this.errorMessage,
    this.lastTrendSyncResult,
    this.pendingSyllabus,
    this.pendingRequest,
  });

  SyllabusState copyWith({
    List<Syllabus>? enrolledSyllabi,
    Syllabus? activeSyllabus,
    bool? isLoading,
    bool? isSyncingTrends,
    String? errorMessage,
    SyncTrendsResponse? lastTrendSyncResult,
    Syllabus? pendingSyllabus,
    SyllabusRequest? pendingRequest,
    bool clearPending = false,
  }) {
    return SyllabusState(
      enrolledSyllabi: enrolledSyllabi ?? this.enrolledSyllabi,
      activeSyllabus: activeSyllabus ?? this.activeSyllabus,
      isLoading: isLoading ?? this.isLoading,
      isSyncingTrends: isSyncingTrends ?? this.isSyncingTrends,
      errorMessage: errorMessage,
      lastTrendSyncResult: lastTrendSyncResult ?? this.lastTrendSyncResult,
      pendingSyllabus: clearPending
          ? null
          : (pendingSyllabus ?? this.pendingSyllabus),
      pendingRequest: clearPending
          ? null
          : (pendingRequest ?? this.pendingRequest),
    );
  }
}

class SyllabusNotifier extends Notifier<SyllabusState> {
  static const String _storageKey = 'learnly_enrolled_syllabi';

  @override
  SyllabusState build() {
    _loadSavedData();
    return SyllabusState();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_storageKey);
      if (savedStr != null) {
        final List<dynamic> decoded = jsonDecode(savedStr);
        final list = decoded.map((e) => Syllabus.fromJson(e)).toList();
        if (list.isNotEmpty) {
          state = state.copyWith(
            enrolledSyllabi: list,
            activeSyllabus: list.first,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading saved syllabi: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(
        state.enrolledSyllabi.map((s) => s.toJson()).toList(),
      );
      await prefs.setString(_storageKey, str);
    } catch (e) {
      debugPrint('Error persisting syllabi: $e');
    }
  }

  void setActiveSyllabus(Syllabus syllabus) {
    state = state.copyWith(activeSyllabus: syllabus);
  }

  /// Generates a syllabus and stages it for preview. Nothing is enrolled yet.
  Future<void> createNewSyllabus({
    required String topic,
    required ExperienceLevel level,
    required LearningStyle style,
    String? goals,
  }) async {
    final request = SyllabusRequest(
      topic: topic,
      level: level,
      style: style,
      goals: goals,
    );
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      pendingRequest: request,
    );
    try {
      final generated = await apiService.generateSyllabus(
        topic: topic,
        experienceLevel: level,
        preferredLearningStyle: style,
        goals: goals,
      );
      state = state.copyWith(isLoading: false, pendingSyllabus: generated);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e is ApiException
            ? e.message
            : 'Failed to generate syllabus. Please try again.',
      );
    }
  }

  /// Regenerates the staged syllabus with the same inputs.
  Future<void> regeneratePending() async {
    final request = state.pendingRequest;
    if (request == null) return;
    await createNewSyllabus(
      topic: request.topic,
      level: request.level,
      style: request.style,
      goals: request.goals,
    );
  }

  /// Enrolls the previewed syllabus and makes it the active roadmap.
  Future<void> acceptPendingSyllabus() async {
    final pending = state.pendingSyllabus;
    if (pending == null) return;
    state = state.copyWith(
      enrolledSyllabi: [pending, ...state.enrolledSyllabi],
      activeSyllabus: pending,
      clearPending: true,
    );
    await _persist();
  }

  void discardPendingSyllabus() {
    state = state.copyWith(clearPending: true);
  }

  // Live Web Scraping & Trend Sync
  Future<void> syncLiveTrends() async {
    final active = state.activeSyllabus;
    if (active == null) return;

    state = state.copyWith(isSyncingTrends: true);
    try {
      final moduleTitles = active.modules.map((m) => m.title).toList();
      final trendResponse = await apiService.syncTrends(
        syllabusId: active.id,
        topic: active.topic,
        currentModuleTitles: moduleTitles,
      );

      // If new trends found, augment the active syllabus
      if (trendResponse.newTrendsFound && trendResponse.updates.isNotEmpty) {
        final update = trendResponse.updates.first;
        if (update.suggestedSubtopicAddition != null) {
          final updatedModules = active.modules.map((m) {
            if (m.id == update.affectedModuleId) {
              final existingSubtopics = List<Subtopic>.from(m.subtopics);
              if (!existingSubtopics.any(
                (s) => s.id == update.suggestedSubtopicAddition!.id,
              )) {
                existingSubtopics.add(update.suggestedSubtopicAddition!);
              }
              return Module(
                id: m.id,
                title: m.title,
                summary: m.summary,
                orderIndex: m.orderIndex,
                subtopics: existingSubtopics,
                quizId: m.quizId,
                isUnlocked: m.isUnlocked,
                isPassed: m.isPassed,
              );
            }
            return m;
          }).toList();

          final updatedSyllabus = Syllabus(
            id: active.id,
            topic: active.topic,
            userExperienceLevel: active.userExperienceLevel,
            primaryLearningStyle: active.primaryLearningStyle,
            industryStandardsSummary: active.industryStandardsSummary,
            latestTrendsIdentified: [
              update.detectedTrendTitle,
              ...active.latestTrendsIdentified,
            ],
            modules: updatedModules,
            createdAt: active.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
          );

          final updatedEnrolled = state.enrolledSyllabi
              .map((s) => s.id == updatedSyllabus.id ? updatedSyllabus : s)
              .toList();

          state = state.copyWith(
            activeSyllabus: updatedSyllabus,
            enrolledSyllabi: updatedEnrolled,
            isSyncingTrends: false,
            lastTrendSyncResult: trendResponse,
          );
          await _persist();
          return;
        }
      }

      state = state.copyWith(
        isSyncingTrends: false,
        lastTrendSyncResult: trendResponse,
      );
    } catch (e) {
      state = state.copyWith(isSyncingTrends: false);
    }
  }

  void markSubtopicCompleted(String moduleId, String subtopicId) {
    final active = state.activeSyllabus;
    if (active == null) return;

    final updatedModules = active.modules.map((m) {
      if (m.id == moduleId) {
        final updatedSubtopics = m.subtopics.map((s) {
          if (s.id == subtopicId) {
            s.isCompleted = true;
          }
          return s;
        }).toList();

        return Module(
          id: m.id,
          title: m.title,
          summary: m.summary,
          orderIndex: m.orderIndex,
          subtopics: updatedSubtopics,
          quizId: m.quizId,
          isUnlocked: m.isUnlocked,
          isPassed: m.isPassed,
        );
      }
      return m;
    }).toList();

    final updatedSyllabus = Syllabus(
      id: active.id,
      topic: active.topic,
      userExperienceLevel: active.userExperienceLevel,
      primaryLearningStyle: active.primaryLearningStyle,
      industryStandardsSummary: active.industryStandardsSummary,
      latestTrendsIdentified: active.latestTrendsIdentified,
      modules: updatedModules,
      createdAt: active.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final updatedEnrolled = state.enrolledSyllabi
        .map((s) => s.id == updatedSyllabus.id ? updatedSyllabus : s)
        .toList();

    state = state.copyWith(
      activeSyllabus: updatedSyllabus,
      enrolledSyllabi: updatedEnrolled,
    );
    _persist();
  }

  void markModulePassedAndUnlockNext(String moduleId) {
    final active = state.activeSyllabus;
    if (active == null) return;

    int passedIndex = -1;
    for (int i = 0; i < active.modules.length; i++) {
      if (active.modules[i].id == moduleId) {
        passedIndex = i;
        break;
      }
    }

    final updatedModules = active.modules.asMap().entries.map((entry) {
      final index = entry.key;
      final m = entry.value;

      if (index == passedIndex) {
        m.isPassed = true;
      } else if (index == passedIndex + 1) {
        m.isUnlocked = true;
      }
      return m;
    }).toList();

    final updatedSyllabus = Syllabus(
      id: active.id,
      topic: active.topic,
      userExperienceLevel: active.userExperienceLevel,
      primaryLearningStyle: active.primaryLearningStyle,
      industryStandardsSummary: active.industryStandardsSummary,
      latestTrendsIdentified: active.latestTrendsIdentified,
      modules: updatedModules,
      createdAt: active.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final updatedEnrolled = state.enrolledSyllabi
        .map((s) => s.id == updatedSyllabus.id ? updatedSyllabus : s)
        .toList();

    state = state.copyWith(
      activeSyllabus: updatedSyllabus,
      enrolledSyllabi: updatedEnrolled,
    );
    _persist();
  }
}

final syllabusProvider = NotifierProvider<SyllabusNotifier, SyllabusState>(
  SyllabusNotifier.new,
);
