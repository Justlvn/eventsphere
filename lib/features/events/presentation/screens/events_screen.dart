import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/events_provider.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import '../../../user/presentation/providers/user_provider.dart';
import '../../../../core/theme/app_theme.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EventsBody();
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final user = context.watch<UserProvider>().user;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _HomeHeader(
              userName: user?.name ?? 'Étudiant',
            ),
          ),
          if (provider.status == EventsStatus.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.status == EventsStatus.error)
            SliverFillRemaining(
              child: _ErrorState(
                message: provider.errorMessage ?? 'Une erreur est survenue.',
                onRetry: provider.refresh,
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _SectionTitle()),
            ..._buildEventsList(context, provider),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  List<Widget> _buildEventsList(
    BuildContext context,
    EventsProvider provider,
  ) {
    final events = provider.upcomingEvents;

    if (events.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final event = events[index];
            return EventCard(
              event: event,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: event.id),
                ),
              ),
            );
          },
          childCount: events.length,
        ),
      ),
    ];
  }
}

/// En-tête violet : bienvenue, nom, avatar.
class _HomeHeader extends StatelessWidget {
  final String userName;

  const _HomeHeader({
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headerColor =
        isLight ? AppColors.primary : AppColors.homeHeaderDark;
    final initial =
        userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: headerColor,
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bienvenue 👋',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 26,
            backgroundColor: isLight
                ? AppColors.lightPurple
                : Colors.white.withValues(alpha: 0.18),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isLight ? AppColors.primary : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Prochains événements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}

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
                Icons.event_available_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun événement à venir',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Les événements passés ne sont plus affichés.\nTirez vers le bas pour actualiser.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
