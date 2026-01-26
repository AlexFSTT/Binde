import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service pentru gestionarea prezenței utilizatorilor
/// Gestionează: Online/Offline status, Last seen, Typing indicator
class PresenceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _presenceChannel;

  /// Actualizează status-ul utilizatorului ca ONLINE
  Future<void> setOnline() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('🟢 Setting user as ONLINE: $userId');

      await _supabase.from('profiles').update({
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ User status updated to ONLINE');
    } catch (e) {
      debugPrint('❌ Error setting online status: $e');
    }
  }

  /// Actualizează status-ul utilizatorului ca OFFLINE
  Future<void> setOffline() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('🔴 Setting user as OFFLINE: $userId');

      await _supabase.from('profiles').update({
        'is_online': false,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ User status updated to OFFLINE');
    } catch (e) {
      debugPrint('❌ Error setting offline status: $e');
    }
  }

  /// Trimite indicator că utilizatorul scrie
  Future<void> sendTypingIndicator(String conversationId, bool isTyping) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Folosim Supabase Broadcast pentru a trimite în timp real
      if (_presenceChannel != null) {
        await _presenceChannel!.sendBroadcastMessage(
          event: 'typing',
          payload: {
            'user_id': userId,
            'conversation_id': conversationId,
            'is_typing': isTyping,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending typing indicator: $e');
    }
  }

  /// Subscribe la indicator-ul de typing pentru o conversație
  /// Returnează un callback care va fi apelat când cineva scrie
  void subscribeToTyping(
    String conversationId,
    Function(Map<String, dynamic>) onTyping,
  ) {
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;

    _presenceChannel = _supabase.channel('presence:$conversationId');

    _presenceChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        onTyping(payload);
      },
    ).subscribe();
  }

  /// Obține status-ul unui utilizator (online/offline și last seen)
  Future<Map<String, dynamic>> getUserStatus(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('is_online, last_seen')
          .eq('id', userId)
          .single();

      final isOnline = response['is_online'] as bool? ?? false;
      final lastSeenStr = response['last_seen'] as String?;
      final lastSeen = lastSeenStr != null ? DateTime.parse(lastSeenStr) : null;

      debugPrint('📊 User status for $userId: Online=$isOnline, Last seen=$lastSeen');

      return {
        'is_online': isOnline,
        'last_seen': lastSeen,
      };
    } catch (e) {
      debugPrint('Error getting user status: $e');
      return {
        'is_online': false,
        'last_seen': null,
      };
    }
  }

  /// Formatează timpul pentru "Last seen" - WHATSAPP STYLE
  /// 
  /// Reguli (exact ca WhatsApp):
  /// - Online → "Online" (verde)
  /// - Astăzi (< 24h, aceeași zi) → "Last seen today at 14:30"
  /// - Ieri (trecut de miezul nopții) → "Last seen yesterday at 22:15"
  /// - Alte zile (> 24h) → "Last seen 23/01/2025 at 18:45"
  /// 
  /// NU mai folosim "just now", "5m ago", "2h ago" - DOAR ora exactă!
  String formatLastSeen(DateTime? lastSeen, bool isOnline) {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    
    // Creăm DateTime-uri fără componenta de timp pentru comparații de zile
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final lastSeenDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    
    // Formatăm ora în format HH:MM
    final hour = lastSeen.hour.toString().padLeft(2, '0');
    final minute = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    
    // Verificăm dacă e astăzi
    if (lastSeenDate.isAtSameMomentAs(today)) {
      return 'Last seen today at $timeStr';
    }
    
    // Verificăm dacă e ieri
    if (lastSeenDate.isAtSameMomentAs(yesterday)) {
      return 'Last seen yesterday at $timeStr';
    }
    
    // Pentru alte zile - afișăm data completă + ora
    final day = lastSeen.day.toString().padLeft(2, '0');
    final month = lastSeen.month.toString().padLeft(2, '0');
    final year = lastSeen.year;
    
    return 'Last seen $day/$month/$year at $timeStr';
  }

  /// Cleanup când se închide aplicația
  void dispose() {
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
  }
}