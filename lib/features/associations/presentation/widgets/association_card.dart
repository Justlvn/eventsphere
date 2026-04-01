import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/association.dart';

class AssociationCard extends StatelessWidget {
  final Association association;
  final VoidCallback? onTap;

  const AssociationCard({
    super.key,
    required this.association,
    this.onTap,
  });

  /// Pastel par association (maquette BDE / Sport / Tech / Culture).
  static Color accentFor(String name) {
    const palette = <Color>[
      Color(0xFF5851DB),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      AppColors.primary,
    ];
    if (name.isEmpty) return AppColors.primary;
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial =
        association.name.isNotEmpty ? association.name[0].toUpperCase() : '?';
    final hasLogo =
        association.logoUrl != null && association.logoUrl!.isNotEmpty;
    final accent = accentFor(association.name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.55
                    : 0.95,
              ),
            ),
            boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasLogo
                    ? Image.network(
                        association.logoUrl!,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _InitialAvatar(
                          initial: initial,
                          accent: accent,
                        ),
                      )
                    : _InitialAvatar(
                        initial: initial,
                        accent: accent,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      association.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (association.description != null &&
                        association.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        association.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (association.memberCount != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 17,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            association.memberCount == 1
                                ? '1 membre'
                                : '${association.memberCount} membres',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: cs.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  final Color accent;

  const _InitialAvatar({
    required this.initial,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
