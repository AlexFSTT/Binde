import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/video_model.dart';

/// Serviciu pentru gestionarea video-urilor
class VideoService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate video-urile publicate
  Future<List<Video>> getVideos() async {
    try {
      final response = await _supabase
          .from('videos')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Video.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea video-urilor: $e');
    }
  }

  /// Obține video-urile dintr-o categorie
  Future<List<Video>> getVideosByCategory(String category) async {
    try {
      final response = await _supabase
          .from('videos')
          .select()
          .eq('is_published', true)
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Video.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea video-urilor: $e');
    }
  }

  /// Obține un video după ID
  Future<Video?> getVideoById(String id) async {
    try {
      final response = await _supabase
          .from('videos')
          .select()
          .eq('id', id)
          .single();

      return Video.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Obține categoriile unice
  Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('videos')
          .select('category')
          .eq('is_published', true);

      final categories = (response as List)
          .map((item) => item['category'] as String?)
          .where((cat) => cat != null && cat.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      return categories;
    } catch (e) {
      return [];
    }
  }

  /// Incrementează vizualizările
  Future<void> incrementViews(String videoId) async {
    try {
      await _supabase.rpc('increment_video_views', params: {'video_id': videoId});
    } catch (e) {
      // Ignoră eroarea - nu e critică
    }
  }
}