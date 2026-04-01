import 'package:flutter/material.dart';

/// En-tête de section pour une [CustomScrollView], réutilisable.
///
/// Affiche un label en couleur primaire au-dessus d'une liste sliver.
class SliverSectionHeader extends StatelessWidget {
  final String title;

  const SliverSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
