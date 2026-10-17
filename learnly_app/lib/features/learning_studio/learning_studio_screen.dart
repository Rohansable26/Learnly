import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/syllabus.dart';
import '../../models/lesson_content.dart';
import '../../providers/learning_provider.dart';
import '../../providers/syllabus_provider.dart';
import '../quiz/quiz_screen.dart';
import 'widgets/flashcard_deck_view.dart';
import 'widgets/youtube_player_screen.dart';

class LearningStudioScreen extends ConsumerStatefulWidget {
  final String syllabusId;
  final String topic;
  final String moduleId;
  final String moduleTitle;
  final Subtopic subtopic;

  const LearningStudioScreen({
    super.key,
    required this.syllabusId,
    required this.topic,
    required this.moduleId,
    required this.moduleTitle,
    required this.subtopic,
  });

  static Future<void> navigate(
    BuildContext context, {
    required String syllabusId,
    required String topic,
    required String moduleId,
    required String moduleTitle,
    required Subtopic subtopic,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningStudioScreen(
          syllabusId: syllabusId,
          topic: topic,
          moduleId: moduleId,
          moduleTitle: moduleTitle,
          subtopic: subtopic,
        ),
      ),
    );
  }

  @override
  ConsumerState<LearningStudioScreen> createState() =>
      _LearningStudioScreenState();
}

class _LearningStudioScreenState extends ConsumerState<LearningStudioScreen> {
  final _doubtController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickPrompts = [
    'Explain with an analogy',
    'What are common production pitfalls?',
    'Write a unit test for this',
    'How to optimize for sub-50ms latency?',
    'Contrast with traditional architectures',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(learningProvider.notifier)
          .loadLesson(
            topic: widget.topic,
            moduleTitle: widget.moduleTitle,
            subtopicTitle: widget.subtopic.title,
          );
    });
  }

  @override
  void dispose() {
    _doubtController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? textToSend]) {
    final text = textToSend ?? _doubtController.text.trim();
    if (text.isEmpty) return;

    if (textToSend == null) {
      _doubtController.clear();
    }

    ref
        .read(learningProvider.notifier)
        .sendStudentMessage(
          topic: widget.topic,
          subtopicTitle: widget.subtopic.title,
          studentText: text,
        );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markCompleted() {
    ref
        .read(syllabusProvider.notifier)
        .markSubtopicCompleted(widget.moduleId, widget.subtopic.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Marked as complete. The module quiz is ready when you are.',
        ),
      ),
    );
  }

  void _openQuiz() {
    QuizScreen.navigate(
      context,
      syllabusId: widget.syllabusId,
      topic: widget.topic,
      moduleId: widget.moduleId,
      moduleTitle: widget.moduleTitle,
    );
  }

  String? _getYouTubeVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (url.contains('youtu.be/')) {
        return url.split('youtu.be/').last.split('?').first.split('&').first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Plays YouTube videos in-app; anything that isn't a single video
  /// (e.g. a YouTube search-results fallback link) opens externally.
  void _playVideo(ResourceItem v) {
    final videoId = _getYouTubeVideoId(v.url);
    if (videoId == null || videoId.isEmpty) {
      _openUrl(v.url);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubePlayerScreen(videoId: videoId, video: v),
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Couldn\'t open $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtopic.title,
              style: context.text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.moduleTitle,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Module quiz',
            icon: const Icon(Icons.quiz_outlined),
            onPressed: _openQuiz,
          ),
          IconButton(
            tooltip: 'Mark complete',
            isSelected: widget.subtopic.isCompleted,
            icon: const Icon(Icons.check_circle_outline),
            selectedIcon: Icon(
              Icons.check_circle,
              color: context.status.success,
            ),
            onPressed: _markCompleted,
          ),
        ],
      ),
      body: state.isLoading
          ? const EmptyState(
              loading: true,
              icon: Icons.auto_awesome,
              title: 'Preparing your lesson',
              message:
                  'Pulling explanations, videos and papers for this topic.',
            )
          : Column(
              children: [
                _buildFormatSelector(state.activeStyle),
                const Divider(),
                Expanded(child: _buildCurrentView(state)),
              ],
            ),
    );
  }

  Widget _buildFormatSelector(LearningStyle currentStyle) {
    const formats = [
      (LearningStyle.chatTutor, Icons.forum_outlined, 'AI tutor'),
      (LearningStyle.handsOn, Icons.style_outlined, 'Flashcards'),
      (LearningStyle.videoLecture, Icons.play_circle_outline, 'Videos'),
      (LearningStyle.researchPaper, Icons.menu_book_outlined, 'Papers'),
      (LearningStyle.deepArticle, Icons.article_outlined, 'Article'),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: formats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (style, icon, label) = formats[i];
          final isSelected =
              currentStyle == style ||
              (currentStyle == LearningStyle.balancedHybrid &&
                  style == LearningStyle.chatTutor);
          return FilterChip(
            avatar: isSelected ? null : Icon(icon, size: 18),
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                ref.read(learningProvider.notifier).switchFormat(style);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildCurrentView(LearningState state) {
    switch (state.activeStyle) {
      case LearningStyle.handsOn:
        return FlashcardDeckView(
          flashcards: state.lessonContent?.flashcards ?? [],
          onAllMastered: _markCompleted,
        );
      case LearningStyle.videoLecture:
        return _buildVideoView(state.lessonContent);
      case LearningStyle.researchPaper:
        return _buildPaperView(state.lessonContent);
      case LearningStyle.deepArticle:
        return _buildArticleView(state.lessonContent);
      case LearningStyle.chatTutor:
      case LearningStyle.balancedHybrid:
        return _buildChatTutorView(state);
    }
  }

  MarkdownStyleSheet _markdownStyle({Color? textColor, double fontScale = 1}) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return base.copyWith(
      p: context.text.bodyLarge?.copyWith(
        color: textColor,
        fontSize: 15 * fontScale,
      ),
      listBullet: context.text.bodyLarge?.copyWith(color: textColor),
      h1: context.text.headlineSmall,
      h2: context.text.titleLarge,
      h3: context.text.titleMedium,
      code: GoogleFonts.firaCode(
        fontSize: 13,
        color: context.colors.onSurface,
        backgroundColor: context.colors.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      blockquoteDecoration: BoxDecoration(
        color: context.colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // View 1: AI tutor chat
  Widget _buildChatTutorView(LearningState state) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.chatMessages.length,
            itemBuilder: (ctx, idx) {
              final msg = state.chatMessages[idx];
              final isTutor = msg.isTutor;
              final bubbleColor = isTutor
                  ? context.colors.surfaceContainerHigh
                  : context.colors.primary;
              final textColor = isTutor
                  ? context.colors.onSurface
                  : context.colors.onPrimary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: isTutor
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.end,
                  children: [
                    if (isTutor) ...[
                      const IconBadge(
                        icon: Icons.psychology_outlined,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isTutor ? 4 : 20),
                            bottomRight: Radius.circular(isTutor ? 20 : 4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              data: msg.text,
                              styleSheet: _markdownStyle(
                                textColor: textColor,
                                fontScale: 14 / 15,
                              ),
                            ),
                            if (isTutor &&
                                !msg.isError &&
                                !msg.id.startsWith('intro_')) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg.fromCache) ...[
                                    Icon(
                                      Icons.history,
                                      size: 14,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'From your history',
                                      style: context.text.labelSmall?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (!state.isSendingMessage)
                                    IconButton(
                                      tooltip: 'Regenerate answer',
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 18,
                                      icon: const Icon(Icons.refresh),
                                      onPressed: () => ref
                                          .read(learningProvider.notifier)
                                          .regenerateAnswer(
                                            topic: widget.topic,
                                            subtopicTitle:
                                                widget.subtopic.title,
                                            tutorMessageIndex: idx,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                            if (msg.followUpQuestions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Follow-up questions',
                                style: context.text.labelMedium?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: msg.followUpQuestions
                                    .map(
                                      (q) => ActionChip(
                                        label: Text(q),
                                        backgroundColor: context.colors.surface,
                                        onPressed: () => _sendMessage(q),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Quick prompts
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _quickPrompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => ActionChip(
              label: Text(_quickPrompts[i]),
              onPressed: () => _sendMessage(_quickPrompts[i]),
            ),
          ),
        ),

        // Input bar
        Material(
          color: context.colors.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _doubtController,
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ask a question…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: context.colors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: state.isSendingMessage
                        ? null
                        : () => _sendMessage(),
                    icon: state.isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // View 2: Videos
  Widget _buildVideoView(TopicLessonContent? content) {
    final videos = content?.recommendedVideos ?? [];
    if (videos.isEmpty) {
      return const EmptyState(
        icon: Icons.videocam_off_outlined,
        title: 'No videos found',
        message: 'We couldn\'t find videos for this topic yet.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (ctx, idx) {
        final v = videos[idx];
        final videoId = _getYouTubeVideoId(v.url);

        return Card(
          child: InkWell(
            onTap: () => _playVideo(v),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (videoId != null && videoId.isNotEmpty)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: context.colors.surfaceContainerHighest,
                                child: Icon(
                                  Icons.video_library_outlined,
                                  size: 48,
                                  color: context.colors.outline,
                                ),
                              ),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.title,
                        style: context.text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          v.authorOrChannel,
                          v.publishedDate,
                        ].whereType<String>().join(' · '),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        v.snippet,
                        style: context.text.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _playVideo(v),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Watch'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // View 3: Research papers
  Widget _buildPaperView(TopicLessonContent? content) {
    final papers = content?.researchPapers ?? [];
    if (papers.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No papers found',
        message: 'We couldn\'t find research papers for this subtopic.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: papers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final p = papers[idx];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(
                      icon: Icons.description_outlined,
                      tone: Tone.tertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: context.text.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${p.authorOrChannel ?? "arXiv"} · ${p.publishedDate ?? "Recent"}',
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Abstract', style: context.text.labelLarge),
                const SizedBox(height: 4),
                Text(p.snippet, style: context.text.bodyMedium),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openUrl(p.url),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Read paper'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // View 4: In-depth article + code
  Widget _buildArticleView(TopicLessonContent? content) {
    if (content == null) {
      return const EmptyState(
        loading: true,
        icon: Icons.article_outlined,
        title: 'Loading article',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        MarkdownBody(
          data: content.coreMarkdownContent,
          styleSheet: _markdownStyle(),
        ),
        const SizedBox(height: 24),
        ...content.codeSnippets.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card.filled(
              color: context.colors.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            style: context.text.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InfoTag(label: c.language.toUpperCase()),
                        IconButton(
                          tooltip: 'Copy code',
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: c.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      c.code,
                      style: GoogleFonts.firaCode(
                        fontSize: 13,
                        height: 1.5,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _openQuiz,
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Take the module quiz'),
        ),
      ],
    );
  }
}
