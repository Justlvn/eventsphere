import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Titre de section type Réglages iOS (ex. « ADMINISTRATION »).
class AppSettingsSectionLabel extends StatelessWidget {
  final String text;

  const AppSettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Carte avec ombre légère, lignes séparées par des séparateurs.
class AppSettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const AppSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.cardFor(b),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

/// Ligne d’action : icône colorée dans un carré arrondi, titre, chevron.
class AppSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showChevron;

  const AppSettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = isDestructive ? cs.error : iconColor;
    final titleColor = isDestructive ? cs.error : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: effectiveIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: cs.outline.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
