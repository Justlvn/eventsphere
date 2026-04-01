import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../models/enums.dart';
import '../../../../models/event.dart';
import '../../data/event_participation_service.dart';
import '../providers/events_provider.dart';
import 'event_form_screen.dart';

/// Écran de détail d'un événement.
///
/// Prend l'[eventId] et observe [EventsProvider] pour se mettre à jour
/// automatiquement après une édition ou se fermer après une suppression.
class EventDetailScreen extends StatelessWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final events = provider.allEvents.where((e) => e.id == eventId);
    final AppEvent? event = events.isNotEmpty ? events.first : null;

    // L'event a été supprimé — on ferme l'écran automatiquement.
    if (event == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = context.watch<PermissionService>();
    final canEdit = p.canEditEvent(event.associationId);
    final canDelete = p.canDeleteEvent(event.associationId);

    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: hasImage ? Colors.transparent : null,
        foregroundColor: hasImage ? Colors.white : null,
        elevation: hasImage ? 0 : null,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () => _openEdit(context, event),
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              onPressed: () => _confirmDelete(context, event),
            ),
        ],
      ),
      extendBodyBehindAppBar: hasImage,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image pleine largeur ──────────────────────────────────
            if (hasImage)
              Hero(
                tag: 'event_image_${event.id}',
                child: _EventHeroImage(imageUrl: event.imageUrl!),
              ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // ── Titre ──────────────────────────────────────────────────────
            Text(
              event.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ── Badges association + visibilité ────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (event.association != null)
                  _InfoChip(
                    icon: Icons.business_outlined,
                    label: event.association!.name,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    textColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                _InfoChip(
                  icon: _visibilityIcon(event.visibility),
                  label: event.visibility.label,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  textColor:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                _InfoChip(
                  icon: Icons.label_outline,
                  label: event.category.label,
                  color: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer,
                  textColor: Theme.of(context)
                      .colorScheme
                      .onTertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── Date ───────────────────────────────────────────────────────
            if (event.eventDate != null) ...[
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: _formatDate(event.eventDate!, event.eventEndDate),
              ),
              const SizedBox(height: 12),
            ],

            // ── Lieu ───────────────────────────────────────────────────────
            if (event.location != null && event.location!.isNotEmpty) ...[
              _DetailRow(
                icon: Icons.place_outlined,
                label: 'Lieu',
                value: event.location!,
              ),
              const SizedBox(height: 12),
            ],

            // ── Description ────────────────────────────────────────────────
            if (event.description != null &&
                event.description!.isNotEmpty) ...[
              _DetailRow(
                icon: Icons.notes_outlined,
                label: 'Description',
                value: event.description!,
                multiline: true,
              ),
              const SizedBox(height: 12),
            ],

            // ── Aucun détail ───────────────────────────────────────────────
            if (event.eventDate == null &&
                (event.location == null || event.location!.isEmpty) &&
                (event.description == null || event.description!.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun détail supplémentaire.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),

            // ── Lien Instagram ─────────────────────────────────────────────
            if (event.instagramUrl != null &&
                event.instagramUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InstagramButton(url: event.instagramUrl!),
            ],

            if (p.canSeeEvent(event)) ...[
              const SizedBox(height: 20),
              _ParticipationSection(event: event),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Métadonnées ────────────────────────────────────────────────
            Text(
              'Créé le ${_formatDate(event.createdAt, null)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, AppEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          initialEvent: event,
          preSelectedAssociation: event.association,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'événement'),
        content: Text(
          'Supprimer « ${event.title} » ? Cette action est irréversible.',
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<EventsProvider>().deleteEvent(event.id);
      // Le screen se ferme automatiquement via l'observation du provider.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime start, DateTime? end) {
    final dateFmt = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFmt = DateFormat('HH:mm');
    final dateStr = dateFmt.format(start);
    final startTime = timeFmt.format(start);

    if (end != null) {
      final endTime = timeFmt.format(end);
      final dur = end.difference(start);
      final h = dur.inHours;
      final m = dur.inMinutes % 60;
      final durStr = h > 0
          ? (m > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${h}h')
          : '${m}min';
      return '$dateStr\n$startTime – $endTime  ($durStr)';
    }
    return '$dateStr · $startTime';
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

// ─── Image hero pleine largeur ────────────────────────────────────────────────

class _EventHeroImage extends StatelessWidget {
  final String imageUrl;

  const _EventHeroImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 56),
              ),
            ),
          ),
          // Gradient en haut pour lisibilité du titre AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                  colors: [Colors.black87, Colors.black45, Colors.transparent],
                ),
              ),
            ),
          ),
          // Gradient en bas pour transition douce
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black26],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bouton Instagram ─────────────────────────────────────────────────────────

class _InstagramButton extends StatelessWidget {
  final String url;

  const _InstagramButton({required this.url});

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _open,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFFE1306C), width: 1.5),
          foregroundColor: const Color(0xFFE1306C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 20),
        label: const Text(
          'Voir le post Instagram',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}

// ─── Ligne d'information ───────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Chip d'info (association, visibilité, catégorie) ─────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Participation « Je participe » ───────────────────────────────────────────

class _ParticipationSection extends StatefulWidget {
  final AppEvent event;

  const _ParticipationSection({required this.event});

  @override
  State<_ParticipationSection> createState() => _ParticipationSectionState();
}

class _ParticipationSectionState extends State<_ParticipationSection> {
  final EventParticipationService _service = EventParticipationService();
  bool _loading = true;
  bool _busy = false;
  EventParticipationStatus? _status;
  int? _organizerParticipantCount;
  int? _organizerUnavailableCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _refreshOrganizerCounts() async {
    final perms = context.read<PermissionService>();
    if (!perms.canViewEventParticipantCount(widget.event.associationId)) return;
    final p = await _service.getParticipantCountForOrganizers(widget.event.id);
    final u = await _service.getUnavailableCountForOrganizers(widget.event.id);
    if (mounted) {
      setState(() {
        _organizerParticipantCount = p;
        _organizerUnavailableCount = u;
      });
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final perms = context.read<PermissionService>();
    if (!perms.canSeeEvent(widget.event)) {
      setState(() => _loading = false);
      return;
    }
    try {
      final st = await _service.getMyStatus(widget.event.id);
      int? c;
      int? u;
      if (perms.canViewEventParticipantCount(widget.event.associationId)) {
        c = await _service.getParticipantCountForOrganizers(widget.event.id);
        u = await _service.getUnavailableCountForOrganizers(widget.event.id);
      }
      if (mounted) {
        setState(() {
          _status = st;
          _organizerParticipantCount = c;
          _organizerUnavailableCount = u;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickGoing() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await _service.setStatus(widget.event.id, EventParticipationStatus.going);
      if (!mounted) return;
      setState(() => _status = EventParticipationStatus.going);
      await _refreshOrganizerCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de mettre à jour : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickUnavailable() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await _service.setStatus(
        widget.event.id,
        EventParticipationStatus.unavailable,
      );
      if (!mounted) return;
      setState(() => _status = EventParticipationStatus.unavailable);
      await _refreshOrganizerCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de mettre à jour : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearResponse() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await _service.clearStatus(widget.event.id);
      if (!mounted) return;
      setState(() => _status = null);
      await _refreshOrganizerCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de mettre à jour : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _organizerParticipantLabel(int n) {
    if (n <= 0) {
      return 'Personnes ayant indiqué participer : 0';
    }
    if (n == 1) {
      return '1 personne a indiqué vouloir participer (anonyme)';
    }
    return '$n personnes ont indiqué vouloir participer (anonymes)';
  }

  String _organizerUnavailableLabel(int n) {
    if (n <= 0) {
      return 'Personnes indisponibles : 0';
    }
    if (n == 1) {
      return '1 personne a indiqué ne pas être disponible (anonyme)';
    }
    return '$n personnes ont indiqué ne pas être disponibles (anonymes)';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final perms = context.watch<PermissionService>();
    final showOrganizerStats =
        perms.canViewEventParticipantCount(widget.event.associationId) &&
            _organizerParticipantCount != null &&
            _organizerUnavailableCount != null;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Participation',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
        ),
        const SizedBox(height: 10),
        if (showOrganizerStats) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.groups_outlined, size: 22, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _organizerParticipantLabel(_organizerParticipantCount!),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.event_busy_outlined, size: 22, color: cs.tertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _organizerUnavailableLabel(_organizerUnavailableCount!),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          perms.canViewEventParticipantCount(widget.event.associationId)
              ? 'Tu vois uniquement les totaux ; les identités restent confidentielles.'
              : 'Indique si tu comptes venir ou si tu ne peux pas. Les organisateurs voient seulement les totaux, pas les noms.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 14),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_status == null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _pickGoing,
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Je participe'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickUnavailable,
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text(
                    'Je ne suis pas disponible',
                    textAlign: TextAlign.center,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          )
        else if (_status == EventParticipationStatus.going)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearResponse,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Je ne participe plus'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearResponse,
              icon: const Icon(Icons.undo_outlined),
              label: const Text('Retirer mon indisponibilité'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
      ],
    );
  }
}
