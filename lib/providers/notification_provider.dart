import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Stream provider pentru TOATE notificările
final allNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);

  // inițial
  yield await service.loadNotifications();

  // realtime refresh (insert/update/delete)
  await for (final _ in service.refreshStream) {
    yield await service.loadNotifications();
  }
});

/// CHAT
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

/// Unread count CHAT
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

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final chat = ref.watch(hasChatUnreadNotificationsProvider);
  final sports = ref.watch(hasSportsUnreadNotificationsProvider);
  final learn = ref.watch(hasLearnUnreadNotificationsProvider);
  return chat || sports || learn;
});
