import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'managers/app_lifecycle_manager.dart';
import 'services/notification_service.dart';

/// Instanța globală Supabase
final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // ✅ FIX: Inițializare notificări cu try-catch (nu crash-uim app-ul dacă Firebase e lipsă)
  try {
    await NotificationService().initialize();
    debugPrint('✅ Notifications initialized');
  } catch (e) {
    debugPrint('⚠️ Notifications failed to initialize: $e');
    // App-ul continuă să meargă chiar dacă notificările nu se inițializează
  }

  runApp(
    const ProviderScope(
      child: BindeApp(),
    ),
  );
}

class BindeApp extends ConsumerWidget {
  const BindeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    // Determină limba de utilizat
    Locale? locale;
    if (settings.languageCode != null) {
      locale = Locale(settings.languageCode!);
    }

    return AppLifecycleManager(
      child: MaterialApp(
        title: 'Binde',
        debugShowCheckedModeBanner: false,
        
        // Tema
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.flutterThemeMode,
        
        // Localizare
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (deviceLocale, supportedLocales) {
          if (locale != null) {
            return locale;
          }
          
          if (deviceLocale != null) {
            for (final supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == deviceLocale.languageCode) {
                return supportedLocale;
              }
            }
          }
          
          return const Locale('ro');
        },
        
        // Ecranul inițial
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Widget care verifică starea autentificării
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = supabase.auth.currentSession;
        if (session != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}