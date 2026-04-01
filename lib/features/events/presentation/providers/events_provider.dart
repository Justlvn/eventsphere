import 'package:flutter/foundation.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../models/association.dart';
import '../../../../models/enums.dart';
import '../../../../models/event.dart';
import '../../data/event_service.dart';

enum EventsStatus { initial, loading, loaded, error }

class EventsProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final EventService _eventService;

  EventsProvider(this._authProvider, this._eventService) {
    _authProvider.addListener(_onAuthChanged);
    if (_authProvider.isAuthenticated) _loadEvents();
  }

  EventsStatus _status = EventsStatus.initial;
  List<AppEvent> _events = [];
  String? _errorMessage;

  EventsStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Liste brute complète de tous les événements visibles.
  List<AppEvent> get allEvents => _events;

  /// Les 4 prochains événements (eventDate dans le futur), triés par date.
  List<AppEvent> get upcomingEvents {
    final now = DateTime.now();
    final filtered = _events
        .where((e) => e.eventDate != null && e.eventDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.eventDate!.compareTo(b.eventDate!));
    return filtered.take(4).toList();
  }

  Future<void> refresh() => _loadEvents();

  /// Met à jour un événement dans la liste locale et notifie les listeners.
  Future<AppEvent> updateEvent({
    required String eventId,
    required String title,
    String? description,
    required EventVisibility visibility,
    required EventCategory category,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? location,
    String? imageUrl,
    bool clearImage = false,
    String? instagramUrl,
    EventVisibility? previousVisibility,
  }) async {
    final updated = await _eventService.updateEvent(
      eventId: eventId,
      title: title,
      description: description,
      visibility: visibility,
      category: category,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      location: location,
      imageUrl: imageUrl,
      clearImage: clearImage,
      instagramUrl: instagramUrl,
      previousVisibility: previousVisibility,
    );
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) _events[index] = updated;
    notifyListeners();
    return updated;
  }

  /// Supprime un événement de la liste locale et notifie les listeners.
  Future<void> deleteEvent(String eventId) async {
    await _eventService.deleteEvent(eventId);
    _events.removeWhere((e) => e.id == eventId);
    notifyListeners();
  }

  /// Crée un événement, l'insère en tête de liste et notifie les listeners.
  /// Retourne l'événement créé ou lance une exception.
  Future<AppEvent> createEvent({
    required String title,
    String? description,
    required Association association,
    required EventVisibility visibility,
    required EventCategory category,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? location,
    String? imageUrl,
    String? instagramUrl,
  }) async {
    final newEvent = await _eventService.createEvent(
      title: title,
      description: description,
      associationId: association.id,
      visibility: visibility,
      category: category,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      location: location,
      imageUrl: imageUrl,
      instagramUrl: instagramUrl,
    );
    _events.insert(0, newEvent);
    notifyListeners();
    return newEvent;
  }

  Future<void> _loadEvents() async {
    _status = EventsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _eventService.fetchEvents();
      _status = EventsStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = EventsStatus.error;
      _events = [];
    }

    notifyListeners();
  }

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated) {
      _loadEvents();
    } else {
      _events = [];
      _status = EventsStatus.initial;
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
