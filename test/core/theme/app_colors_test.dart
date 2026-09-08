import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/theme/app_colors.dart';

void main() {
  test('mantém a paleta canônica Cyber-Sankofa', () {
    expect(AppColors.background, const Color(0xFF120E16));
    expect(AppColors.surface, const Color(0xFF1E1826));
    expect(AppColors.primary, const Color(0xFFCCFF00));
    expect(AppColors.secondary, const Color(0xFFE07A5F));
    expect(AppColors.textMain, const Color(0xFFF2F0F5));
    expect(AppColors.textSub, const Color(0xFF9E9CAB));
    expect(AppColors.error, const Color(0xFFFF453A));
    expect(AppColors.warning, const Color(0xFFFFB020));
  });

  test('define tokens semânticos para contextos do produto', () {
    expect(AppColors.info, const Color(0xFF448AFF));
    expect(AppColors.competition, const Color(0xFFFF6E40));
    expect(AppColors.beta, const Color(0xFFFFC107));
    expect(AppColors.neutral, const Color(0xFF9E9E9E));
  });
}
