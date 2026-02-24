import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friendship_model.dart';
import '../../services/friendship_service.dart';
import '../../services/chat_service.dart';
import '../../screens/chat/chat_detail_screen.dart';
import '../../l10n/app_localizations.dart';

/// Shows the friends bubble overlay with animation
void showFriendsBubble(BuildContext context, {required VoidCallback onChatOpened}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FriendsBubbleOverlay(
          animation: animation,
          onChatOpened: onChatOpened,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    ),
  );
}

class FriendsBubbleOverlay extends StatefulWidget {
  final Animation<double> animation;
  final VoidCallback onChatOpened;

  const FriendsBubbleOverlay({
    super.key,
    required this.animation,
    required this.onChatOpened,
  });

  @override
  State<FriendsBubbleOverlay> createState() => _FriendsBubbleOverlayState();
}

class _FriendsBubbleOverlayState extends State<FriendsBubbleOverlay>
    with TickerProviderStateMixin {
  final FriendshipService _friendshipService = FriendshipService();
  final ChatService _chatService = ChatService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<FriendshipModel> _friends = [];
  bool _isLoading = true;
  int? _tappedIndex;

  RealtimeChannel? _profilesChannel;

  // Stagger animation controller for friend cards
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadFriends();
    _subscribeToProfileChanges();
  }

  @override
  void dispose() {
    _profilesChannel?.unsubscribe();
    _staggerController.dispose();
    super.dispose();
  }

  void _subscribeToProfileChanges() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _profilesChannel = _supabase
        .channel('friends-bubble-status-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) => _loadFriends(),
        )
        .subscribe();
  }

  Future<void> _loadFriends() async {
    final friends = await _friendshipService.getFriends();
    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
      _staggerController.forward(from: 0);
    }
  }

  Future<void> _openChatWithFriend(FriendshipModel friend, int index) async {
    if (friend.otherUserId == null) return;

    // Tap animation
    setState(() => _tappedIndex = index);
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;
    Navigator.pop(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conversation =
          await _chatService.getOrCreateConversation(friend.otherUserId!);
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            conversation: conversation,
            onMessageSent: widget.onChatOpened,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('failed_open_chat')}: $e')),
      );
    }
  }

  void _showFriendOptions(FriendshipModel friend) {
    final colorScheme = Theme.of(context).colorScheme;
    final friendName = friend.otherUserName ?? 'this user';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(friendName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.orange),
                title: Text(context.tr('unfriend')),
                subtitle:
                    Text('${context.tr('remove_from_friends')} $friendName'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmUnfriend(friend);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: colorScheme.error),
                title: Text('Block user',
                    style: TextStyle(color: colorScheme.error)),
                subtitle:
                    Text('${context.tr('block_and_remove')} $friendName'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock(friend);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnfriend(FriendshipModel friend) async {
    final friendName = friend.otherUserName ?? 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove, color: Colors.orange, size: 40),
        title: Text(context.tr('unfriend')),
        content: Text(
            'Are you sure you want to remove $friendName from your friends?\n\nYou can send a new friend request later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.tr('unfriend')),
          ),
        ],
      ),
    );

    if (confirmed != true || friend.otherUserId == null) return;
    final success =
        await _friendshipService.removeFriend(friend.otherUserId!);
    if (!mounted) return;

    if (success) {
      setState(
          () => _friends.removeWhere((f) => f.id == friend.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$friendName ${context.tr('removed_from_friends')}'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Future<void> _confirmBlock(FriendshipModel friend) async {
    final colorScheme = Theme.of(context).colorScheme;
    final friendName = friend.otherUserName ?? 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.block, color: colorScheme.error, size: 40),
        title: Text(context.tr('block_user')),
        content: Text(
            'Are you sure you want to block $friendName?\n\nThis will:\n• Remove them from your friends\n• Prevent them from sending you messages\n• Prevent them from sending friend requests\n\nYou can unblock them later from Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: Text(context.tr('block')),
          ),
        ],
      ),
    );

    if (confirmed != true || friend.otherUserId == null) return;
    final success = await _friendshipService.blockUser(friend.otherUserId!);
    if (!mounted) return;

    if (success) {
      setState(
          () => _friends.removeWhere((f) => f.id == friend.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$friendName ${context.tr('has_been_blocked')}'),
        backgroundColor: colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Bubble dimensions
    final bubbleWidth = screenWidth * 0.85;
    final bubbleMaxHeight = screenHeight * 0.65;
    final bubbleLeft = 12.0;
    final bubbleTop = topPadding + 56.0; // Below app bar

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
        // Backdrop - tap to close
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
          left: bubbleLeft,
          top: bubbleTop,
          child: AnimatedBuilder(
            animation: widget.animation,
            builder: (context, child) {
              final curved = CurvedAnimation(
                parent: widget.animation,
                curve: Curves.easeOutBack,
              );

              return Transform.scale(
                scale: curved.value,
                alignment: Alignment.topLeft,
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
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(24),
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
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    _buildBubbleHeader(colorScheme),
                    // Content
                    Flexible(
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : _friends.isEmpty
                              ? _buildEmptyState(colorScheme)
                              : _buildFriendsList(colorScheme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Small triangle pointer at top-left (pointing up-left toward button)
        Positioned(
          left: bubbleLeft + 14,
          top: bubbleTop - 8,
          child: AnimatedBuilder(
            animation: widget.animation,
            builder: (context, child) {
              return Opacity(
                opacity: widget.animation.value.clamp(0.0, 1.0),
                child: child,
              );
            },
            child: CustomPaint(
              size: const Size(16, 8),
              painter: _BubbleArrowPainter(color: colorScheme.surface),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildBubbleHeader(ColorScheme colorScheme) {
    final onlineCount =
        _friends.where((f) => f.otherUserIsOnline == true).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.people_rounded,
                  color: colorScheme.onPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_friends.length} ${_friends.length == 1 ? 'friend' : 'friends'}'
                  '${onlineCount > 0 ? ' · $onlineCount online' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // Close button
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
            child: Icon(Icons.people_outline_rounded,
                size: 56,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 12),
          Text('No friends yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('Add friends to start chatting',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _buildFriendsList(ColorScheme colorScheme) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        // Stagger delay per item
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final end = (delay + 0.4).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final itemProgress = Interval(delay, end, curve: Curves.easeOutCubic)
                .transform(_staggerController.value);

            return Transform.translate(
              offset: Offset(0, 20 * (1 - itemProgress)),
              child: Opacity(
                opacity: itemProgress.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: _buildFriendTile(_friends[index], index, colorScheme),
        );
      },
    );
  }

  Widget _buildFriendTile(
      FriendshipModel friend, int index, ColorScheme colorScheme) {
    final isOnline = friend.otherUserIsOnline ?? false;
    final isTapped = _tappedIndex == index;

    return AnimatedScale(
      scale: isTapped ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: isTapped
              ? colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openChatWithFriend(friend, index),
            onLongPress: () => _showFriendOptions(friend),
            borderRadius: BorderRadius.circular(14),
            splashColor: colorScheme.primary.withValues(alpha: 0.08),
            highlightColor: colorScheme.primary.withValues(alpha: 0.04),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Avatar with status
                  Stack(
                    children: [
                      Hero(
                        tag: 'friend_avatar_${friend.otherUserId}',
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: friend.otherUserAvatar != null
                              ? NetworkImage(friend.otherUserAvatar!)
                              : null,
                          child: friend.otherUserAvatar == null
                              ? Text(
                                  (friend.otherUserName ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorScheme.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Name + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.otherUserName ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF4CAF50)
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnline
                                    ? const Color(0xFF4CAF50)
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                fontWeight: isOnline
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chat icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: colorScheme.primary,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a small triangle arrow pointing upward (chat bubble tail)
class _BubbleArrowPainter extends CustomPainter {
  final Color color;
  _BubbleArrowPainter({required this.color});

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