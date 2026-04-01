import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';

/// Canal Android pour les notifications affichées au premier plan.
const _androidChannelId = 'eventsphere_high_importance';

/// Handler en arrière-plan (doit être une fonction de premier niveau).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('FCM background: ${message.messageId}');
  }
}

/// Enregistre le token FCM dans Supabase et affiche les notifs au premier plan.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  /// Ne doit être utilisé qu’après [Firebase.initializeApp] dans [init].
  FirebaseMessaging? _messaging;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Conservé pour supprimer le token en base à la déconnexion (currentUser peut être null).
  String? _registeredUserId;
  String? _registeredToken;

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (kDebugMode) {
        debugPrint(
          'PushNotificationService: uniquement Android (FCM).',
        );
      }
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onLocalTap,
      );

      await _ensureAndroidChannel();

      final messaging = _messaging!;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          unawaited(registerDeviceToken());
        } else {
          unawaited(unregisterDeviceToken());
        }
      });

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await registerDeviceToken();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'PushNotificationService: Firebase / notifications — $e\n$st',
        );
      }
      _messaging = null;
    }

    _initialized = true;
  }

  void _onLocalTap(NotificationResponse response) {
    // Navigation profonde possible via response.payload
  }

  Future<void> _ensureAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      'Événements',
      description: 'Nouveaux événements visibles pour vous',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final n = message.notification;
    final dataTitle = message.data['event_title'] as String?;
    var title = (n?.title ?? '').trim();
    if (title.isEmpty) {
      title = (dataTitle ?? '').trim();
    }
    if (title.isEmpty) title = 'EventSphere';

    var body = (n?.body ?? '').trim();
    if (body.isEmpty) {
      body = 'Nouvel événement — ouvre l’app pour les détails.';
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        'Événements',
        channelDescription: 'Nouveaux événements visibles pour vous',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _local.show(
      message.hashCode,
      title,
      body,
      details,
      payload: message.data['event_id'] as String?,
    );
  }

  /// Enregistre ou met à jour le token pour l’utilisateur connecté.
  Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('user_fcm_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );

      _registeredUserId = userId;
      _registeredToken = token;

      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((newToken) async {
        final uid = _registeredUserId ??
            Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        try {
          await Supabase.instance.client.from('user_fcm_tokens').upsert(
            {
              'user_id': uid,
              'token': newToken,
              'platform': 'android',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'user_id,token',
          );
          _registeredToken = newToken;
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('FCM token refresh save: $e\n$st');
          }
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PushNotificationService.register: $e\n$st');
      }
    }
  }

  /// Supprime les lignes de token pour l’utilisateur qui se déconnecte.
  Future<void> unregisterDeviceToken() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      final userId = _registeredUserId ??
          Supabase.instance.client.auth.currentUser?.id;
      final token = _registeredToken ?? await messaging.getToken();
      if (userId != null && token != null) {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
      }
      await messaging.deleteToken();
      _registeredUserId = null;
      _registeredToken = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotificationService.unregister: $e');
      }
    }
  }
}
