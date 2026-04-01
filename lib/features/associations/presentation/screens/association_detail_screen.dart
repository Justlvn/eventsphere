import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_settings_tiles.dart';
import '../../../../features/events/presentation/providers/events_provider.dart';
import '../../../../features/events/presentation/screens/event_detail_screen.dart';
import '../../../../features/events/presentation/screens/event_form_screen.dart';
import '../../../../features/memberships/data/membership_service.dart';
import '../../../../models/association.dart';
import '../../../../models/association_photo.dart';
import '../../../../models/enums.dart';
import '../../../../models/event.dart';
import '../../../../models/membership.dart';
import '../../../admin/presentation/screens/assign_responsible_screen.dart';
import '../../../user/presentation/providers/user_provider.dart';
import '../../data/association_service.dart';
import '../providers/associations_provider.dart';
import 'edit_association_screen.dart';
import 'manage_members_screen.dart';
import 'association_photos_explorer_screen.dart';
import 'association_photos_gallery_screen.dart';
import 'manage_photos_screen.dart';

class AssociationDetailScreen extends StatefulWidget {
  final Association association;

  const AssociationDetailScreen({super.key, required this.association});

  @override
  State<AssociationDetailScreen> createState() =>
      _AssociationDetailScreenState();
}

class _AssociationDetailScreenState extends State<AssociationDetailScreen> {
  final _membershipService = MembershipService();
  final _associationService = AssociationService();

  late Association _association;
  List<Membership> _memberships = [];
  List<AssociationPhoto> _photos = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _association = widget.association;
    _loadAll();
    _refreshAssociationFromServer();
  }

  /// Recharge l’association depuis Supabase (évite données périmées depuis la liste ou le profil).
  Future<void> _refreshAssociationFromServer() async {
    try {
      final fresh =
          await _associationService.fetchAssociationById(_association.id);
      if (mounted) setState(() => _association = fresh);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadMembers(), _loadPhotos()]);
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final all = await _membershipService.fetchAllMembershipsOfAssociation(
          _association.id);
      if (mounted) setState(() => _memberships = all);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _associationService.fetchPhotos(_association.id);
      if (mounted) setState(() => _photos = photos);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadAll(),
      context.read<EventsProvider>().refresh(),
    ]);
  }

  /// Page type « explorateur » (bandeau horizontal, proportions naturelles).
  void _openPhotosExplorer() {
    if (_photos.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AssociationPhotosExplorerScreen(
          associationName: _association.name,
          photos: _photos,
        ),
      ),
    );
  }

  /// Visionneuse plein écran (depuis une miniature sur la fiche).
  void _openPhotosViewer(int initialIndex) {
    if (_photos.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AssociationPhotosGalleryScreen(
          associationName: _association.name,
          photos: _photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PermissionService>();
    final canManage = p.canManageAssociation(_association.id);

    final responsibles = _memberships
        .where((m) => m.role == AssociationRole.responsible)
        .toList();
    final members = _memberships
        .where((m) => m.role == AssociationRole.member)
        .toList();

    final displayMemberCount =
        !_loadingMembers ? _memberships.length : _association.memberCount;

    final allEvents = context.watch<EventsProvider>().allEvents;
    final associationEvents = allEvents
        .where((e) => e.associationId == _association.id)
        .toList()
      ..sort((a, b) => b.displayDate.compareTo(a.displayDate));

    final hasBanner =
        _association.bannerUrl != null && _association.bannerUrl!.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: hasBanner,
      appBar: AppBar(
        title: Text(_association.name),
        backgroundColor: hasBanner ? Colors.transparent : null,
        foregroundColor: hasBanner ? Colors.white : null,
        elevation: hasBanner ? 0 : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Bannière ──────────────────────────────────────────────────────
            if (hasBanner)
              SliverToBoxAdapter(
                child: _BannerSection(association: _association),
              ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  20, hasBanner ? 16 : 24, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Header (logo + nom + insta) ─────────────────────────────
                  _AssociationHeader(
                    association: _association,
                    memberCount: displayMemberCount,
                  ),
                  const SizedBox(height: 24),

                  // ── Section de gestion ──────────────────────────────────────
                  if (canManage) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    _ManagementSection(
                      association: _association,
                      permissions: p,
                      onMembersChanged: _loadMembers,
                      onAssociationUpdated: (updated) {
                        context
                            .read<AssociationsProvider>()
                            .replaceAssociationInList(updated);
                        context.read<UserProvider>().refresh();
                        setState(() => _association = updated);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Responsables ────────────────────────────────────────────
                  if (responsibles.isNotEmpty || canManage) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    _SectionTitle('Responsables'),
                    const SizedBox(height: 10),
                    if (_loadingMembers)
                      const _LoadingRow()
                    else if (responsibles.isEmpty)
                      _EmptyRow(
                          icon: Icons.manage_accounts_outlined,
                          message: 'Aucun responsable assigné.')
                    else
                      _PeopleGroup(
                        memberships: responsibles,
                        roleColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        roleTextColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        roleLabel: 'Responsable',
                      ),
                  ],

                  // ── Membres ─────────────────────────────────────────────────
                  if (canManage) ...[
                    const SizedBox(height: 16),
                    _SectionTitle('Membres', count: members.length),
                    const SizedBox(height: 10),
                    if (_loadingMembers)
                      const _LoadingRow()
                    else if (members.isEmpty)
                      _EmptyRow(
                          icon: Icons.people_outline,
                          message: 'Aucun membre pour le moment.')
                    else
                      _PeopleGroup(
                        memberships: members,
                        roleColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        roleTextColor: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                        roleLabel: 'Membre',
                      ),
                  ],

                  // ── Galerie photos ──────────────────────────────────────────
                  if (_photos.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _openPhotosExplorer,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SectionTitle('Photos',
                                  count: _photos.length),
                            ),
                            Icon(
                              Icons.photo_library_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Galerie',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PhotoGallery(
                      photos: _photos,
                      onOpenAt: _openPhotosViewer,
                    ),
                  ],

                  // ── Événements ──────────────────────────────────────────────
                  const Divider(),
                  const SizedBox(height: 16),
                  _SectionTitle('Événements',
                      count: associationEvents.length),
                  const SizedBox(height: 10),
                  if (associationEvents.isEmpty)
                    _EmptyRow(
                        icon: Icons.event_outlined,
                        message: 'Aucun événement pour le moment.')
                  else
                    _EventsList(
                      events: associationEvents,
                      canCreateEvent: p.canCreateEvent(_association.id),
                      association: _association,
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bannière ─────────────────────────────────────────────────────────────────

class _BannerSection extends StatelessWidget {
  final Association association;

  const _BannerSection({required this.association});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            association.bannerUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          // Gradient haut (AppBar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                  colors: [Colors.black87, Colors.black38, Colors.transparent],
                ),
              ),
            ),
          ),
          // Gradient bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black26],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _AssociationHeader extends StatelessWidget {
  final Association association;
  final int? memberCount;

  const _AssociationHeader({
    required this.association,
    this.memberCount,
  });

  Future<void> _openInstagram() async {
    final url = association.instagramUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo =
        association.logoUrl != null && association.logoUrl!.isNotEmpty;
    final hasInstagram = association.instagramUrl != null &&
        association.instagramUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo ou initiale
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: hasLogo
              ? Image.network(
                  association.logoUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _LogoFallback(association: association),
                )
              : _LogoFallback(association: association),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                association.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (memberCount != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      memberCount == 1 ? '1 membre' : '$memberCount membres',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
              if (association.description != null &&
                  association.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  association.description!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (hasInstagram) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _openInstagram,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1306C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE1306C)
                              .withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 13, color: Color(0xFFE1306C)),
                        SizedBox(width: 5),
                        Text(
                          'Voir sur Instagram',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE1306C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final Association association;

  const _LogoFallback({required this.association});

  @override
  Widget build(BuildContext context) {
    final initial = association.name.isNotEmpty
        ? association.name[0].toUpperCase()
        : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

// ─── Galerie photos ───────────────────────────────────────────────────────────

class _PhotoGallery extends StatelessWidget {
  final List<AssociationPhoto> photos;
  final void Function(int initialIndex) onOpenAt;

  const _PhotoGallery({
    required this.photos,
    required this.onOpenAt,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final photo = photos[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onOpenAt(i),
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  photo.photoUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 120,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section de gestion ───────────────────────────────────────────────────────

class _ManagementSection extends StatelessWidget {
  final Association association;
  final PermissionService permissions;
  final VoidCallback onMembersChanged;
  final ValueChanged<Association> onAssociationUpdated;

  const _ManagementSection({
    required this.association,
    required this.permissions,
    required this.onMembersChanged,
    required this.onAssociationUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final id = association.id;
    final cs = Theme.of(context).colorScheme;

    final mainTiles = <Widget>[
      if (permissions.canSetResponsible(id))
        AppSettingsTile(
          icon: Icons.manage_accounts_outlined,
          iconColor: AppColors.soiree,
          title: 'Attribuer un responsable',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AssignResponsibleScreen(association: association),
            ),
          ),
        ),
      if (permissions.canAddMember(id))
        AppSettingsTile(
          icon: Icons.people_outlined,
          iconColor: AppColors.culture,
          title: 'Gérer les membres',
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManageMembersScreen(association: association),
              ),
            );
            onMembersChanged();
          },
        ),
      if (permissions.canCreateEvent(id))
        AppSettingsTile(
          icon: Icons.event_outlined,
          iconColor: AppColors.afterwork,
          title: 'Créer un événement',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EventFormScreen(preSelectedAssociation: association),
            ),
          ),
        ),
      if (permissions.canManageAssociation(id))
        AppSettingsTile(
          icon: Icons.photo_library_outlined,
          iconColor: AppColors.concert,
          title: 'Gérer les photos',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ManagePhotosScreen(association: association),
            ),
          ),
        ),
      if (permissions.canEditAssociation(id))
        AppSettingsTile(
          icon: Icons.edit_outlined,
          iconColor: AppColors.primary,
          title: "Modifier l'association",
          onTap: () async {
            final updated = await Navigator.of(context).push<Association>(
              MaterialPageRoute(
                builder: (_) =>
                    EditAssociationScreen(association: association),
              ),
            );
            if (updated != null && context.mounted) {
              onAssociationUpdated(updated);
            }
          },
        ),
    ];

    final deleteTiles = <Widget>[
      if (permissions.canDeleteAssociation(id))
        AppSettingsTile(
          icon: Icons.delete_outline,
          iconColor: cs.error,
          title: "Supprimer l'association",
          onTap: () {},
          isDestructive: true,
          showChevron: false,
        ),
    ];

    if (mainTiles.isEmpty && deleteTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSettingsSectionLabel('Gestion'),
        const SizedBox(height: 4),
        if (mainTiles.isNotEmpty) AppSettingsGroup(children: mainTiles),
        if (mainTiles.isNotEmpty && deleteTiles.isNotEmpty)
          const SizedBox(height: 16),
        if (deleteTiles.isNotEmpty) AppSettingsGroup(children: deleteTiles),
      ],
    );
  }
}

// ─── Groupe de personnes ──────────────────────────────────────────────────────

class _PeopleGroup extends StatelessWidget {
  final List<Membership> memberships;
  final Color roleColor;
  final Color roleTextColor;
  final String roleLabel;

  const _PeopleGroup({
    required this.memberships,
    required this.roleColor,
    required this.roleTextColor,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < memberships.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            _PersonRow(
              membership: memberships[i],
              roleColor: roleColor,
              roleTextColor: roleTextColor,
              roleLabel: roleLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Membership membership;
  final Color roleColor;
  final Color roleTextColor;
  final String roleLabel;

  const _PersonRow({
    required this.membership,
    required this.roleColor,
    required this.roleTextColor,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final user = membership.memberUser;
    final name = (user?.name.isNotEmpty == true) ? user!.name : '—';
    final email = user?.email ?? '';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: roleColor,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: roleTextColor),
        ),
      ),
      title:
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: email.isNotEmpty
          ? Text(email, style: const TextStyle(fontSize: 11))
          : null,
    );
  }
}

// ─── Section événements ───────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  final List<AppEvent> events;
  final bool canCreateEvent;
  final Association association;

  const _EventsList({
    required this.events,
    required this.canCreateEvent,
    required this.association,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events.map((event) {
        return _EventRow(
          event: event,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => EventDetailScreen(eventId: event.id)),
          ),
        );
      }).toList(),
    );
  }
}

class _EventRow extends StatelessWidget {
  final AppEvent event;
  final VoidCallback onTap;

  const _EventRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _visibilityIcon(event.visibility),
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          fmt.format(event.displayDate),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (event.location != null) ...[
                          Text(' · ',
                              style: TextStyle(
                                  color: Colors.grey.shade400)),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CategoryBadge(category: event.category),
            ],
          ),
        ),
      ),
    );
  }

  IconData _visibilityIcon(EventVisibility v) {
    switch (v) {
      case EventVisibility.public:
        return Icons.public;
      case EventVisibility.restricted:
        return Icons.group_outlined;
      case EventVisibility.private:
        return Icons.lock_outline;
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  final EventCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .tertiaryContainer
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color:
              Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

// ─── Composants utilitaires ───────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionTitle(this.title, {this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyRow({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Text(message,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}

