import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class TimerService extends ChangeNotifier {
  // Padrão Singleton
  static final TimerService instance = TimerService._();
  TimerService._();

  Timer? _timer;
  
  // Variáveis privadas (ninguém mexe nelas diretamente fora daqui)
  int _secondsRemaining = 0;
  bool _isActive = false;

  // Getters públicos (para a UI ler os valores)
  int get secondsRemaining => _secondsRemaining;
  bool get isActive => _isActive;

  // Formata o tempo para texto (ex: "01:30")
  String get formattedTime {
    final int min = _secondsRemaining ~/ 60;
    final int sec = _secondsRemaining % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // INICIA O CRONÔMETRO
  void start(int seconds) {
    _timer?.cancel(); // Garante limpeza anterior
    
    _secondsRemaining = seconds;
    _isActive = true;
    notifyListeners(); // Avisa a UI para mostrar a barra

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners(); // Atualiza os números na tela
      } else {
        // Acabou o tempo
        _finalizarComVibracao();
      }
    });
  }

  // PARA O CRONÔMETRO (Botão Fechar ou quando acaba)
  void stop() {
    _timer?.cancel();
    _isActive = false;
    _secondsRemaining = 0;
    notifyListeners(); // Avisa a UI para esconder a barra
  }

  // ADICIONA MAIS TEMPO (Botão +10s)
  void addTime(int seconds) {
    if (_isActive) {
      _secondsRemaining += seconds;
      notifyListeners();
    }
  }

  // Lógica de vibração separada
  Future<void> _finalizarComVibracao() async {
    stop(); // Para o contador visualmente

    // Tenta vibrar (verifica se o dispositivo suporta)
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Padrão: Espera 0ms, Vibra 500ms, Pausa 200ms, Vibra 500ms
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (e) {
      debugPrint("Erro ao vibrar: $e"); // Evita crash em emuladores ou dispositivos sem motor
    }
  }
}