import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../theme/app_colors.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.exerciseName,
  });

  final String videoUrl;
  final String exerciseName;

  static String? youtubeVideoId(String videoUrl) {
    final normalizedUrl = videoUrl.trim();
    if (normalizedUrl.isEmpty) return null;
    return YoutubePlayer.convertUrlToId(normalizedUrl);
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  static const _invalidVideoMessage =
      'Link de vídeo inválido ou não suportado.';

  YoutubePlayerController? _controller;

  String get _exerciseTitle {
    final normalizedName = widget.exerciseName.trim();
    return normalizedName.isEmpty ? 'Vídeo do exercício' : normalizedName;
  }

  @override
  void initState() {
    super.initState();
    final videoId = VideoPlayerPage.youtubeVideoId(widget.videoUrl);

    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: true,
          isLive: false,
          forceHD: false,
          enableCaption: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Center(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: _invalidVideoMessage,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _invalidVideoMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMain),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Center(
        child: YoutubePlayer(
          controller: controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: colors.primary,
          progressColors: ProgressBarColors(
            playedColor: colors.primary,
            handleColor: colors.primary,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textMain,
      title: Text(
        _exerciseTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
