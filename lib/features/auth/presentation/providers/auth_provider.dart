import 'package:flutter/foundation.dart';
import '../../../../models/app_user.dart';
import '../../data/auth_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  emailConfirmationPending,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  AuthStatus _status = AuthStatus.initial;
  AppUser? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Chargé au démarrage de l'app pour restaurer la session.
  Future<void> initialize() async {
    _setLoading();
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading();
    try {
      _user = await _authService.signIn(email: email, password: password);
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_extractMessage(e));
      return false;
    }
  }

  /// Lance l'inscription. En cas de succès, le statut passe à
  /// [AuthStatus.emailConfirmationPending] : l'utilisateur doit confirmer
  /// son email avant de pouvoir se connecter.
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? adminCode,
  }) async {
    _setLoading();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        adminCode: adminCode,
      );
      _status = AuthStatus.emailConfirmationPending;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_extractMessage(e));
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading();
    await _authService.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Recharge le profil depuis `public.users` (ex. après changement de rôle par un admin).
  Future<void> refreshProfile() async {
    try {
      final u = await _authService.getCurrentUser();
      if (u != null) {
        _user = u;
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  String _extractMessage(Object e) {
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return e.toString();
  }
}
