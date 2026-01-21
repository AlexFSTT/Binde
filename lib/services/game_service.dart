import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_model.dart';

/// Serviciu pentru gestionarea jocurilor
class GameService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate jocurile disponibile
  Future<List<Game>> getGames() async {
    try {
      final response = await _supabase
          .from('games')
          .select()
          .eq('is_available', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Game.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea jocurilor: $e');
    }
  }

  /// Obține jocurile dintr-o categorie
  Future<List<Game>> getGamesByCategory(String category) async {
    try {
      final response = await _supabase
          .from('games')
          .select()
          .eq('is_available', true)
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Game.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea jocurilor: $e');
    }
  }

  /// Obține categoriile unice
  Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('games')
          .select('category')
          .eq('is_available', true);

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