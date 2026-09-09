import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 20,
    this.onTap,
  });

  final String? photoUrl;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final normalizedName = name.trim();
    final userLabel = normalizedName.isEmpty ? 'usuário' : normalizedName;
    final avatar = _buildAvatar(context, normalizedName);

    if (onTap == null) {
      return Semantics(
        image: true,
        label: 'Avatar de $userLabel',
        child: ExcludeSemantics(child: avatar),
      );
    }

    return Semantics(
      button: true,
      label: 'Abrir perfil de $userLabel',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: 'Abrir perfil de $userLabel',
          child: InkResponse(
            onTap: onTap,
            radius: radius + 8,
            customBorder: const CircleBorder(),
            child: avatar,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String normalizedName) {
    final colors = Theme.of(context).colorScheme;
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.surfaceContainerHighest,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: normalizedPhotoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: normalizedPhotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.secondary,
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildInitial(colors, normalizedName),
                )
              : _buildInitial(colors, normalizedName),
        ),
      ),
    );
  }

  Widget _buildInitial(ColorScheme colors, String normalizedName) {
    return ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Text(
          normalizedName.isEmpty ? '?' : normalizedName[0].toUpperCase(),
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
