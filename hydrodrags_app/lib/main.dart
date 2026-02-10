import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/language_service.dart';
import 'services/app_state_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/racer_profile_screen.dart';
import 'screens/server_unavailable_screen.dart';
import 'screens/event_registration_screen.dart';
import 'screens/waiver_overview_screen.dart';
import 'screens/waiver_reading_screen.dart';
import 'screens/waiver_signature_screen.dart';
import 'screens/registration_complete_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/spectator_purchase_screen.dart';
import 'models/event.dart';

void main() {
  if (kDebugMode) {
    debugPrint('[App] Starting - API_BASE_URL=${ApiConfig.baseUrl}');
  }
  runApp(const HydroDragsApp());
}

class HydroDragsApp extends StatelessWidget {
  const HydroDragsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => AppStateService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: Consumer2<LanguageService, AuthService>(
        builder: (context, languageService, authService, child) {
          return MaterialApp(
            title: 'HydroDrags',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            locale: languageService.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _AuthWrapper(),
            routes: {
              '/main': (context) => const MainNavigationScreen(),
              '/racer-profile': (context) => const RacerProfileScreen(),
              '/event-registration': (context) {
                final event = ModalRoute.of(context)?.settings.arguments;
                return EventRegistrationScreen(event: event is Event ? event : null);
              },
              '/waiver-overview': (context) => const WaiverOverviewScreen(),
              '/waiver-reading': (context) => const WaiverReadingScreen(),
              '/waiver-signature': (context) => const WaiverSignatureScreen(),
              '/registration-complete': (context) => const RegistrationCompleteScreen(),
              '/checkout': (context) => const CheckoutScreen(),
              '/spectator-purchase': (context) {
                final event = ModalRoute.of(context)?.settings.arguments;
                if (event is! Event) {
                  return const Scaffold(
                    body: Center(child: Text('Event required')),
                  );
                }
                return SpectatorPurchaseScreen(event: event);
              },
            },
          );
        },
      ),
    );
  }
}

/// Wrapper widget that checks auth status and routes accordingly
class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading while checking auth status
        if (authService.isLoading && authService.status == AuthStatus.unauthenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Route based on auth status
        if (authService.isServerUnavailable) {
          // Server is unavailable - show error screen
          return const ServerUnavailableScreen();
        } else if (authService.isAuthenticated) {
          // User is authenticated, check profile completion
          if (authService.profileComplete) {
            // Profile is complete, go to main navigation screen
            return const MainNavigationScreen();
          } else {
            // Profile is not complete, go to profile screen
            return const RacerProfileScreen();
          }
        } else {
          // User is not authenticated, show login
          return const LoginScreen();
        }
      },
    );
  }
}