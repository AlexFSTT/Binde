import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lesson_model.dart';

/// Serviciu pentru gestionarea lecțiilor
class LearnService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate lecțiile publicate, ordonate
  Future<List<Lesson>> getLessons() async {
    try {
      final response = await _supabase
          .from('lessons')
          .select()
          .eq('is_published', true)
          .order('order_index', ascending: true);

      // Convertește lista de JSON în listă de obiecte Lesson
      return (response as List)
          .map((json) => Lesson.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea lecțiilor: $e');
    }
  }

  /// Obține lecțiile dintr-o anumită categorie
  Future<List<Lesson>> getLessonsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select()
          .eq('is_published', true)
          .eq('category', category)
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => Lesson.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea lecțiilor: $e');
    }
  }

  /// Obține o lecție după ID
  Future<Lesson?> getLessonById(String id) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select()
          .eq('id', id)
          .single();

      return Lesson.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Obține toate categoriile unice
  Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('category')
          .eq('is_published', true);

      // Extrage categoriile unice
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
}