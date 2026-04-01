import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/association.dart';
import '../../../../models/association_photo.dart';
import '../../data/association_service.dart';

/// Écran de gestion de la galerie photos d'une association.
class ManagePhotosScreen extends StatefulWidget {
  final Association association;

  const ManagePhotosScreen({super.key, required this.association});

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  final _service = AssociationService();
  List<AssociationPhoto> _photos = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final photos = await _service.fetchPhotos(widget.association.id);
      if (mounted) setState(() => _photos = photos);
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final photo =
          await _service.addPhoto(widget.association.id, bytes, ext);
      if (mounted) setState(() => _photos.insert(0, photo));
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(AssociationPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Supprimer cette photo ? Action irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deletePhoto(photo.id);
      if (mounted) setState(() => _photos.removeWhere((p) => p.id == photo.id));
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos de l\'association'),
        centerTitle: false,
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Ajouter une photo',
              onPressed: _addPhoto,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? _EmptyState(onAdd: _addPhoto)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _photos.length,
                    itemBuilder: (context, i) {
                      final photo = _photos[i];
                      return _PhotoTile(
                        photo: photo,
                        onDelete: () => _deletePhoto(photo),
                      );
                    },
                  ),
                ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final AssociationPhoto photo;
  final VoidCallback onDelete;

  const _PhotoTile({required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            photo.photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 64, color: cs.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Aucune photo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Ajoutez des photos pour illustrer l\'association',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Ajouter une photo'),
          ),
        ],
      ),
    );
  }
}
