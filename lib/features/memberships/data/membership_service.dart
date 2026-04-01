import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/enums.dart';
import '../../../models/membership.dart';

class MembershipService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Récupère les membres responsables d'une association avec les infos
  /// utilisateur embarquées (join `users(*)`).
  Future<List<Membership>> fetchResponsiblesOfAssociation(
    String associationId,
  ) async {
    try {
      final data = await _client
          .from('memberships')
          .select('*, users(id, name, email, role, created_at)')
          .eq('association_id', associationId)
          .eq('role', AssociationRole.responsible.value);

      return (data as List)
          .map((json) => Membership.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Récupère tous les memberships d'une association (responsables + membres)
  /// avec les infos utilisateur embarquées.
  Future<List<Membership>> fetchAllMembershipsOfAssociation(
    String associationId,
  ) async {
    try {
      final data = await _client
          .from('memberships')
          .select('*, users(id, name, email, role, created_at)')
          .eq('association_id', associationId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((json) => Membership.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Crée un membership et retourne l'objet créé.
  /// Les doublons (même user + même asso + même rôle) sont rejetés par la BDD.
  Future<Membership> createMembership({
    required String userId,
    required String associationId,
    required AssociationRole role,
  }) async {
    try {
      final data = await _client
          .from('memberships')
          .insert({
            'user_id': userId,
            'association_id': associationId,
            'role': role.value,
          })
          .select()
          .single();

      return Membership.fromJson(data);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Supprime un membership par son identifiant.
  Future<void> deleteMembership(String membershipId) async {
    try {
      await _client.from('memberships').delete().eq('id', membershipId);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}
