import 'package:flutter/material.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/sliver_section_header.dart';
import '../../../memberships/data/membership_service.dart';
import '../../../user/data/user_service.dart';
import '../../../../models/app_user.dart';
import '../../../../models/association.dart';
import '../../../../models/enums.dart';
import '../../../../models/membership.dart';

/// Écran de gestion des responsables d'une association.
///
/// Charge la liste de tous les utilisateurs et les responsables actuels,
/// puis permet à l'admin d'attribuer ou de retirer le rôle de responsable.
class AssignResponsibleScreen extends StatefulWidget {
  final Association association;

  const AssignResponsibleScreen({super.key, required this.association});

  @override
  State<AssignResponsibleScreen> createState() =>
      _AssignResponsibleScreenState();
}

class _AssignResponsibleScreenState extends State<AssignResponsibleScreen> {
  final _userService = UserService();
  final _membershipService = MembershipService();

  List<AppUser> _allUsers = [];
  List<Membership> _responsibles = [];
  String _searchQuery = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _userService.fetchAllUsers(),
        _membershipService.fetchResponsiblesOfAssociation(
          widget.association.id,
        ),
      ]);
      if (mounted) {
        setState(() {
          _allUsers = results[0] as List<AppUser>;
          _responsibles = results[1] as List<Membership>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _assign(AppUser user) async {
    try {
      await _membershipService.createMembership(
        userId: user.id,
        associationId: widget.association.id,
        role: AssociationRole.responsible,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} est maintenant responsable.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _remove(Membership membership) async {
    final userName = membership.memberUser?.name;
    final displayName =
        (userName != null && userName.isNotEmpty) ? userName : 'cet utilisateur';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer le responsable'),
        content: Text(
          'Retirer $displayName des responsables de « ${widget.association.name} » ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _membershipService.deleteMembership(membership.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Responsable retiré.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Utilisateurs filtrés par recherche, exclus les responsables déjà en place.
  List<AppUser> get _availableUsers {
    final responsibleIds = _responsibles.map((m) => m.userId).toSet();
    return _allUsers.where((u) {
      if (responsibleIds.contains(u.id)) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Responsables', style: TextStyle(fontSize: 16)),
            Text(
              widget.association.name,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const AppLoadingView()
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadData)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      // ── Responsables actuels ───────────────────────────────
                      if (_responsibles.isNotEmpty) ...[
                        SliverSectionHeader(
                          title:
                              'Responsables actuels (${_responsibles.length})',
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final m = _responsibles[index];
                              return _ResponsibleTile(
                                membership: m,
                                onRemove: () => _remove(m),
                              );
                            },
                            childCount: _responsibles.length,
                          ),
                        ),
                      ],

                      // ── Recherche + liste d'attribution ───────────────────
                      SliverSectionHeader(
                        title: 'Attribuer à un utilisateur',
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Rechercher par nom ou email…',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.trim()),
                          ),
                        ),
                      ),

                      if (_availableUsers.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Tous les utilisateurs sont déjà responsables.'
                                      : 'Aucun utilisateur ne correspond à la recherche.',
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final user = _availableUsers[index];
                              return _UserAssignTile(
                                user: user,
                                onAssign: () => _assign(user),
                              );
                            },
                            childCount: _availableUsers.length,
                          ),
                        ),

                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 32),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── Tuile : responsable existant ─────────────────────────────────────────────

class _ResponsibleTile extends StatelessWidget {
  final Membership membership;
  final VoidCallback onRemove;

  const _ResponsibleTile({
    required this.membership,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final user = membership.memberUser;
    final name = (user?.name.isNotEmpty == true) ? user!.name : '—';
    final email = user?.email ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: email.isNotEmpty ? Text(email, style: const TextStyle(fontSize: 12)) : null,
      trailing: TextButton.icon(
        icon: Icon(
          Icons.person_remove_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        ),
        label: Text(
          'Retirer',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        onPressed: onRemove,
      ),
    );
  }
}

// ─── Tuile : utilisateur disponible ───────────────────────────────────────────

class _UserAssignTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onAssign;

  const _UserAssignTile({required this.user, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(80, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onAssign,
        child: const Text('Attribuer'),
      ),
    );
  }
}

