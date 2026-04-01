import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/enums.dart';
import '../../../models/membership.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Récupère le profil complet de l'utilisateur depuis public.users.
  Future<AppUser> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return AppUser.fromJson(data);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Récupère tous les utilisateurs de l'application.
  /// Nécessite le rôle admin ou responsable (policy RLS).
  Future<List<AppUser>> fetchAllUsers() async {
    try {
      final data = await _client
          .from('users')
          .select()
          .order('name', ascending: true);

      return (data as List)
          .map((json) => AppUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Met à jour le rôle global (admin / student). Réservé aux admins (RLS).
  Future<void> updateGlobalRole(String userId, GlobalRole role) async {
    try {
      await _client
          .from('users')
          .update({'role': role.value})
          .eq('id', userId);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  /// Récupère tous les memberships de l'utilisateur avec les données
  /// de l'association embarquées (join `associations(*)`).
  Future<List<Membership>> fetchMemberships(String userId) async {
    try {
      final data = await _client
          .from('memberships')
          .select('*, associations(*)')
          .eq('user_id', userId);

      return (data as List)
          .map((json) => Membership.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}
