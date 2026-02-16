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

/// SPORTS
final sportsNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.loadNotifications(category: 'sports');

  await for (final _ in service.refreshStream) {
    yield await service.loadNotifications(category: 'sports');
  }
});

/// LEARN
final learnNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.loadNotifications(category: 'learn');

  await for (final _ in service.refreshStream) {
    yield await service.loadNotifications(category: 'learn');
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

/// Unread count SPORTS
final sportsUnreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.getUnreadCount(category: 'sports');

  await for (final _ in service.refreshStream) {
    yield await service.getUnreadCount(category: 'sports');
  }
});

/// Unread count LEARN
final learnUnreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.getUnreadCount(category: 'learn');

  await for (final _ in service.refreshStream) {
    yield await service.getUnreadCount(category: 'learn');
  }
});

/// ✅ NOU: Provider pentru mesaje necitite (pentru badge pe Chat tab)
/// Ascultă la schimbări în timp real în tabela messages
final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) {
    yield 0;
    return;
  }

  // Încarcă numărul inițial de mesaje necitite
  final initialCount = await _getUnreadMessagesCount(supabase, userId);
  yield initialCount;

  // ✅ REALTIME: La orice schimbare în messages → reîncarcă count-ul
  // Stream-ul nu suportă .neq(), deci ascultăm la toate schimbările
  // și reîncărcăm count-ul folosind query normal (care suportă .neq)
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
        .neq('sender_id', userId); // ✅ Query-urile normale suportă .neq()
    
    return (response as List).length;
  } catch (e) {
    debugPrint('❌ Error getting unread messages: $e');
    return 0;
  }
}

/// Badge pentru clopotel (doar friend requests)
final hasChatUnreadNotificationsProvider = Provider<bool>((ref) {
  final count = ref.watch(chatUnreadCountProvider);
  return count.when(
    data: (c) => c > 0,
    loading: () => false,
    error: (_, _) => false,
  );
});

final hasSportsUnreadNotificationsProvider = Provider<bool>((ref) {
  final count = ref.watch(sportsUnreadCountProvider);
  return count.when(
    data: (c) => c > 0,
    loading: () => false,
    error: (_, _) => false,
  );
});

final hasLearnUnreadNotificationsProvider = Provider<bool>((ref) {
  final count = ref.watch(learnUnreadCountProvider);
  return count.when(
    data: (c) => c > 0,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// ✅ NOU: Badge combinat pentru Chat tab (friend requests + mesaje necitite)
/// Folosit în bottom navigation pentru iconița Chat
final hasChatBadgeProvider = Provider<bool>((ref) {
  final hasNotifications = ref.watch(hasChatUnreadNotificationsProvider);
  final unreadMessages = ref.watch(unreadMessagesCountProvider);
  
  final hasMessages = unreadMessages.when(
    data: (count) => count > 0,
    loading: () => false,
    error: (_, _) => false,
  );
  
  // 🔴 Badge roșu dacă ai friend requests SAU mesaje necitite
  return hasNotifications || hasMessages;
});

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final chat = ref.watch(hasChatUnreadNotificationsProvider);
  final sports = ref.watch(hasSportsUnreadNotificationsProvider);
  final learn = ref.watch(hasLearnUnreadNotificationsProvider);
  return chat || sports || learn;
});