import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  // Asigură inițializarea Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inițializează Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  
  runApp(
    const ProviderScope(
      child: BindeApp(),
    ),
  );
}

// Acces rapid la clientul Supabase
final supabase = Supabase.instance.client;

class BindeApp extends StatelessWidget {
  const BindeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// AuthGate - Decide ce ecran să afișeze bazat pe starea de autentificare
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Verifică dacă utilizatorul e logat
        final session = supabase.auth.currentSession;
        
        if (session != null) {
          // Utilizator logat -> arată ecranul principal
          return const HomeScreen();
        } else {
          // Utilizator nelogat -> arată ecranul de login
          return const LoginScreen();
        }
      },
    );
  }
}