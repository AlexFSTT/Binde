import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Provider pentru notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Stream provider pentru TOATE notificările
final allNotificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă datele inițiale
  final initial = await service.loadNotifications();
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.loadNotifications();
    yield updated;
  }
});

/// Stream provider pentru notificări CHAT (friend requests)
final chatNotificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă datele inițiale
  final initial = await service.loadNotifications(category: 'chat');
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.loadNotifications(category: 'chat');
    yield updated;
  }
});

/// Stream provider pentru notificări SPORTS
final sportsNotificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă datele inițiale
  final initial = await service.loadNotifications(category: 'sports');
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.loadNotifications(category: 'sports');
    yield updated;
  }
});

/// Stream provider pentru notificări LEARN
final learnNotificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă datele inițiale
  final initial = await service.loadNotifications(category: 'learn');
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.loadNotifications(category: 'learn');
    yield updated;
  }
});

/// Provider pentru număr notificări necitite CHAT
final chatUnreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă count inițial
  final initial = await service.getUnreadCount(category: 'chat');
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.getUnreadCount(category: 'chat');
    yield updated;
  }
});

/// Provider pentru număr notificări necitite SPORTS
final sportsUnreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă count inițial
  final initial = await service.getUnreadCount(category: 'sports');
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.getUnreadCount(category: 'sports');
    yield updated;
  }
});

/// Provider pentru număr notificări necitite LEARN
final learnUnreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  
  // 1. Încarcă count inițial
  final initial = await service.getUnreadCount(category: 'learn');
  yield initial;
  
  // 2. Ascultă la stream pentru update-uri
  await for (final _ in service.notificationStream) {
    final updated = await service.getUnreadCount(category: 'learn');
    yield updated;
  }
});

/// Provider boolean pentru badge CHAT
final hasChatUnreadNotificationsProvider = Provider<bool>((ref) {
  final count = ref.watch(chatUnreadCountProvider);
  return count.when(
    data: (count) => count > 0,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Provider boolean pentru badge SPORTS
final hasSportsUnreadNotificationsProvider = Provider<bool>((ref) {
  final count = ref.watch(sportsUnreadCountProvider);
  return count.when(
    data: (count) => count > 0,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Provider boolean pentru badge LEARN
final hasLearnUnreadNotificationsProvider = Provider<bool>((ref) {
  final count = ref.watch(learnUnreadCountProvider);
  return count.when(
    data: (count) => count > 0,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Provider boolean pentru badge ORIUNDE (backward compatibility)
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final chatHasUnread = ref.watch(hasChatUnreadNotificationsProvider);
  final sportsHasUnread = ref.watch(hasSportsUnreadNotificationsProvider);
  final learnHasUnread = ref.watch(hasLearnUnreadNotificationsProvider);
  
  return chatHasUnread || sportsHasUnread || learnHasUnread;
});