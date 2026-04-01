import 'association.dart';
import 'enums.dart';

class AppEvent {
  final String id;
  final String title;
  final String? description;
  /// Null si l'événement n'est rattaché à aucune association.
  final String? associationId;
  final EventVisibility visibility;
  final EventCategory category;
  final String? createdBy;
  final DateTime createdAt;

  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final String? location;

  /// URL publique de l'image de présentation (Supabase Storage).
  final String? imageUrl;

  /// Lien vers un post Instagram pour plus d'infos.
  final String? instagramUrl;

  /// Nom de l'association embarqué via join (`associations(id, name)`).
  final Association? association;

  const AppEvent({
    required this.id,
    required this.title,
    this.description,
    this.associationId,
    required this.visibility,
    required this.category,
    this.createdBy,
    required this.createdAt,
    this.eventDate,
    this.eventEndDate,
    this.location,
    this.imageUrl,
    this.instagramUrl,
    this.association,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      associationId: json['association_id'] as String?,
      visibility: EventVisibilityExtension.fromString(
        json['visibility'] as String? ?? 'public',
      ),
      category: EventCategoryExtension.fromString(
        json['category'] as String? ?? 'autre',
      ),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      eventEndDate: json['event_end_date'] != null
          ? DateTime.parse(json['event_end_date'] as String)
          : null,
      location: json['location'] as String?,
      imageUrl: json['image_url'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      association: json['associations'] != null
          ? Association.fromJson(json['associations'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Date à afficher : eventDate si disponible, sinon createdAt.
  DateTime get displayDate => eventDate ?? createdAt;

  /// Durée calculée à partir de eventDate et eventEndDate.
  Duration? get duration {
    if (eventDate == null || eventEndDate == null) return null;
    final d = eventEndDate!.difference(eventDate!);
    return d.isNegative ? null : d;
  }

  bool get isPublic => visibility == EventVisibility.public;
  bool get isRestricted => visibility == EventVisibility.restricted;
  bool get isPrivate => visibility == EventVisibility.private;

  AppEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? associationId,
    EventVisibility? visibility,
    EventCategory? category,
    String? createdBy,
    DateTime? createdAt,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? location,
    String? imageUrl,
    String? instagramUrl,
    Association? association,
  }) {
    return AppEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      associationId: associationId ?? this.associationId,
      visibility: visibility ?? this.visibility,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      association: association ?? this.association,
    );
  }
}
