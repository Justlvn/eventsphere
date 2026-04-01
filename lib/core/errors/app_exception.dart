import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception applicative unifiée.
///
/// Tous les services wrappent leurs erreurs dans [AppException] afin que
/// les providers et les écrans reçoivent toujours un message lisible en
/// français, sans avoir à interpréter les codes Supabase/Postgres.
class AppException implements Exception {
  final String message;

  /// Exception d'origine (PostgrestException, SocketException, etc.)
  final Object? cause;

  const AppException(this.message, {this.cause});

  /// Construit une [AppException] à partir de n'importe quelle exception.
  ///
  /// Mappe les codes Supabase/Postgres courants vers des messages lisibles.
  factory AppException.fromError(Object e) {
    if (e is AppException) return e;

    if (e is PostgrestException) {
      final msg = _mapPostgrestCode(e.code, e.message);
      return AppException(msg, cause: e);
    }

    // Réseau / socket
    final str = e.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network')) {
      return AppException(
        'Vérifiez votre connexion internet.',
        cause: e,
      );
    }

    // Timeout
    if (str.contains('timeout') || str.contains('timeoutexception')) {
      return AppException(
        'La requête a pris trop de temps. Réessayez.',
        cause: e,
      );
    }

    // Fallback : message brut nettoyé
    return AppException(_clean(e.toString()), cause: e);
  }

  static String _mapPostgrestCode(String? code, String rawMessage) {
    switch (code) {
      // Auth / permissions
      case '42501':
        return 'Accès refusé. Vous n\'avez pas les permissions nécessaires.';
      case 'PGRST301':
        return 'Session expirée. Veuillez vous reconnecter.';
      // Contrainte d'unicité
      case '23505':
        return 'Cet enregistrement existe déjà.';
      // Contrainte de clé étrangère
      case '23503':
        return 'Référence introuvable. L\'élément lié n\'existe pas.';
      // NOT NULL violation
      case '23502':
        return 'Des informations obligatoires sont manquantes.';
      // Résultat vide (single() sans résultat)
      case 'PGRST116':
        return 'Élément introuvable.';
      default:
        return _clean(rawMessage);
    }
  }

  static String _clean(String raw) {
    // Retirer les préfixes techniques courants
    var s = raw
        .replaceAll('PostgrestException(', '')
        .replaceAll('Exception: ', '')
        .replaceAll('Exception:', '')
        .trim();
    if (s.endsWith(')')) s = s.substring(0, s.length - 1).trim();
    // Capitaliser
    if (s.isNotEmpty) s = s[0].toUpperCase() + s.substring(1);
    return s.isEmpty ? 'Une erreur inattendue est survenue.' : s;
  }

  @override
  String toString() => message;
}
