import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../services/friendship_service.dart';
import '../../l10n/app_localizations.dart';

/// Shows the notifications bubble overlay with jelly animation
void showNotificationsBubble(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return NotificationsBubbleOverlay(animation: animation);
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    ),
  );
}

class NotificationsBubbleOverlay extends ConsumerStatefulWidget {
  final Animation<double> animation;

  const NotificationsBubbleOverlay({super.key, required this.animation});

  @override
  ConsumerState<NotificationsBubbleOverlay> createState() =>
      _NotificationsBubbleOverlayState();
}

class _NotificationsBubbleOverlayState
    extends ConsumerState<NotificationsBubbleOverlay>
    with TickerProviderStateMixin {
  final FriendshipService _friendshipService = FriendshipService();

  late AnimationController _jellyController;
  late AnimationController _staggerController;
  late Animation<double> _jellyX;
  late Animation<double> _jellyY;

  final Set<String> _deletedIds = {};
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ro', timeago.RoMessages());

    // Jelly wobble
    _jellyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _jellyX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 0.98), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.01), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.01, end: 0.995), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.995, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _jellyController,
      curve: Curves.easeOut,
    ));

    _jellyY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.02), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 0.99), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.99, end: 1.005), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.005, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _jellyController,
      curve: Curves.easeOut,
    ));

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    widget.animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _jellyController.forward();
        _staggerController.forward();
      }
    });

    if (widget.animation.isCompleted) {
      _jellyController.forward();
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _jellyController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _acceptFriendRequest(NotificationModel notification) async {
    final friendshipId = notification.data['friendship_id'] as String?;
    if (friendshipId == null) return;

    setState(() => _processingIds.add(notification.id));

    final success = await _friendshipService.acceptFriendRequest(friendshipId);

    if (!mounted) return;

    if (success) {
      await ref
          .read(notificationServiceProvider)
          .deleteNotification(notification.id);
      setState(() {
        _deletedIds.add(notification.id);
        _processingIds.remove(notification.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${context.tr('friend_request_accepted_from')} ${notification.data['sender_name'] ?? 'user'}'),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      setState(() => _processingIds.remove(notification.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('failed_accept_friend_request')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _declineFriendRequest(NotificationModel notification) async {
    final friendshipId = notification.data['friendship_id'] as String?;
    if (friendshipId == null) return;

    setState(() => _processingIds.add(notification.id));

    final success =
        await _friendshipService.declineFriendRequest(friendshipId);

    if (!mounted) return;

    if (success) {
      await ref
          .read(notificationServiceProvider)
          .deleteNotification(notification.id);
      setState(() {
        _deletedIds.add(notification.id);
        _processingIds.remove(notification.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${context.tr('friend_request_declined_from')} ${notification.data['sender_name'] ?? 'user'}'),
        ));
      }
    } else {
      setState(() => _processingIds.remove(notification.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('failed_decline_friend_request')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await ref
        .read(notificationServiceProvider)
        .markAllAsRead(category: 'chat');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('all_notifications_read'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final notificationsAsync = ref.watch(chatNotificationsProvider);

    final bubbleWidth = screenWidth * 0.88;
    final bubbleMaxHeight = screenHeight * 0.6;
    final bubbleRight = 8.0;
    final bubbleTop = topPadding + 56.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) => Container(
                color: Colors.black
                    .withValues(alpha: 0.35 * widget.animation.value),
              ),
            ),
          ),

          // Bubble
          Positioned(
            right: bubbleRight,
            top: bubbleTop,
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([widget.animation, _jellyController]),
              builder: (context, child) {
                final curved = CurvedAnimation(
                  parent: widget.animation,
                  curve: Curves.easeOutBack,
                );

                final scaleX = curved.value *
                    (_jellyController.isAnimating ? _jellyX.value : 1.0);
                final scaleY = curved.value *
                    (_jellyController.isAnimating ? _jellyY.value : 1.0);

                return Transform(
                  alignment: Alignment.topRight,
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                  child: Opacity(
                    opacity: widget.animation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: bubbleWidth,
                constraints: BoxConstraints(maxHeight: bubbleMaxHeight),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(colorScheme),
                      Flexible(
                        child: notificationsAsync.when(
                          data: (notifications) {
                            final filtered = notifications
                                .where(
                                    (n) => !_deletedIds.contains(n.id))
                                .toList();
                            if (filtered.isEmpty) {
                              return _buildEmptyState(colorScheme);
                            }
                            return _buildNotificationsList(
                                filtered, colorScheme);
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.all(30),
                            child: Center(
                              child: Text('Error: $e',
                                  style: TextStyle(
                                      color: colorScheme.error,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Arrow pointer top-right
          Positioned(
            right: bubbleRight + 28,
            top: bubbleTop - 7,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) => Opacity(
                opacity: widget.animation.value.clamp(0.0, 1.0),
                child: child,
              ),
              child: CustomPaint(
                size: const Size(16, 8),
                painter: _BubbleArrowUpPainter(color: colorScheme.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final count = ref.watch(chatNotificationCountProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Animated bell icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Transform.rotate(
                angle: (1 - value) * 0.3,
                child: child,
              ),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber[700]!,
                    Colors.amber[500]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count > 0 ? '$count unread' : 'All caught up!',
                  style: TextStyle(
                    fontSize: 12,
                    color: count > 0
                        ? Colors.amber[700]
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight:
                        count > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // Mark all read
          if (ref.watch(chatNotificationCountProvider) > 0)
            IconButton(
              onPressed: _markAllAsRead,
              icon: Icon(Icons.done_all_rounded,
                  color: colorScheme.primary, size: 20),
              tooltip: context.tr('mark_all_read'),
              style: IconButton.styleFrom(
                backgroundColor:
                    colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          const SizedBox(width: 4),
          // Close
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                size: 22),
            style: IconButton.styleFrom(
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
            child: Icon(Icons.notifications_off_outlined,
                size: 50,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 12),
          Text('No notifications',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text("You're all caught up!",
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
      List<NotificationModel> notifications, ColorScheme colorScheme) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final delay = (index * 0.1).clamp(0.0, 0.5);
        final end = (delay + 0.5).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final progress =
                Interval(delay, end, curve: Curves.easeOutCubic)
                    .transform(_staggerController.value);
            return Transform.translate(
              offset: Offset(0, 20 * (1 - progress)),
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: _buildNotificationTile(notifications[index], colorScheme),
        );
      },
    );
  }

  Widget _buildNotificationTile(
      NotificationModel notification, ColorScheme colorScheme) {
    final isFriendRequest = notification.type == 'friend_request';
    final isProcessing = _processingIds.contains(notification.id);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: notification.read
              ? Colors.transparent
              : colorScheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: notification.read
              ? null
              : Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isFriendRequest
                        ? Colors.green.withValues(alpha: 0.15)
                        : colorScheme.primaryContainer,
                    child: Icon(
                      isFriendRequest
                          ? Icons.person_add_rounded
                          : Icons.notifications_rounded,
                      color: isFriendRequest
                          ? Colors.green[700]
                          : colorScheme.primary,
                      size: 20,
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
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(notification.createdAt,
                              locale: 'ro'),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unread dot
                  if (!notification.read && !isFriendRequest)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),

              // Friend request actions
              if (isFriendRequest) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: FilledButton(
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _acceptFriendRequest(notification),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_rounded, size: 14),
                                    const SizedBox(width: 4),
                                    Text(context.tr('accept')),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _declineFriendRequest(notification),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            side: BorderSide(
                                color: colorScheme.error
                                    .withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text(context.tr('decline')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Triangle arrow pointing upward
class _BubbleArrowUpPainter extends CustomPainter {
  final Color color;
  _BubbleArrowUpPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}