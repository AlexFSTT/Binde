import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviciu pentru gestionarea profilului utilizatorului
class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține profilul utilizatorului curent
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Actualizează profilul utilizatorului
  Future<ProfileResult> updateProfile({
    String? fullName,
    String? bio,
    String? avatarUrl,
    required String username, // ✅ Parametru obligatoriu
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      final updates = <String, dynamic>{
        'id': userId, // ✅ ADĂUGAT pentru upsert
        'username': username, // ✅ ADĂUGAT - ACESTA ERA PROBLEMA!
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      // ✅ SCHIMBAT de la .update() la .upsert() pentru consistență
      await _supabase
          .from('profiles')
          .upsert(updates);

      // Actualizează și metadata din auth dacă s-a schimbat numele
      if (fullName != null) {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }

      return ProfileResult.success('Profil actualizat cu succes!');
    } catch (e) {
      // ✅ ADĂUGAT: Error handling pentru username duplicat
      if (e.toString().contains('duplicate key') || 
          e.toString().contains('unique constraint') ||
          e.toString().contains('profiles_username_key')) {
        return ProfileResult.error('Username-ul este deja folosit. Alege altul.');
      }
      
      return ProfileResult.error('Eroare la actualizare: $e');
    }
  }

  /// Uploadează avatar și returnează URL-ul
  Future<ProfileResult> uploadAvatar(String filePath) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      final file = File(filePath);
      final fileExt = filePath.split('.').last.toLowerCase();
      final fileName = '$userId/avatar.$fileExt';

      // Încarcă fișierul în Supabase Storage
      await _supabase.storage.from('avatars').upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // Obține URL-ul public
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

      // Adaugă timestamp pentru a forța reîncărcarea imaginii
      final urlWithTimestamp = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Actualizează profilul cu noul URL
      await _supabase
          .from('profiles')
          .update({'avatar_url': urlWithTimestamp, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      return ProfileResult.success(urlWithTimestamp);
    } catch (e) {
      return ProfileResult.error('Eroare la upload: $e');
    }
  }

  /// Șterge avatarul curent
  Future<ProfileResult> deleteAvatar() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      // Listează fișierele din folderul utilizatorului
      final files = await _supabase.storage.from('avatars').list(path: userId);

      // Șterge toate fișierele (avatar-ul)
      if (files.isNotEmpty) {
        final paths = files.map((f) => '$userId/${f.name}').toList();
        await _supabase.storage.from('avatars').remove(paths);
      }

      // Actualizează profilul - elimină URL-ul
      await _supabase
          .from('profiles')
          .update({'avatar_url': null, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      return ProfileResult.success('Avatar șters cu succes!');
    } catch (e) {
      return ProfileResult.error('Eroare la ștergere: $e');
    }
  }
}

/// Clasă pentru rezultatul operațiilor pe profil
class ProfileResult {
  final bool isSuccess;
  final String message;

  ProfileResult._({required this.isSuccess, required this.message});

  factory ProfileResult.success(String message) {
    return ProfileResult._(isSuccess: true, message: message);
  }

  factory ProfileResult.error(String message) {
    return ProfileResult._(isSuccess: false, message: message);
  }
}