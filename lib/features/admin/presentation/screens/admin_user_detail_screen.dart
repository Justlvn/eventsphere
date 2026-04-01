import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../models/app_user.dart';
import '../../../../models/enums.dart';
import '../../../../models/membership.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../user/data/user_service.dart';

/// Fiche utilisateur pour admin : infos, associations, rôle global.
class AdminUserDetailScreen extends StatefulWidget {
  final AppUser user;
  final List<AppUser> allUsers;

  const AdminUserDetailScreen({
    super.key,
    required this.user,
    required this.allUsers,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final _userService = UserService();

  late AppUser _user;
  List<Membership> _memberships = [];
  bool _loadingMemberships = true;
  bool _savingRole = false;
  String? _membershipError;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadMemberships();
  }

  Future<void> _loadMemberships() async {
    setState(() {
      _loadingMemberships = true;
      _membershipError = null;
    });
    try {
      final list = await _userService.fetchMemberships(_user.id);
      if (mounted) {
        setState(() {
          _memberships = list;
          _loadingMemberships = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _membershipError = e.toString();
          _loadingMemberships = false;
        });
      }
    }
  }

  int get _adminCount =>
      widget.allUsers.where((u) => u.isAdmin).length;

  bool _isCurrentUser() =>
      context.read<AuthProvider>().user?.id == _user.id;

  Future<void> _setRole(GlobalRole newRole) async {
    if (newRole == _user.role) return;

    if (newRole == GlobalRole.student &&
        _user.isAdmin &&
        _adminCount <= 1) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Action impossible'),
          content: const Text(
            'Vous ne pouvez pas retirer le rôle administrateur au dernier administrateur de l’application.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (newRole == GlobalRole.student && _user.isAdmin && _isCurrentUser()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Retirer vos droits admin ?'),
          content: const Text(
            'Vous ne pourrez plus accéder aux fonctions d’administration jusqu’à ce qu’un autre administrateur vous réattribue ce rôle.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _savingRole = true);
    try {
      await _userService.updateGlobalRole(_user.id, newRole);
      final updated = _user.copyWith(role: newRole);
      if (mounted) {
        setState(() {
          _user = updated;
          _savingRole = false;
        });
      }
      if (_isCurrentUser() && mounted) {
        await context.read<AuthProvider>().refreshProfile();
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingRole = false);
        final msg = e is AppException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd('fr_FR');
    final timeFmt = DateFormat.Hm('fr_FR');
    final initial =
        _user.name.isNotEmpty ? _user.name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil utilisateur'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user.name.isNotEmpty ? _user.name : '—',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (_user.email.isNotEmpty)
                      Text(
                        _user.email,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Inscription',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(_user.createdAt)} · ${timeFmt.format(_user.createdAt)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Text(
            'Rôle global',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Étudiant : accès standard. Administrateur : gestion des associations, utilisateurs, responsables…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          AbsorbPointer(
            absorbing: _savingRole,
            child: SegmentedButton<GlobalRole>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<GlobalRole>(
                  value: GlobalRole.student,
                  label: Text('Étudiant'),
                  icon: Icon(Icons.school_outlined, size: 18),
                ),
                ButtonSegment<GlobalRole>(
                  value: GlobalRole.admin,
                  label: Text('Admin'),
                  icon: Icon(Icons.admin_panel_settings_outlined, size: 18),
                ),
              ],
              selected: {_user.role},
              onSelectionChanged: (Set<GlobalRole> selection) {
                if (_savingRole || selection.isEmpty) return;
                _setRole(selection.first);
              },
            ),
          ),
          if (_savingRole)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SizedBox(height: 28),
          Text(
            'Associations',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (_loadingMemberships)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_membershipError != null)
            Text(
              _membershipError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_memberships.isEmpty)
            Text(
              'Aucune association.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _memberships.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.business_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        _memberships[i].association?.name ?? 'Association',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _memberships[i].isResponsible
                            ? 'Responsable'
                            : 'Membre',
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
