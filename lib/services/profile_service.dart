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

  /// Obține profilul unui user specific
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
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

  /// Actualizează profilul utilizatorului cu toate câmpurile
  Future<ProfileResult> updateProfile({
    required String username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? birthCity,
    double? birthCityLat,
    double? birthCityLng,
    String? birthDate,
    String? gender,
    String? currentCity,
    double? currentCityLat,
    double? currentCityLng,
    String? jobTitle,
    String? jobCompany,
    String? relationshipStatus,
    String? relationshipPartner,
    String? religion,
    String? languages,
    String? website,
    String? school,
    String? favoriteSports,
    String? favoriteTeams,
    String? favoriteGames,
    String? phone,
    String? contactVisibility,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      final updates = <String, dynamic>{
        'id': userId,
        'username': username,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Câmpuri de bază
      if (fullName != null) updates['full_name'] = fullName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (coverUrl != null) updates['cover_url'] = coverUrl;

      // Câmpuri noi
      updates['birth_city'] = birthCity;
      updates['birth_city_lat'] = birthCityLat;
      updates['birth_city_lng'] = birthCityLng;
      updates['birth_date'] = birthDate;
      updates['gender'] = gender;
      updates['current_city'] = currentCity;
      updates['current_city_lat'] = currentCityLat;
      updates['current_city_lng'] = currentCityLng;
      updates['job_title'] = jobTitle;
      updates['job_company'] = jobCompany;
      updates['relationship_status'] = relationshipStatus;
      updates['relationship_partner'] = relationshipPartner;
      updates['religion'] = religion;
      updates['languages'] = languages;
      updates['website'] = website;
      updates['school'] = school;
      updates['favorite_sports'] = favoriteSports;
      updates['favorite_teams'] = favoriteTeams;
      updates['favorite_games'] = favoriteGames;
      updates['phone'] = phone;
      updates['contact_visibility'] = contactVisibility ?? 'friends';

      await _supabase.from('profiles').upsert(updates);

      if (fullName != null) {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }

      return ProfileResult.success('Profil actualizat cu succes!');
    } catch (e) {
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

      await _supabase.storage.from('avatars').upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      final urlWithTimestamp = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('profiles')
          .update({'avatar_url': urlWithTimestamp, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      return ProfileResult.success(urlWithTimestamp);
    } catch (e) {
      return ProfileResult.error('Eroare la upload: $e');
    }
  }

  /// Uploadează cover photo și returnează URL-ul
  Future<ProfileResult> uploadCover(String filePath) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      final file = File(filePath);
      final fileExt = filePath.split('.').last.toLowerCase();
      final fileName = '$userId/cover.$fileExt';

      await _supabase.storage.from('covers').upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _supabase.storage.from('covers').getPublicUrl(fileName);
      final urlWithTimestamp = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('profiles')
          .update({'cover_url': urlWithTimestamp, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      return ProfileResult.success(urlWithTimestamp);
    } catch (e) {
      return ProfileResult.error('Eroare la upload cover: $e');
    }
  }

  /// Șterge avatarul curent
  Future<ProfileResult> deleteAvatar() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      final files = await _supabase.storage.from('avatars').list(path: userId);
      if (files.isNotEmpty) {
        final paths = files.map((f) => '$userId/${f.name}').toList();
        await _supabase.storage.from('avatars').remove(paths);
      }

      await _supabase
          .from('profiles')
          .update({'avatar_url': null, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      return ProfileResult.success('Avatar șters cu succes!');
    } catch (e) {
      return ProfileResult.error('Eroare la ștergere: $e');
    }
  }

  /// Șterge cover photo
  Future<ProfileResult> deleteCover() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ProfileResult.error('Utilizatorul nu este autentificat.');
      }

      final files = await _supabase.storage.from('covers').list(path: userId);
      if (files.isNotEmpty) {
        final paths = files.map((f) => '$userId/${f.name}').toList();
        await _supabase.storage.from('covers').remove(paths);
      }

      await _supabase
          .from('profiles')
          .update({'cover_url': null, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      return ProfileResult.success('Cover șters cu succes!');
    } catch (e) {
      return ProfileResult.error('Eroare la ștergere cover: $e');
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