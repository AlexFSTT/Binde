import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<AuthResult> signOut() async {
    try {
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
      return 'Parola trebuie să aibă minim 6 caractere.';
    }
    if (error.contains('Invalid email')) {
      return 'Adresa de email nu este validă.';
    }
    return error;
  }
}

/// Clasă pentru rezultatul autentificării
class AuthResult {
  final bool isSuccess;
  final String message;
  
  AuthResult._({required this.isSuccess, required this.message});
  
  factory AuthResult.success(String message) {
    return AuthResult._(isSuccess: true, message: message);
  }
  
  factory AuthResult.error(String message) {
    return AuthResult._(isSuccess: false, message: message);
  }
}