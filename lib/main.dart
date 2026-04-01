import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/associations/data/association_service.dart';
import 'features/associations/presentation/providers/associations_provider.dart';
import 'features/events/data/event_service.dart';
import 'features/events/presentation/providers/events_provider.dart';
import 'features/user/data/user_service.dart';
import 'features/user/presentation/providers/user_provider.dart';
import 'core/services/permission_service.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('fr_FR');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  try {
    await PushNotificationService.instance.init();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('PushNotificationService: échec init — $e\n$st');
    }
  }

  runApp(const EventSphereApp());
}

class EventSphereApp extends StatelessWidget {
  const EventSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) {
            final provider = AuthProvider(AuthService());
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (context) => UserProvider(
            context.read<AuthProvider>(),
            UserService(),
          ),
          update: (context, auth, previous) =>
              previous ?? UserProvider(auth, UserService()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, EventsProvider>(
          create: (context) => EventsProvider(
            context.read<AuthProvider>(),
            EventService(),
          ),
          update: (context, auth, previous) =>
              previous ?? EventsProvider(auth, EventService()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AssociationsProvider>(
          create: (context) => AssociationsProvider(
            context.read<AuthProvider>(),
            AssociationService(),
          ),
          update: (context, auth, previous) =>
              previous ?? AssociationsProvider(auth, AssociationService()),
        ),
        // PermissionService se recalcule à chaque changement de UserProvider.
        ProxyProvider<UserProvider, PermissionService>(
          create: (context) {
            final up = context.read<UserProvider>();
            return PermissionService(
              user: up.user,
              memberships: up.memberships,
            );
          },
          update: (context, userProvider, _) => PermissionService(
            user: userProvider.user,
            memberships: userProvider.memberships,
          ),
        ),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouterWrapper _routerWrapper;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _routerWrapper = GoRouterWrapper(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp.router(
      title: 'EventSphere',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      locale: const Locale('fr', 'FR'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _routerWrapper.router,
    );
  }

  @override
  void dispose() {
    _routerWrapper.dispose();
    super.dispose();
  }
}

class GoRouterWrapper {
  final AuthProvider _authProvider;
  late final router = createRouter(_authProvider);

  GoRouterWrapper(this._authProvider);

  void dispose() => router.dispose();
}
