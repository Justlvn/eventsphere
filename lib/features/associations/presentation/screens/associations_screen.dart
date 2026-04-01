import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/associations_provider.dart';
import '../widgets/association_card.dart';
import 'association_detail_screen.dart';
import 'association_form_screen.dart';

class AssociationsScreen extends StatelessWidget {
  const AssociationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssociationsProvider>();
    final canCreate = context.watch<PermissionService>().canCreateAssociation;

    final top = MediaQuery.paddingOf(context).top;
    final n = provider.status == AssociationsStatus.loaded
        ? provider.associations.length
        : 0;
    final loaded = provider.status == AssociationsStatus.loaded;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _AssociationsColoredHeader(
              topPadding: top,
              associationCount: n,
              showCountSubtitle: loaded,
              canCreate: canCreate,
            ),
          ),
          // Plus d’air que sur l’accueil entre le bandeau et le contenu.
          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          if (provider.status == AssociationsStatus.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.status == AssociationsStatus.error)
            SliverFillRemaining(
              child: _ErrorState(
                message: provider.errorMessage ?? 'Une erreur est survenue.',
                onRetry: provider.refresh,
              ),
            )
          else if (provider.associations.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final association = provider.associations[index];
                  return AssociationCard(
                    association: association,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssociationDetailScreen(
                          association: association,
                        ),
                      ),
                    ),
                  );
                },
                childCount: provider.associations.length,
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

/// Bandeau aligné sur l’accueil : même padding et gabarit typographique.
class _AssociationsColoredHeader extends StatelessWidget {
  final double topPadding;
  final int associationCount;
  final bool showCountSubtitle;
  final bool canCreate;

  const _AssociationsColoredHeader({
    required this.topPadding,
    required this.associationCount,
    required this.showCountSubtitle,
    required this.canCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headerColor =
        isLight ? AppColors.primary : AppColors.homeHeaderDark;

    return Container(
      width: double.infinity,
      color: headerColor,
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Associations',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
                if (showCountSubtitle) ...[
                  const SizedBox(height: 6),
                  Text(
                    associationCount == 1
                        ? '1 association active'
                        : '$associationCount associations actives',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canCreate)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AssociationFormScreen(),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Créer'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.business_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune association',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Les associations créées apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── État erreur ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
