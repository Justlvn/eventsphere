import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/association.dart';
import '../../data/association_service.dart';

class EditAssociationScreen extends StatefulWidget {
  final Association association;

  const EditAssociationScreen({super.key, required this.association});

  @override
  State<EditAssociationScreen> createState() => _EditAssociationScreenState();
}

class _EditAssociationScreenState extends State<EditAssociationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instagramController;

  final _service = AssociationService();
  bool _submitting = false;

  // Logo
  Uint8List? _logoBytes;
  String _logoExt = 'jpg';
  String? _existingLogoUrl;
  bool _clearLogo = false;

  // Banner
  Uint8List? _bannerBytes;
  String _bannerExt = 'jpg';
  String? _existingBannerUrl;
  bool _clearBanner = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.association.name);
    _descriptionController =
        TextEditingController(text: widget.association.description ?? '');
    _instagramController =
        TextEditingController(text: widget.association.instagramUrl ?? '');
    _existingLogoUrl = widget.association.logoUrl;
    _existingBannerUrl = widget.association.bannerUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _logoBytes = bytes;
      _logoExt = ext;
      _clearLogo = false;
    });
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _bannerBytes = bytes;
      _bannerExt = ext;
      _clearBanner = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      String? logoUrl;
      if (_logoBytes != null) {
        logoUrl = await _service.uploadLogo(
            widget.association.id, _logoBytes!, _logoExt);
      }

      String? bannerUrl;
      if (_bannerBytes != null) {
        bannerUrl = await _service.uploadBanner(
            widget.association.id, _bannerBytes!, _bannerExt);
      }

      if (!mounted) return;

      final updated = await _service.updateAssociation(
        id: widget.association.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        logoUrl: logoUrl,
        clearLogo: _clearLogo,
        bannerUrl: bannerUrl,
        clearBanner: _clearBanner,
        instagramUrl: _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
      );

      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier l'association"),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // ── Nom ─────────────────────────────────────────────────────────
            _Label('Nom *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: "Nom de l'association",
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Le nom est obligatoire.';
                if (v.trim().length < 2) return 'Au moins 2 caractères.';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Description ──────────────────────────────────────────────────
            _Label('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Décrivez l'association (optionnel)",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Instagram ────────────────────────────────────────────────────
            _Label('Compte Instagram (optionnel)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instagramController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://www.instagram.com/monasso',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.trim().startsWith('http')) {
                  return "L'URL doit commencer par https://";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Logo ─────────────────────────────────────────────────────────
            _Label('Logo'),
            const SizedBox(height: 8),
            _SquareImagePicker(
              bytes: _logoBytes,
              existingUrl: _clearLogo ? null : _existingLogoUrl,
              size: 100,
              placeholder: const Icon(Icons.add_photo_alternate_outlined,
                  size: 32),
              onPick: _pickLogo,
              onRemove: () => setState(() {
                _logoBytes = null;
                _clearLogo = true;
              }),
            ),
            const SizedBox(height: 24),

            // ── Bannière ─────────────────────────────────────────────────────
            _Label('Bannière'),
            const SizedBox(height: 8),
            _BannerImagePicker(
              bytes: _bannerBytes,
              existingUrl: _clearBanner ? null : _existingBannerUrl,
              onPick: _pickBanner,
              onRemove: () => setState(() {
                _bannerBytes = null;
                _clearBanner = true;
              }),
            ),
            const SizedBox(height: 32),

            // ── Enregistrer ──────────────────────────────────────────────────
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Picker logo carré ────────────────────────────────────────────────────────

class _SquareImagePicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? existingUrl;
  final double size;
  final Widget placeholder;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _SquareImagePicker({
    required this.bytes,
    required this.existingUrl,
    required this.size,
    required this.placeholder,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasImage => bytes != null || existingUrl != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        GestureDetector(
          onTap: onPick,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: size,
              height: size,
              child: _hasImage
                  ? (bytes != null
                      ? Image.memory(bytes!, fit: BoxFit.cover)
                      : Image.network(existingUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _Placeholder(
                              cs: cs, child: placeholder)))
                  : _Placeholder(cs: cs, child: placeholder),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Choisir'),
              ),
              if (_hasImage) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Supprimer'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme cs;
  final Widget child;

  const _Placeholder({required this.cs, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
          child: IconTheme(data: IconThemeData(color: cs.primary), child: child)),
    );
  }
}

// ─── Picker bannière ─────────────────────────────────────────────────────────

class _BannerImagePicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _BannerImagePicker({
    required this.bytes,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasImage => bytes != null || existingUrl != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: bytes != null
                ? Image.memory(bytes!, height: 140, fit: BoxFit.cover)
                : Image.network(existingUrl!, height: 140, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: cs.surfaceContainerHighest,
                        child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 40)))),
          )
        else
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                    color: cs.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.panorama_outlined, size: 32, color: cs.primary),
                  const SizedBox(height: 6),
                  Text('Choisir une bannière',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        if (_hasImage) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Changer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Label ─────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}
