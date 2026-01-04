import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'constants/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/navigation/step_by_step_navigation_screen.dart';
import 'services/navigation/navigation_service.dart';
import 'services/navigation_state.dart';
import 'providers/feedback_provider.dart';
import 'providers/live_ride_provider.dart';
import 'providers/compatibility_provider.dart';
import 'providers/vehicle_stats_provider.dart';
import 'providers/maintenance_reminder_provider.dart';
import 'providers/emergency_contact_provider.dart';
import 'providers/check_in_provider.dart';

/// Widget qui limite la largeur maximale de l'application à 400px sur desktop
/// et centre le contenu horizontalement
Widget _maxWidthBuilder(BuildContext context, Widget? child) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 400) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: child,
          ),
        );
      }
      return child ?? const SizedBox();
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser les données de locale pour le formatage des dates en français
  await initializeDateFormatting('fr_FR', null);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final ApiService apiService;
  late final AuthService authService;

  @override
  void initState() {
    super.initState();
    apiService = ApiService();
    authService = AuthService(
      storage: const FlutterSecureStorage(),
      apiService: apiService,
    );
    
    // Configurer le callback de rafraîchissement du token
    apiService.setOnTokenRefresh(() async {
      await authService.refreshToken();
    });
    
    // Configurer le callback de déconnexion automatique
    apiService.setOnTokenExpired(() {
      authService.logout();
    });
    
    // Écouter les changements d'authentification pour rediriger
    authService.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    // Ne pas rediriger pendant l'initialisation ou le chargement
    // La redirection se fait uniquement via le Consumer dans build()
    // Ne jamais basculer d'écran avec isLoading
  }

  @override
  void dispose() {
    authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: authService,
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationState(),
        ),
        ChangeNotifierProvider(
          create: (_) => FeedbackProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => LiveRideProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CompatibilityProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => VehicleStatsProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => MaintenanceReminderProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => EmergencyContactProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CheckInProvider(apiService: apiService),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          // Afficher SplashScreen uniquement si isInitializing
          if (authService.isInitializing) {
            return MaterialApp(
              title: 'RideTogether',
              debugShowCheckedModeBanner: false,
              locale: const Locale('fr', 'FR'),
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('fr', 'FR'),
                Locale('en', 'US'),
              ],
              theme: AppTheme.lightTheme,
              builder: _maxWidthBuilder,
              home: const SplashScreen(),
            );
          }
          
          // Sinon, afficher LoginScreen ou MainNavigation selon isAuthenticated
          // Ne jamais basculer d'écran avec isLoading
          final homeWidget = authService.isAuthenticated 
              ? const MainNavigation() 
              : const LoginScreen();
          
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'RideTogether',
            debugShowCheckedModeBanner: false,
            locale: const Locale('fr', 'FR'),
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'),
              Locale('en', 'US'),
            ],
            theme: AppTheme.lightTheme,
            builder: _maxWidthBuilder,
            home: homeWidget,
            routes: {
              '/login': (context) => const LoginScreen(),
            },
            onGenerateRoute: (settings) {
              // Gérer les liens de vérification d'email
              if (settings.name?.startsWith('/verify-email') == true) {
                final uri = Uri.parse(settings.name!);
                final token = uri.queryParameters['token'];
                if (token != null) {
                  return MaterialPageRoute(
                    builder: (_) => VerifyEmailScreen(token: token),
                  );
                }
              }
              // Gérer la navigation par étapes
              if (settings.name == '/step-by-step-navigation') {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null) {
                  return MaterialPageRoute(
                    builder: (_) => StepByStepNavigationScreen(
                      rideId: args['rideId'] as String,
                      route: args['route'] as NavigationRoute,
                      providerId: args['providerId'] as String,
                    ),
                  );
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
