import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Service pentru criptarea end-to-end a mesajelor
/// Folosește AES-256 pentru criptare simetrică
/// 
/// IMPORTANT: Într-o aplicație de producție, ar trebui să folosești
/// un sistem de gestionare a cheilor mai sofisticat (ex: RSA + AES)
class EncryptionService {
  // În producție, cheia ar trebui generată și stocată în siguranță
  // Pentru acest demo, folosim o cheie derivată din ID-ul conversației
  
  /// Generează o cheie de criptare pentru o conversație
  /// Bazată pe ID-ul conversației (în producție, folosește un sistem mai complex)
  encrypt.Key _generateKey(String conversationId) {
    // Creăm un hash SHA-256 din ID-ul conversației
    final bytes = utf8.encode(conversationId);
    final hash = sha256.convert(bytes);
    
    // Folosim primii 32 de bytes pentru cheia AES-256
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// Generează un IV (Initialization Vector) pentru AES
  encrypt.IV _generateIV() {
    // În producție, ar trebui să fie aleatoriu și stocat cu mesajul
    // Pentru simplitate, folosim un IV fix (NU FACE ASTA ÎN PRODUCȚIE!)
    return encrypt.IV.fromLength(16);
  }

  /// Criptează un mesaj
  /// Returnează textul criptat în format Base64
  String encryptMessage(String plaintext, String conversationId) {
    try {
      final key = _generateKey(conversationId);
      final iv = _generateIV();
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      
      return encrypted.base64;
    } catch (e) {
      debugPrint('Error encrypting message: $e');
      // În caz de eroare, returnăm textul original (NU FACE ASTA ÎN PRODUCȚIE!)
      return plaintext;
    }
  }

  /// Decriptează un mesaj
  /// Primește textul criptat în format Base64
  String decryptMessage(String encryptedText, String conversationId) {
    try {
      final key = _generateKey(conversationId);
      final iv = _generateIV();
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      
      return decrypted;
    } catch (e) {
      debugPrint('Error decrypting message: $e');
      // În caz de eroare, returnăm textul așa cum este
      return encryptedText;
    }
  }

  /// Verifică dacă un text este criptat (verificare simplă)
  bool isEncrypted(String text) {
    // Verificăm dacă textul arată ca Base64
    try {
      base64.decode(text);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// NOTĂ IMPORTANTĂ DESPRE SECURITATE:
/// 
/// Această implementare este un DEMO SIMPLIFICAT al criptării E2E.
/// Pentru o aplicație de producție REALĂ, trebuie să implementezi:
/// 
/// 1. **Schimb de chei Diffie-Hellman** - Pentru a genera chei unice pentru fiecare conversație
/// 2. **RSA pentru schimbul inițial de chei** - Pentru a cripta cheile AES
/// 3. **IV aleatoriu** - Generează un IV nou pentru fiecare mesaj
/// 4. **Stocare securizată a cheilor** - Folosește Flutter Secure Storage sau Keychain
/// 5. **Perfect Forward Secrecy** - Folosește protocoale ca Signal Protocol
/// 6. **Autentificare a mesajelor** - HMAC pentru a verifica integritatea
/// 7. **Rotație de chei** - Schimbă cheile periodic
/// 
/// Resurse recomandate:
/// - Signal Protocol: https://signal.org/docs/
/// - libsodium: https://libsodium.gitbook.io/
/// - Package Flutter: pointycastle pentru criptografie avansată
