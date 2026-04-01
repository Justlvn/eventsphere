import 'package:flutter/material.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/sliver_section_header.dart';
import '../../../../features/memberships/data/membership_service.dart';
import '../../../../features/user/data/user_service.dart';
import '../../../../models/app_user.dart';
import '../../../../models/association.dart';
import '../../../../models/enums.dart';
import '../../../../models/membership.dart';

/// Écran de gestion des membres d'une association.
///
/// Accessible aux admins et aux responsables de l'association.
/// Permet de voir les membres actuels, d'en ajouter et d'en retirer.
class ManageMembersScreen extends StatefulWidget {
  final Association association;

  const ManageMembersScreen({super.key, required this.association});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final _membershipService = MembershipService();
  final _userService = UserService();

  List<Membership> _members = [];
  List<AppUser> _allUsers = [];
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
        _membershipService.fetchAllMembershipsOfAssociation(
          widget.association.id,
        ),
        _userService.fetchAllUsers(),
      ]);
      if (mounted) {
        final allMemberships = results[0] as List<Membership>;
        setState(() {
          _members = allMemberships
              .where((m) => m.role == AssociationRole.member)
              .toList();
          _allUsers = results[1] as List<AppUser>;
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

  Future<void> _addMember(AppUser user) async {
    try {
      await _membershipService.createMembership(
        userId: user.id,
        associationId: widget.association.id,
        role: AssociationRole.member,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} a été ajouté comme membre.'),
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

  Future<void> _removeMember(Membership membership) async {
    final userName = membership.memberUser?.name;
    final displayName =
        (userName != null && userName.isNotEmpty) ? userName : 'ce membre';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text(
          'Retirer $displayName de l\'association « ${widget.association.name} » ?',
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
          const SnackBar(content: Text('Membre retiré.')),
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

  /// Utilisateurs non encore membres (ni responsables) de l'association,
  /// filtrés par la recherche.
  List<AppUser> get _availableUsers {
    final existingIds = _members.map((m) => m.userId).toSet();
    return _allUsers.where((u) {
      if (existingIds.contains(u.id)) return false;
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
            const Text('Membres', style: TextStyle(fontSize: 16)),
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
                      // ── Membres actuels ────────────────────────────────────
                      SliverSectionHeader(
                        title: _members.isEmpty
                            ? 'Membres actuels'
                            : 'Membres actuels (${_members.length})',
                      ),
                      if (_members.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.people_outline,
                                      color: Colors.grey.shade400),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Aucun membre pour le moment.',
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final m = _members[index];
                              return _MemberTile(
                                membership: m,
                                onRemove: () => _removeMember(m),
                              );
                            },
                            childCount: _members.length,
                          ),
                        ),

                      // ── Ajouter un membre ──────────────────────────────────
                      const SliverSectionHeader(title: 'Ajouter un membre'),
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
                                Icon(Icons.person_search_outlined,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Tous les utilisateurs sont déjà membres.'
                                      : 'Aucun utilisateur ne correspond à la recherche.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
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
                              return _UserAddTile(
                                user: user,
                                onAdd: () => _addMember(user),
                              );
                            },
                            childCount: _availableUsers.length,
                          ),
                        ),

                      const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                    ],
                  ),
                ),
    );
  }
}

// ─── Tuile : membre existant ───────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final Membership membership;
  final VoidCallback onRemove;

  const _MemberTile({required this.membership, required this.onRemove});

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
      subtitle:
          email.isNotEmpty ? Text(email, style: const TextStyle(fontSize: 12)) : null,
      trailing: IconButton(
        icon: Icon(
          Icons.person_remove_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        tooltip: 'Retirer',
        onPressed: onRemove,
      ),
    );
  }
}

// ─── Tuile : utilisateur disponible ───────────────────────────────────────────

class _UserAddTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onAdd;

  const _UserAddTile({required this.user, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(72, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onAdd,
        child: const Text('Ajouter'),
      ),
    );
  }
}

