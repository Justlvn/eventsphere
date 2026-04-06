import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/app_settings_tiles.dart';
import '../../../../features/admin/presentation/screens/manage_responsibles_screen.dart';
import '../../../../features/admin/presentation/screens/manage_users_screen.dart';
import '../../../../features/associations/presentation/screens/association_detail_screen.dart';
import '../../../../features/associations/presentation/screens/association_form_screen.dart';
import '../../../../features/associations/presentation/screens/manage_members_screen.dart';
import '../../../../features/events/presentation/screens/event_form_screen.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/user/presentation/providers/user_provider.dart';
import '../../../../models/enums.dart';
import '../../../../models/membership.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: userProvider.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHero(userProvider: userProvider),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: _ProfileContent(userProvider: userProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau « Profil » + carte utilisateur chevauchante (maquette).
class _ProfileHero extends StatelessWidget {
  final UserProvider userProvider;

  const _ProfileHero({required this.userProvider});

  @override
  Widget build(BuildContext context) {
    final user = userProvider.user!;
    final p = context.watch<PermissionService>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final top = MediaQuery.paddingOf(context).top;
    final headerColor =
        isLight ? AppColors.primary : AppColors.homeHeaderDark;
    final cs = Theme.of(context).colorScheme;
    final initial =
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: headerColor,
          padding: EdgeInsets.fromLTRB(22, top + 12, 22, 52),
          child: const Text(
            'Profil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.9),
                ),
                boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RolePills(p: p),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _RolePills extends StatelessWidget {
  final PermissionService p;

  const _RolePills({required this.p});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (p.isAdmin)
          _RolePill(
            icon: Icons.shield_outlined,
            label: 'Administrateur',
            foreground: const Color(0xFFDC2626),
            background: const Color(0xFFFFE4E6),
          )
        else
          _RolePill(
            icon: Icons.school_outlined,
            label: 'Étudiant',
            foreground: isDark ? cs.primary : const Color(0xFF2563EB),
            background: isDark
                ? cs.primary.withValues(alpha: 0.14)
                : const Color(0xFFEFF6FF),
          ),
        if (!p.isAdmin && p.isResponsibleAnywhere)
          _RolePill(
            icon: Icons.star_outline_rounded,
            label: 'Responsable',
            foreground: isDark ? cs.primary : AppColors.primary,
            background: isDark
                ? cs.primary.withValues(alpha: 0.14)
                : AppColors.lightPurple.withValues(alpha: 0.65),
          )
        else if (!p.isAdmin &&
            p.hasAnyMembership &&
            !p.isResponsibleAnywhere)
          _RolePill(
            icon: Icons.groups_outlined,
            label: 'Membre',
            foreground: isDark ? cs.primary : const Color(0xFF2563EB),
            background: isDark
                ? cs.primary.withValues(alpha: 0.14)
                : const Color(0xFFEFF6FF),
          ),
      ],
    );
  }
}

class _RolePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  const _RolePill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? foreground.withValues(alpha: 0.15) : background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: foreground.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contenu dynamique ────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  final UserProvider userProvider;

  const _ProfileContent({required this.userProvider});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PermissionService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const _AppearanceSection(),
        const SizedBox(height: 22),
        if (p.isAdmin)
          _AdminSection()
        else if (p.isResponsibleAnywhere)
          _ResponsibleSection(
            memberships: userProvider.responsibleMemberships,
            allMemberships: userProvider.memberships,
          )
        else if (p.hasAnyMembership)
          _MemberSection(memberships: userProvider.memberships)
        else
          const _StudentSection(),
        const SizedBox(height: 20),
        AppSettingsGroup(
          children: [
            AppSettingsTile(
              icon: Icons.delete_forever_outlined,
              iconColor: Theme.of(context).colorScheme.error,
              title: 'Supprimer le compte',
              onTap: () => _showDeleteAccountFlow(context),
              isDestructive: true,
              showChevron: false,
            ),
            AppSettingsTile(
              icon: Icons.logout,
              iconColor: Theme.of(context).colorScheme.error,
              title: 'Se déconnecter',
              onTap: () => context.read<AuthProvider>().signOut(),
              isDestructive: true,
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Thème (clair / sombre / système) ─────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schemeDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.9),
        ),
        boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          Icon(
            schemeDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: AppColors.primary,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode sombre',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schemeDark ? 'Activé' : 'Désactivé',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: schemeDark,
            onChanged: (v) {
              context.read<ThemeProvider>().setThemeMode(
                    v ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Titre de section ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Profil Admin ─────────────────────────────────────────────────────────────

class _AdminSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PermissionService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSettingsSectionLabel('Administration'),
        AppSettingsGroup(
          children: [
            if (p.canCreateAssociation)
              AppSettingsTile(
                icon: Icons.add_business_outlined,
                iconColor: AppColors.culture,
                title: 'Créer une association',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AssociationFormScreen(),
                  ),
                ),
              ),
            if (p.canManageAllUsers)
              AppSettingsTile(
                icon: Icons.people_outlined,
                iconColor: AppColors.soiree,
                title: 'Gérer les utilisateurs',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManageUsersScreen(),
                  ),
                ),
              ),
            if (p.isAdmin)
              AppSettingsTile(
                icon: Icons.manage_accounts_outlined,
                iconColor: AppColors.afterwork,
                title: 'Gérer les responsables',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageResponsiblesScreen(),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Profil Responsable ───────────────────────────────────────────────────────

class _ResponsibleSection extends StatelessWidget {
  final List<Membership> memberships;
  final List<Membership> allMemberships;

  const _ResponsibleSection({
    required this.memberships,
    required this.allMemberships,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          memberships.length == 1 ? 'Association gérée' : 'Associations gérées',
        ),
        ...memberships.map((m) => _AssociationManageCard(membership: m)),
        if (allMemberships.any((m) => m.role == AssociationRole.member)) ...[
          const SizedBox(height: 20),
          _SectionLabel('Autres associations'),
          ...allMemberships
              .where((m) => m.role == AssociationRole.member)
              .map((m) => _AssociationInfoCard(membership: m)),
        ],
      ],
    );
  }
}

class _AssociationManageCard extends StatelessWidget {
  final Membership membership;

  const _AssociationManageCard({required this.membership});

  @override
  Widget build(BuildContext context) {
    final asso = membership.association;
    final p = context.watch<PermissionService>();
    final assoId = membership.associationId;
    final canAdd = p.canAddMember(assoId);
    final canCreate = p.canCreateEvent(assoId);

    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                asso?.name.isNotEmpty == true
                    ? asso!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            title: Text(
              asso?.name ?? 'Association',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: asso?.description != null
                ? Text(
                    asso!.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  )
                : null,
            trailing: _PillBadge(
              label: 'Responsable',
              color: AppColors.primary,
            ),
            onTap: asso != null
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssociationDetailScreen(
                          association: asso,
                        ),
                      ),
                    )
                : null,
          ),
          if (canAdd || canCreate) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (canAdd)
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.people_outlined, size: 15),
                        label: const Text('Membres', style: TextStyle(fontSize: 13)),
                        onPressed: asso != null
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ManageMembersScreen(association: asso),
                                  ),
                                )
                            : null,
                      ),
                    ),
                  if (canAdd && canCreate)
                    Container(
                      height: 20,
                      width: 1,
                      color: Colors.grey.shade200,
                    ),
                  if (canCreate)
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.event_outlined, size: 15),
                        label: const Text('Événement', style: TextStyle(fontSize: 13)),
                        onPressed: asso != null
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EventFormScreen(
                                      preSelectedAssociation: asso,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Profil Membre ────────────────────────────────────────────────────────────

class _MemberSection extends StatelessWidget {
  final List<Membership> memberships;

  const _MemberSection({required this.memberships});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          memberships.length == 1 ? 'Mon association' : 'Mes associations',
        ),
        ...memberships.map((m) => _AssociationInfoCard(membership: m)),
      ],
    );
  }
}

class _AssociationInfoCard extends StatelessWidget {
  final Membership membership;

  const _AssociationInfoCard({required this.membership});

  @override
  Widget build(BuildContext context) {
    final asso = membership.association;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            asso?.name.isNotEmpty == true ? asso!.name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          asso?.name ?? 'Association',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: asso?.description != null
            ? Text(
                asso!.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              )
            : null,
        trailing: _PillBadge(
          label: membership.isResponsible ? 'Responsable' : 'Membre',
          color: membership.isResponsible
              ? AppColors.primary
              : AppColors.culture,
        ),
        onTap: asso != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssociationDetailScreen(association: asso),
                  ),
                )
            : null,
      ),
    );
  }
}

// ─── Profil Student ───────────────────────────────────────────────────────────

class _StudentSection extends StatelessWidget {
  const _StudentSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.school_outlined,
              size: 28,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Aucune association",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vous pouvez consulter les événements et associations publics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge pilule ─────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Future<void> _showDeleteAccountFlow(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer le compte ?'),
      content: const Text(
        'Êtes-vous sûr ? Cela est irréversible.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Oui'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  final auth = context.read<AuthProvider>();
  final ok = await auth.deleteAccount();

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  if (!context.mounted) return;

  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          auth.errorMessage ?? 'Impossible de supprimer le compte.',
        ),
        backgroundColor: cs.error,
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: const Text('Compte bien supprimé'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  if (context.mounted) {
    auth.clearSessionAfterAccountDeletion();
  }
}

