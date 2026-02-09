import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart'; // <--- Importante para vibrar

class TimerService extends ChangeNotifier {
  // Singleton: Garante que só existe UM cronômetro no app todo
  static final TimerService instance = TimerService._();
  TimerService._(); // Construtor privado

  Timer? _timer;
  int secondsRemaining = 0;
  bool isActive = false;

  // Inicia o cronômetro com X segundos
  void start(int seconds) {
    _timer?.cancel(); // Cancela se já tiver um rodando
    secondsRemaining = seconds;
    isActive = true;
    notifyListeners(); // Avisa a tela para aparecer a barra

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 0) {
        secondsRemaining--;
        notifyListeners(); // Atualiza a contagem visualmente (ex: 59, 58...)
      } else {
        // O TEMPO ACABOU!
        _finalizarComVibracao();
      }
    });
  }

  // Para o cronômetro manualmente (botão fechar)
  void stop() {
    _timer?.cancel();
    isActive = false;
    notifyListeners(); // Avisa a tela para sumir a barra
  }

  // Adiciona mais tempo (botão +10s)
  void addTime(int seconds) {
    if (isActive) {
      secondsRemaining += seconds;
      notifyListeners();
    }
  }

  // Função interna para vibrar e parar
  void _finalizarComVibracao() async {
    stop(); // Para o timer primeiro

    // Verifica se o celular tem vibrador e vibra
    if (await Vibration.hasVibrator() ?? false) {
      // Padrão: Espera 0ms, Vibra 500ms, Espera 200ms, Vibra 500ms
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
  }

  // Formata o tempo para texto (ex: "01:30")
  String get formattedTime {
    final int min = secondsRemaining ~/ 60;
    final int sec = secondsRemaining % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}