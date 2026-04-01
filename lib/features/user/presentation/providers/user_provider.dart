import 'package:flutter/foundation.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../models/app_user.dart';
import '../../../../models/enums.dart';
import '../../../../models/membership.dart';
import '../../data/user_service.dart';

enum UserDataStatus { initial, loading, loaded, error }

class UserProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final UserService _userService;

  UserProvider(this._authProvider, this._userService) {
    _authProvider.addListener(_onAuthChanged);
    // Chargement immédiat si déjà authentifié au moment de la création.
    if (_authProvider.isAuthenticated) {
      _loadUserData();
    }
  }

  UserDataStatus _status = UserDataStatus.initial;
  List<Membership> _memberships = [];
  String? _errorMessage;

  UserDataStatus get status => _status;
  List<Membership> get memberships => _memberships;
  String? get errorMessage => _errorMessage;

  // ─── Raccourcis vers les données du user authentifié ─────────────────────

  /// Profil de base du user connecté (depuis AuthProvider).
  AppUser? get user => _authProvider.user;

  /// Rôle global : admin ou student.
  GlobalRole? get globalRole => user?.role;

  bool get isAdmin => user?.isAdmin ?? false;

  /// True si le user est responsable d'au moins une association.
  bool get isResponsible =>
      _memberships.any((m) => m.role == AssociationRole.responsible);

  /// True si le user est membre (ou responsable) d'au moins une association.
  bool get hasAnyMembership => _memberships.isNotEmpty;

  /// Associations dont le user est responsable.
  List<Membership> get responsibleMemberships =>
      _memberships.where((m) => m.role == AssociationRole.responsible).toList();

  /// Associations dont le user est simple membre.
  List<Membership> get memberOnlyMemberships =>
      _memberships.where((m) => m.role == AssociationRole.member).toList();

  /// Retourne true si le user est responsable de l'association donnée.
  bool isResponsibleOf(String associationId) {
    return _memberships.any(
      (m) =>
          m.associationId == associationId &&
          m.role == AssociationRole.responsible,
    );
  }

  /// Retourne true si le user est membre (ou responsable) de l'association donnée.
  bool isMemberOf(String associationId) {
    return _memberships.any((m) => m.associationId == associationId);
  }

  // ─── Chargement des données ───────────────────────────────────────────────

  /// Recharge le profil et les memberships depuis Supabase.
  Future<void> refresh() => _loadUserData();

  Future<void> _loadUserData() async {
    final userId = _authProvider.user?.id;
    if (userId == null) return;

    _status = UserDataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _memberships = await _userService.fetchMemberships(userId);
      _status = UserDataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = UserDataStatus.error;
      _memberships = [];
    }

    notifyListeners();
  }

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated) {
      _loadUserData();
    } else {
      _memberships = [];
      _status = UserDataStatus.initial;
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
