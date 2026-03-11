import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String exerciseName;

  const VideoPlayerPage({super.key, required this.videoUrl, required this.exerciseName});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Extrai o ID do vídeo (funciona com link normal ou encurtado do youtube)
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true, 
          loop: true, // Fica repetindo para o aluno ver a execução
          mute: false,
        ),
      );
    } else {
      _isError = true;
    }
  }

  @override
  void dispose() {
    if (!_isError) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(widget.exerciseName)),
        body: const Center(child: Text("Link de vídeo inválido ou não suportado.", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Fundo preto para dar imersão
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(widget.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.primary,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}