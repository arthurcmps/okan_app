import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class TimerService extends ChangeNotifier {
  // Padrão Singleton
  static final TimerService instance = TimerService._();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;
  DateTime? _endTime;
  
  int _secondsRemaining = 0;
  bool _isActive = false;

  TimerService._() {
    // --- O SEGREDO ESTÁ AQUI ---
    // Avisa o telemóvel para tratar este som como um ALARME e não como Mídia.
    _configurarAudioPlayer();
  }

Future<void> _configurarAudioPlayer() async {
    await _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.alarm, 
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback, // <-- CORRIGIDO PARA PLAYBACK
        options: const { // <-- CORRIGIDO DE COLCHETES [ ] PARA CHAVES { } (Set)
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
        },
      ),
    ));
  }

  int get secondsRemaining => _secondsRemaining;
  bool get isActive => _isActive;

  String get formattedTime {
    final int min = _secondsRemaining ~/ 60;
    final int sec = _secondsRemaining % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void start(int seconds) {
    _timer?.cancel(); 
    
    _secondsRemaining = seconds;
    _isActive = true;
    _endTime = DateTime.now().add(Duration(seconds: seconds));
    
    notifyListeners(); 

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      
      if (_endTime != null && _endTime!.isAfter(now)) {
        _secondsRemaining = _endTime!.difference(now).inSeconds;
        notifyListeners(); 
      } else {
        _finalizarComVibracaoESom();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _isActive = false;
    _secondsRemaining = 0;
    _endTime = null;
    notifyListeners(); 
  }

  void addTime(int seconds) {
    if (_isActive && _endTime != null) {
      _endTime = _endTime!.add(Duration(seconds: seconds));
      _secondsRemaining = _endTime!.difference(DateTime.now()).inSeconds;
      notifyListeners();
    }
  }

  Future<void> _finalizarComVibracaoESom() async {
    stop(); 

    // 1. Tocar o Som (agora mascarado como Alarme do Sistema)
    try {
      await _audioPlayer.play(AssetSource('sounds/alarme.mp3'));
    } catch (e) {
      debugPrint("Erro ao tocar áudio: $e");
    }

    // 2. Vibrar
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (e) {
      debugPrint("Erro ao vibrar: $e"); 
    }
  }
}