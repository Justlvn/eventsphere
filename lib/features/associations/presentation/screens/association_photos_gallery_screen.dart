import 'package:flutter/material.dart';
import '../../../../models/association_photo.dart';

/// Galerie plein écran : défilement horizontal, zoom pincement sur chaque photo.
class AssociationPhotosGalleryScreen extends StatefulWidget {
  final String associationName;
  final List<AssociationPhoto> photos;
  final int initialIndex;

  const AssociationPhotosGalleryScreen({
    super.key,
    required this.associationName,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<AssociationPhotosGalleryScreen> createState() =>
      _AssociationPhotosGalleryScreenState();
}

class _AssociationPhotosGalleryScreenState
    extends State<AssociationPhotosGalleryScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    final safe = widget.photos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.photos.length - 1);
    _index = safe;
    _pageController = PageController(initialPage: safe);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photos')),
        body: const Center(child: Text('Aucune photo')),
      );
    }

    final total = widget.photos.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.associationName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '${_index + 1} / $total',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final photo = widget.photos[i];
          return _GalleryPage(photo: photo);
        },
      ),
    );
  }
}

class _GalleryPage extends StatelessWidget {
  final AssociationPhoto photo;

  const _GalleryPage({required this.photo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(80),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Image.network(
                photo.photoUrl,
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
