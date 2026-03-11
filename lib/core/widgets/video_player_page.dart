import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/theme/app_colors.dart'; // Ajuste o caminho das suas cores

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
    // A mágica: esse comando extrai o ID do vídeo a partir de qualquer link do youtube
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true, // Já começa tocando
          mute: false,
          disableDragSeek: false,
          loop: true, // Fica repetindo a execução
          isLive: false,
          forceHD: false,
          enableCaption: false,
        ),
      );
    } else {
      _isError = true;
    }
  }

  @override
  void dispose() {
    if (!_isError) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.exerciseName)),
        body: const Center(child: Text("Link de vídeo inválido.", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Fundo preto fica mais cinemático
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
          progressIndicatorColor: AppColors.primary, // A barrinha de progresso na sua cor neon!
          progressColors: const ProgressBarColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
          ),
          onReady: () {
            // Opcional: fazer algo quando o vídeo carrega
          },
        ),
      ),
    );
  }
}