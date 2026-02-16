import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';

import '../firebase_options.dart';
import '../models/notification_model.dart';

/// Handler pentru notificări în background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('📨 Background notification: ${message.messageId}');
}

/// Service pentru gestionarea notificărilor + badge realtime
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  late final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ stream de refresh (pentru listă + badge)
  final StreamController<void> _refreshController =
      StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;

  RealtimeChannel? _notificationsChannel;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await _requestPermission();
      await _configureLocalNotifications();
      await _configureFCM();
      await _saveFCMToken();
      await _subscribeToNotificationsRealtime();

      _initialized = true;
      debugPrint('✅ Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');
    } else {
      debugPrint('⚠️ Notification permission denied');
    }
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // ✅ v20+ cere named param `settings:`
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    const chatChannel = AndroidNotificationChannel(
      'chat_notifications',
      'Friend Requests',
      description: 'Notifications for friend requests',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const sportsChannel = AndroidNotificationChannel(
      'sports_notifications',
      'Sports Updates',
      description: 'Notifications for sports news and live events',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const learnChannel = AndroidNotificationChannel(
      'learn_notifications',
      'Learning Updates',
      description: 'Notifications for new lessons and updates',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: false,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(chatChannel);
    await androidPlugin?.createNotificationChannel(sportsChannel);
    await androidPlugin?.createNotificationChannel(learnChannel);
  }

  Future<void> _configureFCM() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground notification: ${message.notification?.title}');
      _showLocalNotification(message);
      _playSound();
      _vibrate();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification tapped (background): ${message.data}');
      _handleNotificationTap(message.data);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 Notification tapped (terminated): ${initialMessage.data}');
      _handleNotificationTap(initialMessage.data);
    }
  }

  Future<void> _saveFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_info': {
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
        },
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('✅ FCM token saved/claimed for user: $userId');

      _fcm.onTokenRefresh.listen((_) => _saveFCMToken());
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// ✅ NOU: Șterge FCM token-ul curent din baza de date
  /// Apelat la LOGOUT pentru a opri notificările pe acest device
  /// CRITIC: Fără asta, device-ul primește notificări chiar dacă user-ul s-a delogat!
  Future<void> removeFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('⚠️ No FCM token to remove');
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ No user ID - cannot remove FCM token');
        return;
      }

      // Șterge token-ul din tabela fcm_tokens
      await _supabase
          .from('fcm_tokens')
          .delete()
          .eq('token', token)
          .eq('user_id', userId);

      debugPrint('✅ FCM token removed for user: $userId');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
      // Nu aruncăm eroarea - logout-ul trebuie să continue chiar dacă ștergerea eșuează
    }
  }

  /// ✅ Realtime listener pe notifications: INSERT/UPDATE/DELETE => refresh badge + listă
  Future<void> _subscribeToNotificationsRealtime() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // cleanup dacă există
    if (_notificationsChannel != null) {
      await _notificationsChannel!.unsubscribe();
      _notificationsChannel = null;
    }

    // ✅ aici era eroarea: filter trebuie PostgresChangeFilter, nu String
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );

    _notificationsChannel = _supabase
        .channel('notifications-changes-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: (payload) {
            debugPrint('🔔 Notifications change: ${payload.eventType}');
            _refreshController.add(null);
          },
        )
        .subscribe();

    debugPrint('✅ Realtime subscribed to notifications (all events)');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] as String?;
    final category = message.data['category'] as String? ?? 'chat';
    final messageText = message.notification?.body ?? '';

    final channelId = _getChannelId(category);
    final channelName = _getChannelName(category);

    // ✅ mesaj expandabil
    if (type == 'message' || type == 'chat') {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications for $category',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          messageText,
          contentTitle: message.notification?.title,
          summaryText: 'Mesaj nou',
        ),
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ✅ aici era eroarea: show are named params și cere id:
      await _localNotifications.show(
        id: message.hashCode,
        title: message.notification?.title,
        body: messageText,
        notificationDetails: details,
        payload: jsonEncode(message.data),
      );
      return;
    }

    // ✅ friend request cu butoane
    if (type == 'friend_request') {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications for friend requests',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'accept',
            'Accept',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'decline',
            'Decline',
            showsUserInterface: true,
          ),
        ],
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: message.hashCode,
        title: message.notification?.title,
        body: message.notification?.body,
        notificationDetails: details,
        payload: jsonEncode(message.data),
      );
      return;
    }

    // ✅ notificare standard
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications for $category',
      importance: category == 'sports'
          ? Importance.high
          : Importance.defaultImportance,
      priority: category == 'sports'
          ? Priority.high
          : Priority.defaultPriority,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  String _getChannelId(String category) {
    switch (category) {
      case 'sports':
        return 'sports_notifications';
      case 'learn':
        return 'learn_notifications';
      default:
        return 'chat_notifications';
    }
  }

  String _getChannelName(String category) {
    switch (category) {
      case 'sports':
        return 'Sports Updates';
      case 'learn':
        return 'Learning Updates';
      default:
        return 'Friend Requests';
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final data = jsonDecode(response.payload!);

    if (response.actionId != null) {
      _handleNotificationAction(response.actionId!, data);
      return;
    }

    _handleNotificationTap(data);
  }

  Future<void> _handleNotificationAction(
      String actionId, Map<String, dynamic> data) async {
    final friendshipId = data['friendship_id'] as String?;
    if (friendshipId == null) return;

    try {
      if (actionId == 'accept') {
        await _supabase
            .from('friendships')
            .update({
              'status': 'accepted',
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', friendshipId);

        final notificationId = data['notification_id'] as String?;
        if (notificationId != null) {
          await deleteNotification(notificationId);
        }
      } else if (actionId == 'decline') {
        await _supabase
            .from('friendships')
            .update({
              'status': 'declined',
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', friendshipId);

        final notificationId = data['notification_id'] as String?;
        if (notificationId != null) {
          await deleteNotification(notificationId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling friend request action: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('📱 Handle notification tap: $data');
  }

  Future<void> _playSound() async {}

  Future<void> _vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 200);
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);

      _refreshController.add(null);
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead({String? category}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      var query = _supabase
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

      if (category != null) {
        query = query.eq('category', category);
      }

      await query;
      _refreshController.add(null);
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
      _refreshController.add(null);
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  Future<List<NotificationModel>> loadNotifications(
      {int limit = 50, String? category}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      var query =
          _supabase.from('notifications').select().eq('user_id', userId);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadCount({String? category}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      var query = _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  void dispose() {
    _refreshController.close();
    _notificationsChannel?.unsubscribe();
  }
}