import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/syllabus.dart';

/// Plays a YouTube video inside the app using YouTube's official IFrame player.
/// The player's built-in fullscreen button handles fullscreen + rotation.
class YoutubePlayerScreen extends StatefulWidget {
  final String videoId;
  final ResourceItem video;

  const YoutubePlayerScreen({
    super.key,
    required this.videoId,
    required this.video,
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> _openInYouTube() async {
    final uri = Uri.parse(widget.video.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final player = YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
    return Scaffold(
      appBar: AppBar(
        title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open in YouTube',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInYouTube,
          ),
        ],
      ),
      body: ListView(
        children: [
          player,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.title, style: context.text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  [
                    v.authorOrChannel,
                    v.publishedDate,
                  ].whereType<String>().join(' · '),
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(v.snippet, style: context.text.bodyMedium),
                if (v.keyTakeaways.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Key takeaways', style: context.text.titleSmall),
                  const SizedBox(height: 8),
                  ...v.keyTakeaways.map(
                    (k) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(k, style: context.text.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _openInYouTube,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in YouTube'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
