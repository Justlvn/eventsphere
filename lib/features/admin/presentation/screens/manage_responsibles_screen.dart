import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../associations/presentation/providers/associations_provider.dart';
import '../../../../models/association.dart';
import 'assign_responsible_screen.dart';

/// Écran intermédiaire pour l'admin : choisir une association avant
/// d'accéder à la gestion de ses responsables.
class ManageResponsiblesScreen extends StatelessWidget {
  const ManageResponsiblesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssociationsProvider>();
    final associations = provider.associations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les responsables'),
        centerTitle: false,
      ),
      body: () {
        if (provider.status == AssociationsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (associations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune association disponible.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: associations.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final asso = associations[index];
            return _AssociationTile(association: asso);
          },
        );
      }(),
    );
  }
}

class _AssociationTile extends StatelessWidget {
  final Association association;

  const _AssociationTile({required this.association});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          association.name.isNotEmpty
              ? association.name[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        association.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: association.description != null
          ? Text(
              association.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AssignResponsibleScreen(association: association),
        ),
      ),
    );
  }
}
