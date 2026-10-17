import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learnly_app/main.dart';
import 'package:learnly_app/models/syllabus.dart';
import 'package:learnly_app/features/syllabus/syllabus_screen.dart';
import 'package:learnly_app/features/quiz/quiz_screen.dart';
import 'package:learnly_app/features/profile/student_profile_sheet.dart';
import 'package:learnly_app/features/trends/trend_radar_sheet.dart';
import 'package:learnly_app/features/onboarding/new_topic_sheet.dart';
import 'package:learnly_app/features/learning_studio/learning_studio_screen.dart';
import 'package:learnly_app/features/recall/recall_center_screen.dart';
import 'package:learnly_app/features/analytics/analytics_screen.dart';

import 'package:learnly_app/features/learning_studio/widgets/flashcard_deck_view.dart';
import 'package:learnly_app/models/flashcard.dart';

void main() {
  testWidgets('HomeScreen mobile viewport RenderFlex test (360x780)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: LearnlyApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Learnly AI'), findsOneWidget);
  });

  testWidgets('SyllabusScreen, Recall & Analytics mobile viewport RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: RecallCenterScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AnalyticsScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SyllabusScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('StudentProfileSheet mobile viewport test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: StudentProfileSheet()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('TrendRadarSheet mobile viewport test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: TrendRadarSheet()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('NewTopicSheet mobile viewport test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: NewTopicSheet()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('QuizScreen and FlashcardDeckView mobile viewport test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuizScreen(
            syllabusId: 'syl_1',
            topic: 'Advanced Retrieval-Augmented Generation (RAG)',
            moduleId: 'mod_1',
            moduleTitle: 'Advanced Vector Indexing & HNSW Graph Partitioning',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FlashcardDeckView(
              flashcards: [
                Flashcard(
                  id: 'fc_1',
                  question: 'What is the primary trade-off in HNSW indexing parameter M?',
                  answer: 'Higher M increases recall and graph connectivity at the cost of higher memory footprint and index build time.',
                  keyConcept: 'Hierarchical Navigable Small World Graphs',
                ),
              ],
              onAllMastered: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('LearningStudioScreen mobile viewport test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LearningStudioScreen(
            syllabusId: 'syl_1',
            topic: 'Advanced RAG Systems Architecture',
            moduleId: 'mod_1',
            moduleTitle: 'Vector Indexing & Hybrid Search',
            subtopic: Subtopic(
              id: 'sub_1',
              title: 'HNSW Graph Indexing & Distance Metrics',
              description: 'Deep dive into hierarchical navigable small world graphs.',
              estimatedMinutes: 25,
              resources: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Ultra-narrow 320dp HomeScreen RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(child: LearnlyApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Learnly AI'), findsOneWidget);
  });

  testWidgets('Ultra-narrow 320dp NewTopicSheet RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: NewTopicSheet()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Intermediate'), findsOneWidget);
  });

  testWidgets('Ultra-narrow 320dp TrendRadarSheet RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: TrendRadarSheet()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Trend radar'), findsOneWidget);
  });

  testWidgets('Ultra-narrow 320dp StudentProfileSheet RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: StudentProfileSheet()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Ultra-narrow 320dp FlashcardDeckView RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FlashcardDeckView(
              flashcards: [
                Flashcard(
                  id: 'fc_1',
                  question: 'Question 1',
                  answer: 'Answer 1',
                  keyConcept: 'Concept 1',
                ),
                Flashcard(
                  id: 'fc_2',
                  question: 'Question 2 with longer text explanation trade-offs',
                  answer: 'Answer 2',
                  keyConcept: 'Concept 2 Long Title',
                ),
              ],
              onAllMastered: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Review later'), findsOneWidget);
  });

  testWidgets('Ultra-narrow 320dp Syllabus, Recall, Analytics, Quiz & Studio RenderFlex test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. SyllabusScreen
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SyllabusScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 2. RecallCenterScreen
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: RecallCenterScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 3. AnalyticsScreen
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AnalyticsScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 4. QuizScreen
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuizScreen(
            syllabusId: 'syl_1',
            topic: 'Advanced Retrieval-Augmented Generation (RAG)',
            moduleId: 'mod_1',
            moduleTitle: 'Advanced Vector Indexing & HNSW Graph Partitioning',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 5. LearningStudioScreen
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LearningStudioScreen(
            syllabusId: 'syl_1',
            topic: 'Advanced RAG Systems Architecture',
            moduleId: 'mod_1',
            moduleTitle: 'Vector Indexing & Hybrid Search',
            subtopic: Subtopic(
              id: 'sub_1',
              title: 'HNSW Graph Indexing & Distance Metrics',
              description: 'Deep dive into hierarchical navigable small world graphs.',
              estimatedMinutes: 25,
              resources: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Large accessibility font zoom (1.3x) on Analytics and HomeScreen format cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. AnalyticsScreen with 1.3x text zoom
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(body: AnalyticsScreen()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 2. HomeScreen with full format cards and feed with 1.3x text zoom
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: LearnlyApp(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll down to format cards and live feed to trigger layout
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 200));
  });
}

