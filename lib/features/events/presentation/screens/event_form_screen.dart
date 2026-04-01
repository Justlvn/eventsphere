import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../models/association.dart';
import '../../../../models/enums.dart';
import '../../../../models/event.dart';
import '../../data/event_service.dart';
import '../providers/events_provider.dart';

/// Formulaire de création **ou d'édition** d'événement.
///
/// **Mode création** : ne pas passer [initialEvent].
/// **Mode édition**  : passer [initialEvent] — les champs sont pré-remplis
/// et l'association ne peut pas être modifiée.
///
/// [preSelectedAssociation] : association fixée et non modifiable.
/// [allowedAssociations]    : liste pour le sélecteur admin (création seule).
class EventFormScreen extends StatefulWidget {
  final Association? preSelectedAssociation;
  final List<Association>? allowedAssociations;

  /// Événement existant pour le mode édition.
  final AppEvent? initialEvent;

  const EventFormScreen({
    super.key,
    this.preSelectedAssociation,
    this.allowedAssociations,
    this.initialEvent,
  });

  bool get isEditing => initialEvent != null;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _instagramController = TextEditingController();

  Association? _selectedAssociation;
  EventVisibility _visibility = EventVisibility.public;
  EventCategory _category = EventCategory.soiree;
  DateTime? _eventDate;
  DateTime? _eventEndDate;
  bool _submitting = false;
  bool _didApplyResponsibleDefaultVisibility = false;

  // Image handling
  Uint8List? _pickedBytes;
  String _pickedExtension = 'jpg';
  String? _existingImageUrl;
  bool _clearImage = false;

  @override
  void initState() {
    super.initState();
    _selectedAssociation = widget.preSelectedAssociation;

    // Pré-remplissage en mode édition.
    final event = widget.initialEvent;
    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      _visibility = event.visibility;
      _category = event.category;
      _eventDate = event.eventDate;
      _eventEndDate = event.eventEndDate;
      // L'association vient de l'event si non fournie explicitement.
      _selectedAssociation ??= event.association;
      _existingImageUrl = event.imageUrl;
      _instagramController.text = event.instagramUrl ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyResponsibleDefaultVisibility || widget.initialEvent != null) {
      return;
    }
    final perms = context.read<PermissionService>();
    if (!perms.canPublishEventAsPublic) {
      setState(() => _visibility = EventVisibility.private);
    }
    _didApplyResponsibleDefaultVisibility = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventDate ?? now),
    );
    if (!mounted) return;

    final newStart = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );

    setState(() {
      _eventDate = newStart;
      // Reset end date if it is now before the new start
      if (_eventEndDate != null && !_eventEndDate!.isAfter(newStart)) {
        _eventEndDate = null;
      }
    });
  }

  Future<void> _pickEndTime() async {
    if (_eventDate == null) return;

    // Default suggestion: same day as start, +1 hour
    final suggestion = _eventEndDate ?? _eventDate!.add(const Duration(hours: 1));
    final now = DateTime.now();

    // Step 1: pick the date (can be same day or later)
    final date = await showDatePicker(
      context: context,
      initialDate: suggestion,
      firstDate: _eventDate!,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    // Step 2: pick the time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(suggestion),
    );
    if (!mounted || time == null) return;

    final end = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!end.isAfter(_eventDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La date et heure de fin doivent être après le début."),
        ),
      );
      return;
    }

    setState(() => _eventEndDate = end);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    // Use picked.name (not path) — on web, path is a blob URL
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _pickedBytes = bytes;
      _pickedExtension = ext.isNotEmpty ? ext : 'jpg';
      _clearImage = false;
    });
  }

  void _removeImage() {
    setState(() {
      _pickedBytes = null;
      _clearImage = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAssociation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une association.')),
      );
      return;
    }

    final perms = context.read<PermissionService>();
    if (!perms.canPublishEventAsPublic &&
        _visibility == EventVisibility.public) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Seuls les administrateurs peuvent publier un événement en public.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final location = _locationController.text.trim().isEmpty
        ? null
        : _locationController.text.trim();
    final instagramUrl = _instagramController.text.trim().isEmpty
        ? null
        : _instagramController.text.trim();

    try {
      // Upload new image if one was picked
      String? uploadedUrl;
      if (_pickedBytes != null) {
        final service = EventService();
        uploadedUrl =
            await service.uploadEventImage(_pickedBytes!, _pickedExtension);
      }

      if (!mounted) return;
      final provider = context.read<EventsProvider>();

      if (widget.isEditing) {
        await provider.updateEvent(
          eventId: widget.initialEvent!.id,
          title: title,
          description: description,
          visibility: _visibility,
          category: _category,
          eventDate: _eventDate,
          eventEndDate: _eventEndDate,
          location: location,
          imageUrl: uploadedUrl,
          clearImage: _clearImage,
          instagramUrl: instagramUrl,
          previousVisibility: widget.initialEvent!.visibility,
        );
      } else {
        await provider.createEvent(
          title: title,
          description: description,
          association: _selectedAssociation!,
          visibility: _visibility,
          category: _category,
          eventDate: _eventDate,
          eventEndDate: _eventEndDate,
          location: location,
          imageUrl: uploadedUrl,
          instagramUrl: instagramUrl,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Événement « $title » modifié.'
                  : 'Événement « $title » créé.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
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
    final perms = context.watch<PermissionService>();
    final allowPublicVisibility = perms.canPublishEventAsPublic;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier l\'événement' : 'Créer un événement',
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // ── Association ───────────────────────────────────────────────
            _SectionLabel('Association'),
            const SizedBox(height: 8),
            _AssociationSelector(
              preSelected: widget.preSelectedAssociation,
              allowed: widget.allowedAssociations,
              selected: _selectedAssociation,
              onChanged: (a) => setState(() => _selectedAssociation = a),
            ),
            const SizedBox(height: 24),

            // ── Titre ─────────────────────────────────────────────────────
            _SectionLabel('Titre *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Nom de l\'événement',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Le titre est obligatoire.';
                }
                if (v.trim().length < 3) {
                  return 'Le titre doit contenir au moins 3 caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Description ───────────────────────────────────────────────
            _SectionLabel('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Décrivez l\'événement (optionnel)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Date de début ─────────────────────────────────────────────
            _SectionLabel('Date et heure de début'),
            const SizedBox(height: 8),
            _DatePickerTile(
              selectedDate: _eventDate,
              onTap: _pickDate,
              onClear: () => setState(() {
                _eventDate = null;
                _eventEndDate = null;
              }),
            ),
            const SizedBox(height: 16),

            // ── Heure de fin ──────────────────────────────────────────────
            _SectionLabel('Heure de fin'),
            const SizedBox(height: 8),
            _EndTimeTile(
              startDate: _eventDate,
              endDate: _eventEndDate,
              onTap: _pickEndTime,
              onClear: () => setState(() => _eventEndDate = null),
            ),
            const SizedBox(height: 24),

            // ── Lieu ──────────────────────────────────────────────────────
            _SectionLabel('Lieu'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Salle, bâtiment, adresse… (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // ── Catégorie ─────────────────────────────────────────────────
            _SectionLabel('Catégorie'),
            const SizedBox(height: 8),
            DropdownButtonFormField<EventCategory>(
              value: _category,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: EventCategory.values.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c.label),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 24),

            // ── Visibilité ────────────────────────────────────────────────
            _SectionLabel('Visibilité'),
            const SizedBox(height: 8),
            if (!allowPublicVisibility) ...[
              Text(
                'En tant que responsable, tu ne peux publier qu’en visibilité '
                'privée ou restreinte. Un administrateur pourra ensuite passer '
                'l’événement en public.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _VisibilitySelector(
              allowPublic: allowPublicVisibility,
              selected: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: 24),

            // ── Lien Instagram ────────────────────────────────────────────
            _SectionLabel('Lien Instagram (optionnel)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instagramController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://www.instagram.com/p/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final url = v.trim();
                if (!url.startsWith('http://') &&
                    !url.startsWith('https://')) {
                  return 'L\'URL doit commencer par https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Image de présentation ─────────────────────────────────────
            _SectionLabel('Image de présentation'),
            const SizedBox(height: 8),
            _ImagePickerSection(
              pickedBytes: _pickedBytes,
              existingImageUrl:
                  _clearImage ? null : _existingImageUrl,
              onPick: _pickImage,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 32),

            // ── Bouton soumettre ──────────────────────────────────────────
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditing
                          ? 'Enregistrer les modifications'
                          : 'Créer l\'événement',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sélecteur d'association ───────────────────────────────────────────────────

class _AssociationSelector extends StatelessWidget {
  final Association? preSelected;
  final List<Association>? allowed;
  final Association? selected;
  final ValueChanged<Association?> onChanged;

  const _AssociationSelector({
    required this.preSelected,
    required this.allowed,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (preSelected != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                preSelected!.name.isNotEmpty
                    ? preSelected!.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              preSelected!.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.lock_outline,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
          ],
        ),
      );
    }

    final options = allowed ?? const [];
    if (options.isEmpty) {
      return Text(
        'Aucune association disponible.',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    return DropdownButtonFormField<Association>(
      value: selected,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Choisir une association',
      ),
      items: options.map((a) {
        return DropdownMenuItem(
          value: a,
          child: Text(a.name),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Veuillez choisir une association.' : null,
    );
  }
}

// ─── Sélecteur de date ─────────────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DatePickerTile({
    required this.selectedDate,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE d MMMM yyyy · HH:mm', 'fr_FR');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.8),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: selectedDate != null
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDate != null
                    ? fmt.format(selectedDate!)
                    : 'Choisir une date et heure (optionnel)',
                style: TextStyle(
                  color: selectedDate != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey,
                ),
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sélecteur de visibilité ───────────────────────────────────────────────────

/// Bandeau lorsqu’un responsable modifie un événement déjà passé en public par un admin.
class _PublicVisibilityLockedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.primary, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: cs.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public, size: 22, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EventVisibility.public.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cet événement est public (validé par un administrateur). '
                  'Tu peux le passer en restreint ou privé ci-dessous ; seuls les '
                  'admins peuvent remettre en public.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: cs.primary),
        ],
      ),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  /// Si `false`, l’option « public » n’est pas proposée (responsables d’asso).
  final bool allowPublic;
  final EventVisibility selected;
  final ValueChanged<EventVisibility> onChanged;

  const _VisibilitySelector({
    required this.allowPublic,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showPublicAsLocked =
        !allowPublic && selected == EventVisibility.public;

    final selectable = allowPublic
        ? EventVisibility.values.toList()
        : EventVisibility.values
            .where((v) => v != EventVisibility.public)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPublicAsLocked) ...[
          _PublicVisibilityLockedNotice(),
          const SizedBox(height: 8),
        ],
        ...selectable.map((v) {
          final isSelected = v == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(v),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.4),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _visibilityIcon(v),
                      size: 22,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          Text(
                            v.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _visibilityIcon(EventVisibility v) {
    switch (v) {
      case EventVisibility.public:
        return Icons.public;
      case EventVisibility.restricted:
        return Icons.group_outlined;
      case EventVisibility.private:
        return Icons.lock_outline;
    }
  }
}

// ─── Sélecteur d'heure de fin ─────────────────────────────────────────────────

class _EndTimeTile extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _EndTimeTile({
    required this.startDate,
    required this.endDate,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = startDate == null;
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('d MMM', 'fr_FR');

    String label;
    if (disabled) {
      label = "Choisissez d'abord une date de début";
    } else if (endDate != null) {
      final dur = endDate!.difference(startDate!);
      final h = dur.inHours;
      final m = dur.inMinutes % 60;
      final durStr = h > 0
          ? (m > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${h}h')
          : '${m}min';
      // Show date prefix only when end is on a different day than start
      final diffDay = endDate!.year != startDate!.year ||
          endDate!.month != startDate!.month ||
          endDate!.day != startDate!.day;
      final datePrefix = diffDay ? '${dateFmt.format(endDate!)}  ' : '';
      label = '$datePrefix${timeFmt.format(endDate!)}  ·  durée $durStr';
    } else {
      label = 'Choisir une date et heure de fin (optionnel)';
    }

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: disabled
                ? cs.outline.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.8),
          ),
          borderRadius: BorderRadius.circular(4),
          color: disabled ? cs.surfaceContainerHighest.withValues(alpha: 0.4) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 20,
              color: disabled
                  ? cs.onSurface.withValues(alpha: 0.3)
                  : endDate != null
                      ? cs.primary
                      : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: disabled
                      ? cs.onSurface.withValues(alpha: 0.4)
                      : endDate != null
                          ? cs.onSurface
                          : Colors.grey,
                ),
              ),
            ),
            if (endDate != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Section image ─────────────────────────────────────────────────────────────

class _ImagePickerSection extends StatelessWidget {
  final Uint8List? pickedBytes;
  final String? existingImageUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerSection({
    required this.pickedBytes,
    required this.existingImageUrl,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasImage => pickedBytes != null || existingImageUrl != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: pickedBytes != null
                ? Image.memory(
                    pickedBytes!,
                    height: 160,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    existingImageUrl!,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: cs.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
          ),
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
        ] else
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 32, color: cs.primary),
                  const SizedBox(height: 6),
                  Text(
                    'Choisir une image',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Label de section ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

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
