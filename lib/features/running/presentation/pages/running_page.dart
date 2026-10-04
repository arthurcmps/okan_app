import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RunningPage extends StatelessWidget {
  const RunningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Corrida'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textMain,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.directions_run,
              size: 72,
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'Cada passo conta',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Acompanhe seu percurso e sua evolução.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSub, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.route, size: 48, color: AppColors.secondary),
                  SizedBox(height: 16),
                  Text(
                    'Suas corridas aparecerão aqui',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nenhuma corrida registrada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
