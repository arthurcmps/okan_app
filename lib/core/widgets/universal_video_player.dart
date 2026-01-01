import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class UniversalVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const UniversalVideoPlayer({super.key, required this.videoUrl});

  @override
  State<UniversalVideoPlayer> createState() => _UniversalVideoPlayerState();
}

class _UniversalVideoPlayerState extends State<UniversalVideoPlayer> {
  // Controladores
  YoutubePlayerController? _youtubeController;
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;

  bool _isYoutube = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _inicializarPlayer();
  }

  void _inicializarPlayer() {
    // 1. Tenta identificar se é YouTube
    final String? videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId != null) {
      // É YouTube!
      _isYoutube = true;
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );
    } else {
      // 2. Assume que é um MP4/Link Direto
      _isYoutube = false;
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      _videoPlayerController!.initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: true,
            looping: true,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            errorBuilder: (context, errorMessage) {
              return Center(child: Text("Erro no vídeo: $errorMessage", style: const TextStyle(color: Colors.white)));
            },
          );
        });
      }).catchError((error) {
        setState(() => _isError = true);
        debugPrint("Erro ao carregar vídeo: $error");
      });
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return const Center(child: Text("Não foi possível carregar o vídeo.", style: TextStyle(color: Colors.white)));
    }

    if (_isYoutube) {
      // Player do YouTube
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blue,
        ),
        builder: (context, player) {
          return player;
        },
      );
    } else {
      // Player Nativo (Chewie)
      if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
        return Chewie(controller: _chewieController!);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }
  }
}