import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/swirl_model.dart';
import '../models/swirl_comment_model.dart';

/// Service pentru gestionarea Swirls (video-uri scurte TikTok-style)
/// Include: likes, comments, share, upload
class SwirlsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate Swirls-urile publicate
  Future<List<Swirl>> getSwirls() async {
    try {
      final response = await _supabase
          .from('swirls')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final List<Swirl> swirls = (response as List)
          .map((json) => Swirl.fromJson(json))
          .where((swirl) => swirl.isValidDuration)
          .toList();

      return swirls;
    } catch (e) {
      throw Exception('Failed to load swirls: $e');
    }
  }

  /// Obține Swirls-uri după categorie
  Future<List<Swirl>> getSwirlsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('swirls')
          .select()
          .eq('category', category)
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final List<Swirl> swirls = (response as List)
          .map((json) => Swirl.fromJson(json))
          .where((swirl) => swirl.isValidDuration)
          .toList();

      return swirls;
    } catch (e) {
      throw Exception('Failed to load swirls by category: $e');
    }
  }

  /// Obține un singur Swirl după ID
  Future<Swirl> getSwirlById(String id) async {
    try {
      final response = await _supabase
          .from('swirls')
          .select()
          .eq('id', id)
          .single();

      final swirl = Swirl.fromJson(response);
      
      if (!swirl.isValidDuration) {
        throw Exception('Invalid swirl duration: ${swirl.durationSeconds} seconds');
      }

      return swirl;
    } catch (e) {
      throw Exception('Failed to load swirl: $e');
    }
  }

  // ============================================================================
  // VIEWS
  // ============================================================================

  /// Crește numărul de vizualizări pentru un Swirl
  Future<void> incrementViews(String swirlId) async {
    try {
      await _supabase.rpc('increment_swirl_views', params: {'swirl_id': swirlId});
    } catch (e) {
      debugPrint('Failed to increment views: $e');
    }
  }

  // ============================================================================
  // LIKES SYSTEM
  // ============================================================================

  /// Verifică dacă user-ul curent a dat like unui Swirl
  Future<bool> hasUserLikedSwirl(String swirlId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('swirl_likes')
          .select('id')
          .eq('swirl_id', swirlId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking like status: $e');
      return false;
    }
  }

  /// Toggle like pentru un Swirl (like/unlike)
  Future<bool> toggleLike(String swirlId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to like');
      }

      // Verifică dacă există deja like
      final existingLike = await _supabase
          .from('swirl_likes')
          .select('id')
          .eq('swirl_id', swirlId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike - șterge like-ul
        await _supabase
            .from('swirl_likes')
            .delete()
            .eq('swirl_id', swirlId)
            .eq('user_id', userId);

        // Decrementează counter
        await _supabase.rpc('decrement_swirl_likes', params: {'swirl_id': swirlId});
        
        return false; // Nu mai e liked
      } else {
        // Like - adaugă like
        await _supabase.from('swirl_likes').insert({
          'swirl_id': swirlId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Incrementează counter
        await _supabase.rpc('increment_swirl_likes', params: {'swirl_id': swirlId});
        
        return true; // E liked acum
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  // ============================================================================
  // COMMENTS SYSTEM
  // ============================================================================

  /// Obține comments pentru un Swirl
  Future<List<SwirlComment>> getComments(String swirlId) async {
    try {
      final response = await _supabase
          .from('swirl_comments')
          .select()
          .eq('swirl_id', swirlId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SwirlComment.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  /// Adaugă un comment la un Swirl
  Future<SwirlComment> addComment(String swirlId, String text) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to comment');
      }

      // Obține username-ul user-ului curent
      final userResponse = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .single();

      final username = userResponse['username'] as String? ?? 'Unknown';
      final avatarUrl = userResponse['avatar_url'] as String?;

      // Adaugă comment-ul
      final response = await _supabase.from('swirl_comments').insert({
        'swirl_id': swirlId,
        'user_id': userId,
        'username': username,
        'user_avatar': avatarUrl,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return SwirlComment.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Șterge un comment (doar owner-ul poate șterge)
  Future<void> deleteComment(String commentId, String userId) async {
    try {
      await _supabase
          .from('swirl_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  // ============================================================================
  // VIDEO UPLOAD
  // ============================================================================

  /// Upload video la Supabase Storage
  Future<String> uploadVideo(String filePath, String fileName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to upload');
      }

      // Upload la Supabase Storage în folder-ul user-ului
      final path = '$userId/$fileName';
      final file = File(filePath);
      await _supabase.storage.from('swirls').upload(path, file);

      // Obține URL-ul public
      final publicUrl = _supabase.storage.from('swirls').getPublicUrl(path);
      
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Creează un Swirl nou în database
  Future<Swirl> createSwirl({
    required String title,
    required String videoUrl,
    required int durationSeconds,
    String? description,
    String? category,
    String? thumbnailUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to create swirl');
      }

      // Validare durată
      if (!validateDuration(durationSeconds)) {
        throw Exception(getDurationErrorMessage(durationSeconds));
      }

      // Obține username-ul user-ului
      final userResponse = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .single();

      final username = userResponse['username'] as String? ?? 'Unknown';
      final avatarUrl = userResponse['avatar_url'] as String?;

      // Creează Swirl-ul
      final response = await _supabase.from('swirls').insert({
        'title': title,
        'description': description,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'category': category,
        'duration_seconds': durationSeconds,
        'user_id': userId,
        'username': username,
        'user_avatar': avatarUrl,
        'is_published': true,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return Swirl.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create swirl: $e');
    }
  }

  /// Validează durata unui Swirl
  bool validateDuration(int durationSeconds) {
    return durationSeconds >= 10 && durationSeconds <= 600;
  }

  /// Returnează mesaj de eroare pentru durată invalidă
  String getDurationErrorMessage(int durationSeconds) {
    if (durationSeconds < 10) {
      return 'Swirl too short! Minimum duration is 10 seconds.';
    } else if (durationSeconds > 600) {
      return 'Swirl too long! Maximum duration is 10 minutes.';
    }
    return 'Invalid duration';
  }

  // ============================================================================
  // SHARE
  // ============================================================================

  /// Generează link pentru share
  String generateShareLink(String swirlId) {
    // TODO: Înlocuiește cu domeniul tău real
    return 'https://binde.app/swirls/$swirlId';
  }
}