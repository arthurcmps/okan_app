import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_check.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({this.onCompleted, super.key});

  /// Permite validar o encerramento sem inicializar Firebase em testes.
  /// Em produção, o destino permanece sendo [AuthCheck].
  final VoidCallback? onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  static const List<Map<String, String>> _onboardingData = [
    {
      'title': 'Conceito Sankofa',
      'subtitle':
          'Sua evolução conecta passado, presente e futuro — registrada passo a passo.',
      'icon': '🌱',
    },
    {
      'title': 'Treinos Inteligentes',
      'subtitle':
          'Acesse seus treinos, veja a execução e registre suas cargas com poucos toques.',
      'icon': '🏋️‍♂️',
    },
    {
      'title': 'Sua Melhor Versão',
      'subtitle':
          'Acompanhe sua força e suas medidas para reconhecer cada avanço.',
      'icon': '📈',
    },
  ];

  bool get _isLastPage => _currentPage == _onboardingData.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('showOnboarding', false);

    if (!mounted) return;

    if (widget.onCompleted != null) {
      widget.onCompleted!();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthCheck(showOnboarding: false),
      ),
    );
  }

  Future<void> _nextOrComplete() async {
    if (_isLastPage) {
      await _completeOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _isLastPage
                      ? const SizedBox(width: 80, key: ValueKey('skip-space'))
                      : TextButton(
                          key: const ValueKey('skip-button'),
                          onPressed: _isCompleting
                              ? null
                              : _completeOnboarding,
                          child: const Text(
                            'Pular',
                            style: TextStyle(color: AppColors.textSub),
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() => _currentPage = value);
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => _buildPage(
                  title: _onboardingData[index]['title']!,
                  subtitle: _onboardingData[index]['subtitle']!,
                  emoji: _onboardingData[index]['icon']!,
                ),
              ),
            ),
            Semantics(
              container: true,
              liveRegion: true,
              label: 'Página ${_currentPage + 1} de ${_onboardingData.length}',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                    (index) => _buildDot(index: index),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLastPage
                        ? AppColors.primary
                        : AppColors.surface,
                    disabledBackgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isCompleting ? null : _nextOrComplete,
                  child: _isCompleting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          _isLastPage ? 'COMEÇAR AGORA' : 'PRÓXIMO',
                          style: TextStyle(
                            color: _isLastPage
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(
        right: index == _onboardingData.length - 1 ? 0 : 8,
      ),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? AppColors.primary : Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required String emoji,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 420;
        final verticalPadding = compact ? 12.0 : 24.0;
        final minimumHeight = constraints.maxHeight > verticalPadding * 2
            ? constraints.maxHeight - verticalPadding * 2
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 24 : 40,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: compact ? 64 : 80),
                  ),
                ),
                SizedBox(height: compact ? 20 : 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                SizedBox(height: compact ? 12 : 20),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
