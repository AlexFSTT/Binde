import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/common/notification_badge.dart';
import '../../widgets/common/friends_drawer.dart';
import '../../providers/notification_provider.dart';
import '../notifications/notifications_screen.dart';
import 'chat_detail_screen.dart';
import '../friends/friend_search_screen.dart';

/// Ecran pentru lista de conversații
/// ✅ BADGE SEPARATION:
///    - Clopotel (bell icon) = DOAR friend requests (cu COUNTER)
///    - Chat tab (bottom nav) = friend requests + mesaje necitite (cu COUNTER)
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<Conversation> _conversations = [];
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  String? _error;
  
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _removeRealtimeSubscription();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    debugPrint('🔔 Setting up Realtime subscription for conversations');

    _messagesChannel = _supabase
        .channel('all_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            debugPrint('📨 Received message update via Realtime');
            _loadConversations();
          },
        )
        .subscribe();
  }

  void _removeRealtimeSubscription() {
    if (_messagesChannel != null) {
      debugPrint('🔕 Removing Realtime subscription');
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  Future<void> _loadConversations() async {
    if (_conversations.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final conversations = await _chatService.getConversations();
      
      final unreadCounts = <String, int>{};
      for (final conversation in conversations) {
        final count = await _getUnreadCount(conversation.id);
        if (count > 0) {
          unreadCounts[conversation.id] = count;
        }
      }
      
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _unreadCounts = unreadCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<int> _getUnreadCount(String conversationId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;

      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId)
          .count();

      return response.count;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          conversation: conversation,
          onMessageSent: _loadConversations,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  void _openUserSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendSearchScreen(),
      ),
    ).then((_) => _loadConversations());
  }

  /// Formatează timpul conversației
  String _formatConversationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Acum';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}z';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // ✅ COUNTER pentru clopotel = doar friend requests
    final chatNotificationCount = ref.watch(chatNotificationCountProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: FriendsDrawer(
        onChatOpened: _loadConversations,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.people_outline),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Friends',
        ),
        title: Text(context.tr('nav_chat')),
        actions: [
          // ✅ CLOPOTEL = doar friend requests cu COUNTER
          IconButton(
            icon: NotificationBadge(
              count: chatNotificationCount,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(category: 'chat'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: FloatingActionButton(
        heroTag: 'conversations_fab',
        onPressed: _openUserSelector,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
              'Error: $_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_conversations'),
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
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final unreadCount = _unreadCounts[conversation.id] ?? 0;
          return _buildConversationCard(conversation, colorScheme, unreadCount);
        },
      ),
    );
  }

  Widget _buildConversationCard(
    Conversation conversation,
    ColorScheme colorScheme,
    int unreadCount,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0, left: 2),
      child: SizedBox(
        height: 66,
        child: Stack(
          children: [
            Positioned(
              left: 26,
              right: 0,
              top: 7,
              bottom: 7,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () => _openChat(conversation),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 10,
                      top: 5,
                      bottom: 5,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversation.otherUserName ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // ✅ Counter badge pe conversație
                                  if (unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (conversation.lastMessage != null)
                                Text(
                                  conversation.lastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                )
                              else
                                Text(
                                  context.tr('Start the conversation by sending a message!'),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (conversation.lastMessageAt != null)
                          Text(
                            _formatConversationTime(conversation.lastMessageAt!),
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            Positioned(
              left: 0,
              top: 7,
              child: Hero(
                tag: 'conversation_avatar_${conversation.id}',
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: conversation.otherUserAvatar != null
                          ? NetworkImage(conversation.otherUserAvatar!)
                          : null,
                      child: conversation.otherUserAvatar == null
                          ? Text(
                              (conversation.otherUserName ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}