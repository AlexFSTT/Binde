import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/update_model.dart';

/// Service pentru gestionarea Update-urilor despre aplicație
/// Doar adminii pot posta update-uri
class UpdatesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate update-urile publicate
  Future<List<AppUpdate>> getUpdates() async {
    try {
      final response = await _supabase
          .from('updates')
          .select('''
            *,
            profiles:author_id (
              full_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AppUpdate.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load updates: $e');
    }
  }

  /// Obține un singur update după ID
  Future<AppUpdate> getUpdateById(String id) async {
    try {
      final response = await _supabase
          .from('updates')
          .select('''
            *,
            profiles:author_id (
              full_name,
              avatar_url
            )
          ''')
          .eq('id', id)
          .single();

      return AppUpdate.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load update: $e');
    }
  }

  /// Verifică dacă user-ul curent este admin
  Future<bool> isAdmin() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', userId)
          .single();

      return response['is_admin'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Creează un update nou (doar pentru admini)
  Future<void> createUpdate({
    required String title,
    required String content,
    String? imageUrl,
    bool isPublished = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Verifică dacă user-ul este admin
      final isUserAdmin = await isAdmin();
      if (!isUserAdmin) {
        throw Exception('Only admins can create updates');
      }

      await _supabase.from('updates').insert({
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'author_id': userId,
        'is_published': isPublished,
      });
    } catch (e) {
      throw Exception('Failed to create update: $e');
    }
  }

  /// Actualizează un update existent (doar pentru admini)
  Future<void> updateUpdate({
    required String updateId,
    String? title,
    String? content,
    String? imageUrl,
    bool? isPublished,
  }) async {
    try {
      final isUserAdmin = await isAdmin();
      if (!isUserAdmin) {
        throw Exception('Only admins can update updates');
      }

      final Map<String, dynamic> data = {};
      if (title != null) data['title'] = title;
      if (content != null) data['content'] = content;
      if (imageUrl != null) data['image_url'] = imageUrl;
      if (isPublished != null) data['is_published'] = isPublished;

      data['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('updates').update(data).eq('id', updateId);
    } catch (e) {
      throw Exception('Failed to update: $e');
    }
  }

  /// Șterge un update (doar pentru admini)
  Future<void> deleteUpdate(String updateId) async {
    try {
      final isUserAdmin = await isAdmin();
      if (!isUserAdmin) {
        throw Exception('Only admins can delete updates');
      }

      await _supabase.from('updates').delete().eq('id', updateId);
    } catch (e) {
      throw Exception('Failed to delete update: $e');
    }
  }
}
