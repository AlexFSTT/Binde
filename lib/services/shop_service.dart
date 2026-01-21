import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

/// Serviciu pentru gestionarea produselor
class ShopService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate produsele disponibile
  Future<List<Product>> getProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea produselor: $e');
    }
  }

  /// Obține produsele dintr-o categorie
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea produselor: $e');
    }
  }

  /// Obține un produs după ID
  Future<Product?> getProductById(String id) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', id)
          .single();

      return Product.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Obține categoriile unice
  Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('products')
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