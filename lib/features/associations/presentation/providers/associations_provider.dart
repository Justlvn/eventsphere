import 'package:flutter/foundation.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../models/association.dart';
import '../../data/association_service.dart';

enum AssociationsStatus { initial, loading, loaded, error }

class AssociationsProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final AssociationService _service;

  AssociationsProvider(this._authProvider, this._service) {
    _authProvider.addListener(_onAuthChanged);
    if (_authProvider.isAuthenticated) _loadAssociations();
  }

  AssociationsStatus _status = AssociationsStatus.initial;
  List<Association> _associations = [];
  String? _errorMessage;

  AssociationsStatus get status => _status;
  List<Association> get associations => _associations;
  String? get errorMessage => _errorMessage;

  Future<void> refresh() => _loadAssociations();

  /// Met à jour une association dans le cache (ex. après édition depuis le détail).
  void replaceAssociationInList(Association updated) {
    final i = _associations.indexWhere((a) => a.id == updated.id);
    if (i != -1) {
      _associations[i] = updated;
      notifyListeners();
    }
  }

  /// Crée une association et l'insère dans la liste locale triée.
  /// Retourne l'association créée, ou lance une exception en cas d'erreur.
  Future<Association> createAssociation({
    required String name,
    String? description,
  }) async {
    final newAsso = await _service.createAssociation(
      name: name,
      description: description,
    );
    _associations
      ..add(newAsso)
      ..sort((a, b) => a.name.compareTo(b.name));
    _status = AssociationsStatus.loaded;
    notifyListeners();
    return newAsso;
  }

  Future<void> _loadAssociations() async {
    _status = AssociationsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _associations = await _service.fetchAssociations();
      _status = AssociationsStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AssociationsStatus.error;
      _associations = [];
    }

    notifyListeners();
  }

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated) {
      _loadAssociations();
    } else {
      _associations = [];
      _status = AssociationsStatus.initial;
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
