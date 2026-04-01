import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';

/// Statut enregistré pour un événement (au plus une ligne par utilisateur).
enum EventParticipationStatus {
  going,
  unavailable,
}

/// Inscriptions « Je participe » / « Indisponible » (table `event_participations`).
class EventParticipationService {
  final SupabaseClient _client = Supabase.instance.client;

  static EventParticipationStatus? _statusFromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final s = row['status'] as String?;
    if (s == 'unavailable') return EventParticipationStatus.unavailable;
    return EventParticipationStatus.going;
  }

  /// Statut de l’utilisateur connecté pour cet événement, ou `null` si aucune réponse.
  Future<EventParticipationStatus?> getMyStatus(String eventId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('event_participations')
          .select('status')
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .maybeSingle();
      return _statusFromRow(row);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Enregistre « je participe » ou « indisponible » (remplace l’autre si besoin).
  Future<void> setStatus(
    String eventId,
    EventParticipationStatus status,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AppException('Non connecté');
    }
    final statusStr =
        status == EventParticipationStatus.unavailable ? 'unavailable' : 'going';
    try {
      await _client.from('event_participations').upsert(
        {'event_id': eventId, 'user_id': uid, 'status': statusStr},
        onConflict: 'event_id,user_id',
      );
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Retire toute réponse (ni participe ni indisponible).
  Future<void> clearStatus(String eventId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AppException('Non connecté');
    }
    try {
      await _client
          .from('event_participations')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', uid);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Nombre de participants « going » (admin / responsables) via RPC.
  Future<int?> getParticipantCountForOrganizers(String eventId) async {
    try {
      final result = await _client.rpc(
        'event_participant_count',
        params: {'p_event_id': eventId},
      );
      if (result == null) return null;
      if (result is int) return result;
      if (result is num) return result.toInt();
      return int.tryParse(result.toString());
    } catch (_) {
      return null;
    }
  }

  /// Nombre d’indisponibilités (mêmes droits que [getParticipantCountForOrganizers]).
  Future<int?> getUnavailableCountForOrganizers(String eventId) async {
    try {
      final result = await _client.rpc(
        'event_unavailable_count',
        params: {'p_event_id': eventId},
      );
      if (result == null) return null;
      if (result is int) return result;
      if (result is num) return result.toInt();
      return int.tryParse(result.toString());
    } catch (_) {
      return null;
    }
  }
}
