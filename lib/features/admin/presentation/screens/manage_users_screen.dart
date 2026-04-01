import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/app_user.dart';
import '../../../../features/user/data/user_service.dart';
import 'admin_user_detail_screen.dart';

/// Liste des utilisateurs avec recherche (admin).
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _userService = UserService();
  final _searchController = TextEditingController();

  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _userService.fetchAllUsers();
      if (mounted) {
        setState(() {
          _users = list;
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

  List<AppUser> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou email…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Aucun utilisateur.'
              : 'Aucun résultat.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final u = list[index];
          return _UserTile(
            user: u,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => AdminUserDetailScreen(
                    user: u,
                    allUsers: _users,
                  ),
                ),
              );
              if (changed == true && mounted) {
                await _load();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Utilisateur mis à jour.'),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd('fr_FR');
    final initial =
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        user.name.isNotEmpty ? user.name : '—',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.email.isNotEmpty)
            Text(
              user.email,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            'Inscrit le ${fmt.format(user.createdAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Admin',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
      onTap: onTap,
    );
  }
}
