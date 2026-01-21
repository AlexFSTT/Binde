import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sports_news_model.dart';
import '../models/sports_event_model.dart';

/// Serviciu pentru gestionarea secțiunii Sports
class SportsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // ȘTIRI SPORTIVE
  // ============================================

  /// Obține toate știrile
  Future<List<SportsNews>> getAllNews() async {
    try {
      final response = await _supabase
          .from('sports_news')
          .select()
          .eq('is_published', true)
          .order('published_at', ascending: false);

      return (response as List)
          .map((json) => SportsNews.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea știrilor: $e');
    }
  }

  /// Obține știrile pentru un sport specific
  Future<List<SportsNews>> getNewsBySport(String sportType) async {
    try {
      final response = await _supabase
          .from('sports_news')
          .select()
          .eq('is_published', true)
          .eq('sport_type', sportType)
          .order('published_at', ascending: false);

      return (response as List)
          .map((json) => SportsNews.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea știrilor: $e');
    }
  }

  /// Obține o știre după ID
  Future<SportsNews?> getNewsById(String id) async {
    try {
      final response = await _supabase
          .from('sports_news')
          .select()
          .eq('id', id)
          .single();

      return SportsNews.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // EVENIMENTE LIVE
  // ============================================

  /// Obține toate evenimentele
  Future<List<SportsEvent>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('sports_events')
          .select()
          .order('start_time', ascending: true);

      return (response as List)
          .map((json) => SportsEvent.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea evenimentelor: $e');
    }
  }

  /// Obține evenimentele live
  Future<List<SportsEvent>> getLiveEvents() async {
    try {
      final response = await _supabase
          .from('sports_events')
          .select()
          .eq('is_live', true)
          .order('start_time', ascending: true);

      return (response as List)
          .map((json) => SportsEvent.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea evenimentelor live: $e');
    }
  }

  /// Obține evenimentele pentru un sport specific
  Future<List<SportsEvent>> getEventsBySport(String sportType) async {
    try {
      final response = await _supabase
          .from('sports_events')
          .select()
          .eq('sport_type', sportType)
          .order('start_time', ascending: true);

      return (response as List)
          .map((json) => SportsEvent.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea evenimentelor: $e');
    }
  }

  /// Obține evenimentele viitoare
  Future<List<SportsEvent>> getUpcomingEvents() async {
    try {
      final response = await _supabase
          .from('sports_events')
          .select()
          .eq('event_status', 'upcoming')
          .order('start_time', ascending: true);

      return (response as List)
          .map((json) => SportsEvent.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Eroare la încărcarea evenimentelor: $e');
    }
  }
}