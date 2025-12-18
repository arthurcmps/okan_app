import 'dart:async';
import 'package:flutter/material.dart';

class TimerService extends ChangeNotifier {
  // Singleton: Garante que só existe UM cronômetro no app todo
  static final TimerService instance = TimerService._();
  TimerService._();

  Timer? _timer;
  int secondsRemaining = 0;
  bool isActive = false;

  void start(int seconds) {
    _timer?.cancel();
    secondsRemaining = seconds;
    isActive = true;
    notifyListeners(); // Avisa a tela para atualizar

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 0) {
        secondsRemaining--;
        notifyListeners(); // Atualiza a contagem visualmente
      } else {
        stop();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    isActive = false;
    notifyListeners();
  }

  void addTime(int seconds) {
    secondsRemaining += seconds;
    notifyListeners();
  }

  String get formattedTime {
    final int min = secondsRemaining ~/ 60;
    final int sec = secondsRemaining % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}