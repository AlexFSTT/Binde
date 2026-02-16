import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

/// Serviciu pentru autentificare - gestionează login, register, logout
class AuthService {
  // Instanța Supabase
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Obține utilizatorul curent (null dacă nu e logat)
  User? get currentUser => _supabase.auth.currentUser;
  
  // Verifică dacă utilizatorul e logat
  bool get isLoggedIn => currentUser != null;
  
  // Stream pentru schimbări de autentificare
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  
  /// ÎNREGISTRARE cu email și parolă
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName}, // Salvează numele în metadata
      );
      
      if (response.user != null) {
        return AuthResult.success('Cont creat cu succes!');
      } else {
        return AuthResult.error('Nu s-a putut crea contul.');
      }
    } on AuthException catch (e) {
      return AuthResult.error(_translateError(e.message));
    } catch (e) {
      return AuthResult.error('Eroare neașteptată: $e');
    }
  }
  
  /// LOGIN cu email și parolă
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return AuthResult.success('Autentificare reușită!');
      } else {
        return AuthResult.error('Nu s-a putut autentifica.');
      }
    } on AuthException catch (e) {
      return AuthResult.error(_translateError(e.message));
    } catch (e) {
      return AuthResult.error('Eroare neașteptată: $e');
    }
  }
  
  /// LOGOUT
  /// ✅ FIX CRITIC: Șterge FCM token ÎNAINTE de sign out
  /// Fără asta, device-ul continuă să primească push notifications
  /// chiar dacă user-ul s-a delogat
  Future<AuthResult> signOut() async {
    try {
      // ✅ PASUL 1: Șterge FCM token-ul acestui device din baza de date
      // Trebuie făcut ÎNAINTE de signOut, pentru că avem nevoie de userId
      await NotificationService().removeFCMToken();
      
      // ✅ PASUL 2: Acum facem sign out
      await _supabase.auth.signOut();
      return AuthResult.success('Deconectat cu succes!');
    } catch (e) {
      return AuthResult.error('Eroare la deconectare: $e');
    }
  }
  
  /// RESETARE PAROLĂ
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return AuthResult.success('Email de resetare trimis! Verifică inbox-ul.');
    } on AuthException catch (e) {
      return AuthResult.error(_translateError(e.message));
    } catch (e) {
      return AuthResult.error('Eroare neașteptată: $e');
    }
  }
  
  /// Traduce erorile în română
  String _translateError(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Email sau parolă incorectă.';
    }
    if (error.contains('Email not confirmed')) {
      return 'Te rugăm să confirmi email-ul.';
    }
    if (error.contains('User already registered')) {
      return 'Acest email este deja înregistrat.';
    }
    if (error.contains('Password should be at least')) {
      return 'Parola trebuie să aibă cel puțin 6 caractere.';
    }
    return error;
  }
}

/// Model simplu pentru rezultatul autentificării
class AuthResult {
  final bool isSuccess;
  final String message;

  AuthResult._(this.isSuccess, this.message);

  factory AuthResult.success(String message) => AuthResult._(true, message);
  factory AuthResult.error(String message) => AuthResult._(false, message);
}