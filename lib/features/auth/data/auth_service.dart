import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/validation/devinci_email.dart';
import '../../../models/app_user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Connecte un utilisateur existant et retourne son profil.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw Exception('Connexion échouée : aucun utilisateur retourné.');
    }

    return _fetchUserProfile(userId);
  }

  /// Crée un compte Supabase Auth.
  ///
  /// Le nom et le code admin sont passés en metadata.
  /// Un trigger Postgres (`on_auth_user_created`) se charge d'insérer
  /// la ligne dans `public.users` et d'attribuer le bon rôle.
  ///
  /// La confirmation email étant activée, aucune session n'est ouverte
  /// immédiatement : l'utilisateur doit confirmer son email puis se connecter.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String? adminCode,
  }) async {
    if (!isDevinciInstitutionEmail(email)) {
      throw Exception(kDevinciEmailRequirementMessage);
    }

    final metadata = <String, dynamic>{'name': name};
    if (adminCode != null && adminCode.isNotEmpty) {
      metadata['admin_code'] = adminCode;
    }

    await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  /// Déconnecte l'utilisateur courant.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Récupère le profil de l'utilisateur connecté depuis public.users.
  /// Retourne null si aucune session active.
  Future<AppUser?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    return _fetchUserProfile(session.user.id);
  }

  Future<AppUser> _fetchUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return AppUser.fromJson(data);
  }
}
