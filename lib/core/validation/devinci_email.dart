/// Emails autorisés à l’inscription : domaine `devinci.fr` ou `edu.devinci.fr` (insensible à la casse).
bool isDevinciInstitutionEmail(String email) {
  final normalized = email.trim().toLowerCase();
  final at = normalized.lastIndexOf('@');
  if (at <= 0 || at >= normalized.length - 1) return false;
  final host = normalized.substring(at + 1);
  return host == 'devinci.fr' || host == 'edu.devinci.fr';
}

const String kDevinciEmailRequirementMessage =
    'Seules les adresses @devinci.fr ou @edu.devinci.fr sont acceptées pour créer un compte.';
