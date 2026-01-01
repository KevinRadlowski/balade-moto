import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/navigation/step_by_step_navigation_screen.dart';
import 'services/navigation/navigation_service.dart';

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
    // Si l'utilisateur n'est plus authentifié, rediriger vers login
    if (!authService.isAuthenticated && navigatorKey.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          final context = navigatorKey.currentContext!;
          // Vérifier qu'on n'est pas déjà sur l'écran de login ou splash
          final currentRoute = ModalRoute.of(context);
          final routeName = currentRoute?.settings.name;
          
          if (routeName != '/login' && 
              routeName != '/verify-email' &&
              routeName != '/') {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        }
      });
    }
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
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Balades Moto',
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
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const SplashScreen(),
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
      ),
    );
  }
}

