import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/swirl_model.dart';

/// Service pentru gestionarea Swirls (video-uri scurte TikTok-style)
/// Validare: 10 secunde - 10 minute
class SwirlsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate Swirls-urile publicate
  /// Sortate după data creării (cele mai recente primul) - pentru scroll vertical
  Future<List<Swirl>> getSwirls() async {
    try {
      final response = await _supabase
          .from('swirls') // Renamed from 'videos' table
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final List<Swirl> swirls = (response as List)
          .map((json) => Swirl.fromJson(json as Map<String, dynamic>))
          .where((swirl) => swirl.isValidDuration) // Validare: 10-600 secunde
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
          .map((json) => Swirl.fromJson(json as Map<String, dynamic>))
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

      final swirl = Swirl.fromJson(response as Map<String, dynamic>);
      
      if (!swirl.isValidDuration) {
        throw Exception('Invalid swirl duration: ${swirl.durationSeconds} seconds');
      }

      return swirl;
    } catch (e) {
      throw Exception('Failed to load swirl: $e');
    }
  }

  /// Crește numărul de vizualizări pentru un Swirl
  Future<void> incrementViews(String swirlId) async {
    try {
      await _supabase.rpc('increment_swirl_views', params: {'swirl_id': swirlId});
    } catch (e) {
      // Ignore errors for view counting
      print('Failed to increment views: $e');
    }
  }

  /// Crește numărul de like-uri pentru un Swirl
  Future<void> incrementLikes(String swirlId) async {
    try {
      await _supabase.rpc('increment_swirl_likes', params: {'swirl_id': swirlId});
    } catch (e) {
      throw Exception('Failed to increment likes: $e');
    }
  }

  /// Validează durata unui Swirl înainte de upload
  /// Returns true dacă durata este validă (10-600 secunde)
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
}
