import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../services/friendship_service.dart';
import '../../l10n/app_localizations.dart';

/// Ecran pentru afișarea notificărilor filtrate pe categorie
class NotificationsScreen extends ConsumerStatefulWidget {
  final String? category; // 'chat' sau null pentru toate

  const NotificationsScreen({
    super.key,
    this.category,
  });

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  
  // ✅ Set pentru tracking notificări șterse local
  final Set<String> _deletedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ro', timeago.RoMessages());
  }

  Future<void> _markAllAsRead() async {
    await ref.read(notificationServiceProvider).markAllAsRead(category: widget.category);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('all_notifications_read'))),
      );
    }
  }

  Future<void> _refreshNotifications() async {
    // Clear deleted IDs și refresh
    setState(() {
      _deletedNotificationIds.clear();
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _getCategoryTitle() {
    switch (widget.category) {
      case 'chat':
        return 'Friend Requests';
      default:
        return 'Notifications';
    }
  }

  IconData _getCategoryIcon(String type) {
    if (type.startsWith('friend')) return Icons.person_add;
    return Icons.notifications;
  }

  Color _getCategoryColor(String type, ColorScheme colorScheme) {
    if (type.startsWith('friend')) return Colors.green;
    return colorScheme.primary;
  }

  Future<void> _acceptFriendRequest(NotificationModel notification) async {
    final friendshipId = notification.data['friendship_id'] as String?;
    if (friendshipId == null) return;

    final success = await _friendshipService.acceptFriendRequest(friendshipId);
    
    if (!mounted) return;

    if (success) {
      // Șterge din database
      await ref.read(notificationServiceProvider).deleteNotification(notification.id);
      
      // ✅ Marchează ca ștearsă local
      setState(() {
        _deletedNotificationIds.add(notification.id);
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('friend_request_accepted_from')} ${notification.data['sender_name'] ?? 'user'}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_accept_friend_request')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineFriendRequest(NotificationModel notification) async {
    final friendshipId = notification.data['friendship_id'] as String?;
    if (friendshipId == null) return;

    final success = await _friendshipService.declineFriendRequest(friendshipId);
    
    if (!mounted) return;

    if (success) {
      // Șterge din database
      await ref.read(notificationServiceProvider).deleteNotification(notification.id);
      
      // ✅ Marchează ca ștearsă local
      setState(() {
        _deletedNotificationIds.add(notification.id);
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('friend_request_declined_from')} ${notification.data['sender_name'] ?? 'user'}'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_decline_friend_request')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Selectează provider-ul corect bazat pe categorie
    final AsyncValue<List<NotificationModel>> notificationsAsync;
    
    switch (widget.category) {
      case 'chat':
        notificationsAsync = ref.watch(chatNotificationsProvider);
        break;
      default:
        notificationsAsync = ref.watch(allNotificationsProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getCategoryTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: context.tr('mark_all_read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          // ✅ Filtrează notificările șterse local
          final filteredNotifications = notifications
              .where((n) => !_deletedNotificationIds.contains(n.id))
              .toList();
          
          if (filteredNotifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredNotifications.length,
              itemBuilder: (context, index) {
                final notification = filteredNotifications[index];
                return _buildNotificationItem(notification, colorScheme);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, ColorScheme colorScheme) {
    final isFriendRequest = notification.type == 'friend_request';
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onError,
          size: 28,
        ),
      ),
      onDismissed: (direction) async {
        // Șterge din database
        await ref.read(notificationServiceProvider).deleteNotification(notification.id);
        
        // ✅ Marchează ca ștearsă local
        setState(() {
          _deletedNotificationIds.add(notification.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${notification.title} ${context.tr('deleted')}'),
            ),
          );
        }
      },
      child: Card(
        elevation: notification.read ? 0 : 2,
        color: notification.read
            ? null
            : colorScheme.primaryContainer.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar sau Icon
              if (isFriendRequest && notification.data['sender_id'] != null)
                _buildAvatar(notification, colorScheme)
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(notification.type, colorScheme)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(notification.type),
                    color: _getCategoryColor(notification.type, colorScheme),
                    size: 24,
                  ),
                ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.read
                            ? FontWeight.normal
                            : FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    Text(
                      timeago.format(notification.createdAt, locale: 'ro'),
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    
                    if (isFriendRequest) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptFriendRequest(notification),
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(context.tr('accept')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _declineFriendRequest(notification),
                              icon: const Icon(Icons.close, size: 18),
                              label: Text(context.tr('decline')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(color: colorScheme.error),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              if (!notification.read && !isFriendRequest)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(NotificationModel notification, ColorScheme colorScheme) {
    final senderName = notification.data['sender_name'] as String?;
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        (senderName ?? '?')[0].toUpperCase(),
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}