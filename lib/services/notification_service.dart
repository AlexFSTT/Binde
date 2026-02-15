import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import '../models/notification_model.dart';
import '../firebase_options.dart';

/// Handler pentru notificări în background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('📨 Background notification: ${message.messageId}');
}

/// Service pentru gestionarea notificărilor cu separare pe categorii
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  late final SupabaseClient _supabase = Supabase.instance.client;

  // Stream pentru notificări noi
  late final StreamController<NotificationModel> _notificationStreamController =
      StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get notificationStream =>
      _notificationStreamController.stream;

  bool _initialized = false;

  /// Inițializare service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Inițializare Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Request permission
      await _requestPermission();

      // 3. Configurare local notifications cu canale separate
      await _configureLocalNotifications();

      // 4. Configurare FCM
      await _configureFCM();

      // 5. Salvare FCM token
      await _saveFCMToken();

      // 6. Subscribe la notificări
      await _subscribeToNotifications();

      _initialized = true;
      debugPrint('✅ Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Request permission
  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');
    } else {
      debugPrint('⚠️ Notification permission denied');
    }
  }

  /// Configurare local notifications cu canale separate
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

    // ✅ flutter_local_notifications v20+ cere parametru named `settings:`
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // ✅ Canale separate pentru categorii
    await _createNotificationChannels();
  }

  /// Creează canale separate pentru fiecare categorie
  Future<void> _createNotificationChannels() async {
    // Canal pentru Chat (friend requests)
    const chatChannel = AndroidNotificationChannel(
      'chat_notifications',
      'Friend Requests',
      description: 'Notifications for friend requests',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Canal pentru Sports
    const sportsChannel = AndroidNotificationChannel(
      'sports_notifications',
      'Sports Updates',
      description: 'Notifications for sports news and live events',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Canal pentru Learn
    const learnChannel = AndroidNotificationChannel(
      'learn_notifications',
      'Learning Updates',
      description: 'Notifications for new lessons and updates',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: false,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sportsChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(learnChannel);
  }

  /// Configurare FCM
  Future<void> _configureFCM() async {
    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground notification: ${message.notification?.title}');
      _showLocalNotification(message);
      _playSound();
      _vibrate();
    });

    // Background tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification tapped (background): ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Terminated tap
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          '📱 Notification tapped (terminated): ${initialMessage.data}');
      _handleNotificationTap(initialMessage.data);
    }
  }

  /// Salvare FCM token
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

      debugPrint('✅ FCM token saved: ${token.substring(0, 20)}...');

      _fcm.onTokenRefresh.listen((newToken) {
        _saveFCMToken();
      });
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Subscribe la notificări Supabase
  Future<void> _subscribeToNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          if (data.isEmpty) return;

          final notification = NotificationModel.fromJson(data.last);
          _notificationStreamController.add(notification);
          _showInAppNotification(notification);
        });

    debugPrint('✅ Subscribed to notifications');
  }

  /// Arată notificare in-app
  void _showInAppNotification(NotificationModel notification) {
    _playSound();
    _vibrate();
  }

  /// Arată notificare locală din FCM
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] as String?;
    final category = message.data['category'] as String? ?? 'chat';
    final messageText = message.notification?.body ?? '';

    // Determină canalul bazat pe categorie
    final channelId = _getChannelId(category);
    final channelName = _getChannelName(category);

    // ✅ MESAJE: Notificare expandabilă pentru text lung
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

      await _localNotifications.show(
        id: message.hashCode,
        title: message.notification?.title,
        body: messageText,
        notificationDetails: details,
        payload: jsonEncode(message.data),
      );
      return;
    }

    // ✅ FRIEND REQUESTS: Notificare cu butoane Accept/Decline
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

    // ✅ SPORTS/LEARN: Notificare standard
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications for $category',
      importance: category == 'sports'
          ? Importance.high
          : Importance.defaultImportance,
      priority:
          category == 'sports' ? Priority.high : Priority.defaultPriority,
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

  /// Determină ID canal bazat pe categorie
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

  /// Determină nume canal bazat pe categorie
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

  /// Handler când utilizatorul apasă pe notificare
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final data = jsonDecode(response.payload!);

    // Dacă a apăsat pe buton de acțiune (Accept/Decline)
    if (response.actionId != null) {
      _handleNotificationAction(response.actionId!, data);
      return;
    }

    _handleNotificationTap(data);
  }

  /// Gestionează acțiuni notificare (Accept/Decline friend request)
  Future<void> _handleNotificationAction(
      String actionId, Map<String, dynamic> data) async {
    final friendshipId = data['friendship_id'] as String?;
    if (friendshipId == null) return;

    try {
      if (actionId == 'accept') {
        // Accept friend request
        await _supabase
            .from('friendships')
            .update({
              'status': 'accepted',
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', friendshipId);

        // Șterge notificarea
        final notificationId = data['notification_id'] as String?;
        if (notificationId != null) {
          await deleteNotification(notificationId);
        }

        debugPrint('✅ Friend request accepted: $friendshipId');
      } else if (actionId == 'decline') {
        // Decline friend request
        await _supabase
            .from('friendships')
            .update({
              'status': 'declined',
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', friendshipId);

        // Șterge notificarea
        final notificationId = data['notification_id'] as String?;
        if (notificationId != null) {
          await deleteNotification(notificationId);
        }

        debugPrint('❌ Friend request declined: $friendshipId');
      }
    } catch (e) {
      debugPrint('❌ Error handling friend request action: $e');
    }
  }

  /// Gestionează tap pe notificare (navighează la ecranul corespunzător)
  void _handleNotificationTap(Map<String, dynamic> data) {
    // TODO: Implement navigation based on notification type
    debugPrint('📱 Handle notification tap: $data');
    // Navigation va fi implementat în următorul pas
  }

  /// Play sunet
  Future<void> _playSound() async {
    // Sunetul default se redă automat
  }

  /// Vibrație
  Future<void> _vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      // Ignore
    }
  }

  /// Marchează notificare ca citită
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Marchează toate notificările ca citite (cu filtru categorie opțional)
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
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  /// Șterge notificare
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  /// Încarcă notificări (cu filtru categorie opțional)
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

  /// Numără notificări necitite (cu filtru categorie opțional)
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

  /// Cleanup
  void dispose() {
    _notificationStreamController.close();
  }
}
