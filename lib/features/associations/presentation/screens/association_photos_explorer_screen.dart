import 'package:flutter/material.dart';
import '../../../../models/association_photo.dart';
import 'association_photos_gallery_screen.dart';

/// Grille type galerie téléphone : 4 colonnes, scroll vertical.
class AssociationPhotosExplorerScreen extends StatelessWidget {
  final String associationName;
  final List<AssociationPhoto> photos;

  const AssociationPhotosExplorerScreen({
    super.key,
    required this.associationName,
    required this.photos,
  });

  static const _bg = Color(0xFF121212);

  /// Espacement entre les miniatures (style album).
  static const _spacing = 2.0;

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AssociationPhotosGalleryScreen(
          associationName: associationName,
          photos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          title: const Text('Galerie'),
        ),
        body: const Center(
          child: Text('Aucune photo', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final count = photos.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              associationName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '$count photo${count > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: _spacing,
          crossAxisSpacing: _spacing,
          childAspectRatio: 1,
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) {
          final photo = photos[i];
          return _GridPhotoTile(
            photo: photo,
            onTap: () => _openViewer(context, i),
          );
        },
      ),
    );
  }
}

class _GridPhotoTile extends StatelessWidget {
  final AssociationPhoto photo;
  final VoidCallback onTap;

  const _GridPhotoTile({
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        child: Image.network(
          photo.photoUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return ColoredBox(
              color: const Color(0xFF1E1E1E),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: Colors.white24,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => ColoredBox(
            color: const Color(0xFF1E1E1E),
            child: Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}
