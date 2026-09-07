import 'package:flutter/material.dart';

/// Estado de carregamento padronizado e anunciado por leitores de tela.
class OkanLoadingState extends StatelessWidget {
  const OkanLoadingState({
    super.key,
    this.label = 'Carregando conteúdo',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: label,
        child: ExcludeSemantics(
          child: CircularProgressIndicator(color: colors.secondary),
        ),
      ),
    );
  }
}

/// Estado informativo para conteúdo vazio, erro ou falta de permissão.
class OkanMessageState extends StatelessWidget {
  const OkanMessageState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.announce = false,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel e onAction devem ser informados juntos.',
       );

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = isError ? colors.error : colors.secondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          container: true,
          liveRegion: announce,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: accentColor.withOpacity(0.12),
                  foregroundColor: accentColor,
                  child: Icon(icon, size: 34),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              if (onAction != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
