import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum AuthFeedbackKind { error, success, info }

class AuthPageFrame extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;

  const AuthPageFrame({
    super.key,
    required this.child,
    this.maxContentWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const horizontalPadding = 24.0;
          const verticalPadding = 20.0;
          final contentHeight = constraints.maxHeight - (verticalPadding * 2);
          final minimumHeight = contentHeight > 0 ? contentHeight : 0.0;

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minimumHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthFeedbackBanner extends StatelessWidget {
  final String? message;
  final AuthFeedbackKind kind;

  const AuthFeedbackBanner({
    super.key,
    required this.message,
    this.kind = AuthFeedbackKind.error,
  });

  @override
  Widget build(BuildContext context) {
    final visibleMessage = message?.trim();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: visibleMessage == null || visibleMessage.isEmpty
          ? const SizedBox.shrink()
          : Semantics(
              key: ValueKey(visibleMessage),
              container: true,
              liveRegion: true,
              excludeSemantics: true,
              label: visibleMessage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _color.withOpacity(0.55)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon, color: _color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        visibleMessage,
                        style: const TextStyle(color: AppColors.textMain),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color get _color => switch (kind) {
    AuthFeedbackKind.error => AppColors.error,
    AuthFeedbackKind.success => AppColors.success,
    AuthFeedbackKind.info => AppColors.info,
  };

  IconData get _icon => switch (kind) {
    AuthFeedbackKind.error => Icons.error_outline,
    AuthFeedbackKind.success => Icons.check_circle_outline,
    AuthFeedbackKind.info => Icons.info_outline,
  };
}

class AuthPasswordField extends StatelessWidget {
  final Key? fieldKey;
  final Key? toggleKey;
  final TextEditingController controller;
  final String label;
  final bool passwordVisible;
  final VoidCallback onToggleVisibility;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;

  const AuthPasswordField({
    super.key,
    this.fieldKey,
    this.toggleKey,
    required this.controller,
    required this.label,
    required this.passwordVisible,
    required this.onToggleVisibility,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final visibilityLabel = passwordVisible
        ? 'Ocultar $label'
        : 'Mostrar $label';

    return TextFormField(
      key: fieldKey,
      controller: controller,
      obscureText: !passwordVisible,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      style: const TextStyle(color: AppColors.textMain),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          key: toggleKey,
          tooltip: visibilityLabel,
          onPressed: onToggleVisibility,
          icon: Icon(
            passwordVisible ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSub,
          ),
        ),
      ),
    );
  }
}
