import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../models/event.dart';
import '../../models/membership.dart';

/// Source unique de vérité pour toutes les permissions de l'application.
///
/// Instancié via [ProxyProvider] dans [main.dart] : se met à jour
/// automatiquement à chaque changement de [UserProvider].
///
/// Usage dans un widget :
/// ```dart
/// final p = context.watch<PermissionService>();
/// if (p.canCreateEvent(associationId)) { ... }
/// ```
class PermissionService {
  final AppUser? _user;
  final List<Membership> _memberships;

  const PermissionService({
    AppUser? user,
    List<Membership> memberships = const [],
  })  : _user = user,
        _memberships = memberships;

  // ─── Rôle global ────────────────────────────────────────────────────────────

  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Vrai si l'utilisateur est responsable d'au moins une association.
  bool get isResponsibleAnywhere =>
      _memberships.any((m) => m.role == AssociationRole.responsible);

  /// Vrai si l'utilisateur appartient à au moins une association.
  bool get hasAnyMembership => _memberships.isNotEmpty;

  // ─── Rôle dans une association donnée ───────────────────────────────────────

  bool isResponsibleOf(String associationId) => _memberships.any(
        (m) =>
            m.associationId == associationId &&
            m.role == AssociationRole.responsible,
      );

  bool isMemberOf(String associationId) =>
      _memberships.any((m) => m.associationId == associationId);

  // ─── Permissions sur les associations ───────────────────────────────────────

  /// Seul un admin peut créer une association.
  bool get canCreateAssociation => isAdmin;

  /// Un admin peut modifier toutes les associations.
  /// Un responsable peut modifier son association.
  bool canEditAssociation(String associationId) =>
      isAdmin || isResponsibleOf(associationId);

  /// Seul un admin peut supprimer une association.
  bool canDeleteAssociation(String associationId) => isAdmin;

  /// Admin ou responsable de l'association.
  bool canManageAssociation(String associationId) =>
      isAdmin || isResponsibleOf(associationId);

  // ─── Permissions sur les membres ────────────────────────────────────────────

  /// Admin ou responsable de l'association.
  bool canAddMember(String associationId) =>
      isAdmin || isResponsibleOf(associationId);

  /// Admin ou responsable de l'association.
  bool canRemoveMember(String associationId) =>
      isAdmin || isResponsibleOf(associationId);

  /// Seul un admin peut nommer un responsable.
  bool canSetResponsible(String associationId) => isAdmin;

  // ─── Permissions sur les événements ─────────────────────────────────────────

  /// Admin ou responsable de l'association organisatrice.
  bool canCreateEvent(String? associationId) {
    if (isAdmin) return true;
    if (associationId == null) return false;
    return isResponsibleOf(associationId);
  }

  /// Admin ou responsable de l'association organisatrice.
  bool canEditEvent(String? associationId) => canCreateEvent(associationId);

  /// Admin ou responsable de l'association organisatrice.
  bool canDeleteEvent(String? associationId) => canCreateEvent(associationId);

  /// Seuls les **admins** peuvent créer ou passer un événement en **public**.
  /// Les responsables d'association ne peuvent publier qu'en restreint ou privé.
  bool get canPublishEventAsPublic => isAdmin;

  /// Voir le **nombre** de participants (pas les noms) — admin ou responsable de l’asso organisatrice.
  bool canViewEventParticipantCount(String? associationId) =>
      canCreateEvent(associationId);

  /// Détermine si l'utilisateur peut voir un événement selon sa visibilité.
  ///
  /// Note : le filtrage est déjà géré par les RLS Supabase.
  /// Cette méthode sert à l'affichage conditionnel côté UI (badges, boutons…).
  bool canSeeEvent(AppEvent event) {
    switch (event.visibility) {
      case EventVisibility.public:
        return true;
      case EventVisibility.restricted:
        return isAdmin ||
            (event.associationId != null &&
                isMemberOf(event.associationId!));
      case EventVisibility.private:
        // Tout responsable (au moins une association), pas seulement celle de l’événement.
        return isAdmin || isResponsibleAnywhere;
    }
  }

  // ─── Permissions globales (admin) ────────────────────────────────────────────

  bool get canManageAllUsers => isAdmin;
  bool get canManageAllEvents => isAdmin;
  bool get canManageAllAssociations => isAdmin;
}
