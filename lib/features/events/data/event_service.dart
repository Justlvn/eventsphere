import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/enums.dart';
import '../../../models/event.dart';

class EventService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _bucket = 'event-images';

  static String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Sélection avec image_url incluse.
  static const String _eventSelect = '*, associations(id, name)';

  // ─── Lecture ─────────────────────────────────────────────────────────────────

  /// Récupère les événements accessibles à l'utilisateur connecté.
  Future<List<AppEvent>> fetchEvents() async {
    try {
      final data = await _client
          .from('events')
          .select(_eventSelect)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => AppEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  // ─── Upload image ─────────────────────────────────────────────────────────────

  /// Upload une image dans Supabase Storage et retourne l'URL publique.
  Future<String> uploadEventImage(Uint8List bytes, String extension) async {
    try {
      final path =
          'events/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeType(extension),
              upsert: false,
            ),
          );
      return _client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  // ─── Création ─────────────────────────────────────────────────────────────────

  /// Crée un événement et retourne l'objet créé avec les données d'association.
  Future<AppEvent> createEvent({
    required String title,
    String? description,
    required String associationId,
    required EventVisibility visibility,
    required EventCategory category,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? location,
    String? imageUrl,
    String? instagramUrl,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;

      final data = await _client
          .from('events')
          .insert({
            'title': title.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            'association_id': associationId,
            'visibility': visibility.value,
            'category': category.value,
            if (userId != null) 'created_by': userId,
            if (eventDate != null) 'event_date': eventDate.toIso8601String(),
            if (eventEndDate != null)
              'event_end_date': eventEndDate.toIso8601String(),
            if (location != null && location.trim().isNotEmpty)
              'location': location.trim(),
            if (imageUrl != null) 'image_url': imageUrl,
            if (instagramUrl != null && instagramUrl.trim().isNotEmpty)
              'instagram_url': instagramUrl.trim(),
          })
          .select(_eventSelect)
          .single();

      final created = AppEvent.fromJson(data);
      _notifyEventCreatedBestEffort(created.id);
      return created;
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Notifie les utilisateurs éligibles (Edge Function) sans bloquer la création.
  ///
  /// Utilise [SupabaseClient.functions.invoke] (HTTP client interne avec `apikey` +
  /// `Authorization` alignés sur [Supabase.initialize]). Un `http.post` manuel peut
  /// provoquer un **401** à la passerelle (`execution_id: null`, `verify_jwt`) si les
  /// en-têtes ne correspondent pas exactement au client.
  void _notifyEventCreatedBestEffort(String eventId) {
    unawaited(_notifyEventCreatedBestEffortAsync(eventId));
  }

  Future<void> _notifyEventCreatedBestEffortAsync(String eventId) async {
    await _invokeNotifyOnEvent({'event_id': eventId});
  }

  /// Appel Edge Function `notify-on-event` avec corps JSON (création ou élargissement).
  Future<void> _invokeNotifyOnEvent(Map<String, String> body) async {
    try {
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        // Session peut déjà être valide ; [functions.invoke] utilise AuthHttpClient.
      }
      await _client.functions.invoke('notify-on-event', body: body);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('notify-on-event: $e\n$st');
      }
    }
  }

  static bool _isVisibilityWidened(
    EventVisibility previous,
    EventVisibility current,
  ) {
    if (previous == current) return false;
    if (previous == EventVisibility.private) {
      return current == EventVisibility.restricted ||
          current == EventVisibility.public;
    }
    if (previous == EventVisibility.restricted) {
      return current == EventVisibility.public;
    }
    return false;
  }

  void _notifyVisibilityWidenedBestEffort(
    String eventId,
    EventVisibility previousVisibility,
  ) {
    unawaited(
      _invokeNotifyOnEvent({
        'event_id': eventId,
        'previous_visibility': previousVisibility.value,
      }),
    );
  }

  // ─── Modification ─────────────────────────────────────────────────────────────

  /// Met à jour un événement existant et retourne l'objet mis à jour.
  ///
  /// Si [previousVisibility] est renseigné et que la visibilité **s’élargit**
  /// (privé → restreint/public, restreint → public), une notification est envoyée
  /// aux utilisateurs qui **gagnent** l’accès.
  Future<AppEvent> updateEvent({
    required String eventId,
    required String title,
    String? description,
    required EventVisibility visibility,
    required EventCategory category,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? location,
    String? imageUrl,
    bool clearImage = false,
    String? instagramUrl,
    EventVisibility? previousVisibility,
  }) async {
    try {
      final data = await _client
          .from('events')
          .update({
            'title': title.trim(),
            'description':
                (description != null && description.trim().isNotEmpty)
                    ? description.trim()
                    : null,
            'visibility': visibility.value,
            'category': category.value,
            'event_date': eventDate?.toIso8601String(),
            'event_end_date': eventEndDate?.toIso8601String(),
            'location':
                (location != null && location.trim().isNotEmpty)
                    ? location.trim()
                    : null,
            if (clearImage)
              'image_url': null
            else if (imageUrl != null)
              'image_url': imageUrl,
            'instagram_url':
                (instagramUrl != null && instagramUrl.trim().isNotEmpty)
                    ? instagramUrl.trim()
                    : null,
          })
          .eq('id', eventId)
          .select(_eventSelect)
          .single();

      final updated = AppEvent.fromJson(data);
      if (previousVisibility != null &&
          _isVisibilityWidened(previousVisibility, visibility)) {
        _notifyVisibilityWidenedBestEffort(eventId, previousVisibility);
      }
      return updated;
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  // ─── Suppression ──────────────────────────────────────────────────────────────

  /// Supprime un événement par son identifiant.
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client.from('events').delete().eq('id', eventId);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}
