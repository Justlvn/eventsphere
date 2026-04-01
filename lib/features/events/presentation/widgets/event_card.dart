import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/enums.dart';
import '../../../../models/event.dart';

class EventCard extends StatelessWidget {
  final AppEvent event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _categoryColor(event.category);
    final displayDate = event.eventDate ?? event.createdAt;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Hero(
        tag: 'event_${event.id}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.95),
                ),
                boxShadow: AppShadows.cardFor(Theme.of(context).brightness),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      child: Image.network(
                        event.imageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          height: 140,
                          color: color.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: color.withValues(alpha: 0.45),
                          ),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 140,
                            color: color.withValues(alpha: 0.08),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  _EventCardInner(
                    event: event,
                    color: color,
                    displayDate: displayDate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _categoryColor(EventCategory cat) {
    switch (cat) {
      case EventCategory.soiree:
        return AppColors.soiree;
      case EventCategory.afterwork:
        return AppColors.afterwork;
      case EventCategory.journee:
        return AppColors.journee;
      case EventCategory.venteNourriture:
        return AppColors.venteNourriture;
      case EventCategory.sport:
        return AppColors.sport;
      case EventCategory.culture:
        return AppColors.culture;
      case EventCategory.concert:
        return AppColors.concert;
    }
  }
}

class _EventCardInner extends StatelessWidget {
  final AppEvent event;
  final Color color;
  final DateTime displayDate;

  const _EventCardInner({
    required this.event,
    required this.color,
    required this.displayDate,
  });

  String _longDate(BuildContext context) {
    final cap = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(displayDate);
    return cap.substring(0, 1).toUpperCase() + cap.substring(1);
  }

  String _timeRange() {
    if (event.eventDate == null) return '—';
    final start = DateFormat('HH:mm').format(event.eventDate!);
    if (event.eventEndDate != null) {
      final end = DateFormat('HH:mm').format(event.eventEndDate!);
      return '$start - $end';
    }
    return start;
  }

  String _associationLabel() {
    return event.association?.name ?? event.category.label;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _associationLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
              height: 1.2,
              color: cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            text: _longDate(context),
          ),
          const SizedBox(height: 8),
          _MetaRow(icon: Icons.schedule_outlined, text: _timeRange()),
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.place_outlined,
            text: (event.location != null && event.location!.isNotEmpty)
                ? event.location!
                : '—',
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.65)),
          const SizedBox(height: 12),
          _VisibilityFooter(visibility: event.visibility),
          if (event.instagramUrl != null &&
              event.instagramUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InstagramChip(url: event.instagramUrl!),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisibilityFooter extends StatelessWidget {
  final EventVisibility visibility;

  const _VisibilityFooter({required this.visibility});

  @override
  Widget build(BuildContext context) {
    late IconData icon;
    late String label;
    late Color accent;

    switch (visibility) {
      case EventVisibility.public:
        icon = Icons.visibility_outlined;
        label = 'Public';
        accent = AppColors.success;
      case EventVisibility.restricted:
        icon = Icons.people_outline_rounded;
        label = 'Restreint';
        accent = AppColors.warning;
      case EventVisibility.private:
        icon = Icons.lock_outline_rounded;
        label = 'Privé';
        accent = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _InstagramChip extends StatelessWidget {
  final String url;

  const _InstagramChip({required this.url});

  static const _pink = Color(0xFFE1306C);

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _pink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _pink.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded, size: 14, color: _pink),
            SizedBox(width: 6),
            Text(
              'Voir sur Instagram',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _pink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
