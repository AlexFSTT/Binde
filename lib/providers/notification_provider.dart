import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Stream provider pentru TOATE notificările
final allNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);

  yield await service.loadNotifications();

  await for (final _ in service.refreshStream) {
    yield await service.loadNotifications();
  }
});

/// CHAT - doar friend requests (pentru clopotel)
final chatNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.loadNotifications(category: 'chat');

  await for (final _ in service.refreshStream) {
    yield await service.loadNotifications(category: 'chat');
  }
});

/// Unread count CHAT (doar friend requests, pentru clopotel)
final chatUnreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.getUnreadCount(category: 'chat');

  await for (final _ in service.refreshStream) {
    yield await service.getUnreadCount(category: 'chat');
  }
});

/// ✅ Provider pentru mesaje necitite (pentru badge pe Chat tab)
final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) {
    yield 0;
    return;
  }

  final initialCount = await _getUnreadMessagesCount(supabase, userId);
  yield initialCount;

  await for (final _ in supabase
      .from('messages')
      .stream(primaryKey: ['id'])) {
    final count = await _getUnreadMessagesCount(supabase, userId);
    yield count;
  }
});

/// Helper pentru a număra mesajele necitite
Future<int> _getUnreadMessagesCount(SupabaseClient supabase, String userId) async {
  try {
    final response = await supabase
        .from('messages')
        .select('id')
        .eq('is_read', false)
        .neq('sender_id', userId);
    
    return (response as List).length;
  } catch (e) {
    debugPrint('❌ Error getting unread messages: $e');
    return 0;
  }
}

// =====================================================
// COUNT PROVIDERS (pentru counter badges)
// =====================================================

/// 🔔 Count pentru clopotel = doar friend requests necitite
final chatNotificationCountProvider = Provider<int>((ref) {
  final count = ref.watch(chatUnreadCountProvider);
  return count.when(
    data: (c) => c,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

/// 💬 Count COMBINAT pentru Chat tab = friend requests + mesaje necitite
final chatBadgeCountProvider = Provider<int>((ref) {
  final notificationCount = ref.watch(chatNotificationCountProvider);
  final unreadMessages = ref.watch(unreadMessagesCountProvider);
  
  final messagesCount = unreadMessages.when(
    data: (count) => count,
    loading: () => 0,
    error: (_, _) => 0,
  );
  
  return notificationCount + messagesCount;
});

// =====================================================
// BOOLEAN PROVIDERS
// =====================================================

/// Badge boolean pentru clopotel (doar friend requests)
final hasChatUnreadNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(chatNotificationCountProvider) > 0;
});

/// Badge combinat boolean pentru Chat tab (friend requests + mesaje necitite)
final hasChatBadgeProvider = Provider<bool>((ref) {
  return ref.watch(chatBadgeCountProvider) > 0;
});

/// Orice notificare necitită
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(hasChatUnreadNotificationsProvider);
});