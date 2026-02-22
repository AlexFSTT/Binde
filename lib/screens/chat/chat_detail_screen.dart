import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../services/notification_service.dart';
import '../../services/friendship_service.dart';
import '../feed/user_posts_screen.dart';
import 'dart:async';

/// Ecran pentru chat 1-la-1 între utilizatorul curent și un alt utilizator
/// Cu status Online/Last seen/Typing și profil clickable
/// ✅ FIX: Avatar-ul sender-ului se afișează corect la mesaje noi realtime
class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback? onMessageSent;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.onMessageSent,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final PresenceService _presenceService = PresenceService();
  final FriendshipService _friendshipService = FriendshipService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  // Pentru status
  bool _isOnline = false;
  DateTime? _lastSeen;
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _statusRefreshTimer;

  // ✅ NOU: Status relație (friend/blocked/blocked_by/none)
  String _relationshipStatus = 'friend'; // default friend - se actualizează async

  // Pentru Realtime
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    
    // ✅ FIX: Setăm conversația activă - suprimă push notifications din această conversație
    NotificationService.activeConversationId = widget.conversation.id;
    
    _loadMessages();
    _setupRealtimeSubscription();
    _markMessagesAsRead();
    _loadUserStatus();
    _setupTypingListener();
    _checkRelationshipStatus(); // ✅ NOU
    
    // Listener pentru când utilizatorul scrie
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // ✅ FIX: Curățăm conversația activă - push notifications revin la normal
    NotificationService.activeConversationId = null;
    
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _removeRealtimeSubscription();
    _typingTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _presenceService.dispose();
    super.dispose();
  }

  /// Încarcă status-ul utilizatorului (online/last seen)
  Future<void> _loadUserStatus() async {
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );
    
    final status = await _presenceService.getUserStatus(otherUserId);
    
    if (mounted) {
      setState(() {
        _isOnline = status['is_online'] as bool;
        _lastSeen = status['last_seen'] as DateTime?;
      });
    }

    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _loadUserStatus();
    });
  }

  /// Setup pentru typing indicator
  void _setupTypingListener() {
    _presenceService.subscribeToTyping(
      widget.conversation.id,
      (payload) {
        final userId = payload['user_id'] as String?;
        final isTyping = payload['is_typing'] as bool? ?? false;
        final currentUserId = _supabase.auth.currentUser?.id;

        if (userId != currentUserId && mounted) {
          setState(() {
            _isTyping = isTyping;
          });

          if (isTyping) {
            _typingTimer?.cancel();
            _typingTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _isTyping = false;
                });
              }
            });
          }
        }
      },
    );
  }

  /// Când utilizatorul scrie, trimitem indicator
  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      _presenceService.sendTypingIndicator(widget.conversation.id, true);
      
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _presenceService.sendTypingIndicator(widget.conversation.id, false);
      });
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final messages = await _chatService.getMessages(widget.conversation.id);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeSubscription() {
    _channel = _supabase
        .channel('messages:${widget.conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversation.id,
          ),
          callback: (payload) async {
            // ✅ FIX: Încărcăm mesajul cu JOIN pentru a avea avatar și nume
            final messageId = payload.newRecord['id'] as String;
            
            try {
              // Fetch complet mesajul cu avatar și nume
              // ✅ FOLOSIM ALIAS 'sender' consistent cu getMessages()
              final response = await _supabase
                  .from('messages')
                  .select('''
                    id,
                    conversation_id,
                    sender_id,
                    content,
                    is_read,
                    created_at,
                    sender:profiles!messages_sender_id_fkey(
                      full_name,
                      avatar_url
                    )
                  ''')
                  .eq('id', messageId)
                  .single();

              final newMessage = Message.fromJson(response);
              
              // ✅ FIX AVATAR "?": Extragem datele sender-ului din obiectul nested
              // Message.fromJson() nu parsează automat sender-ul nested,
              // trebuie extras manual și adăugat cu copyWith()
              final sender = response['sender'] as Map<String, dynamic>?;
              final messageWithSender = newMessage.copyWith(
                senderName: sender?['full_name'] as String?,
                senderAvatar: sender?['avatar_url'] as String?,
              );
              
              if (mounted) {
                setState(() {
                  // ✅ Verificăm să nu adăugăm mesajul duplicat
                  final exists = _messages.any((m) => m.id == messageWithSender.id);
                  if (!exists) {
                    _messages.add(messageWithSender);
                  }
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                final currentUserId = _supabase.auth.currentUser?.id;
                if (messageWithSender.senderId != currentUserId) {
                  _markMessagesAsRead();
                }
              }
            } catch (e) {
              debugPrint('Error fetching new message details: $e');
            }
          },
        )
        .subscribe();
  }

  void _removeRealtimeSubscription() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.conversation.id);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      _messageController.clear();
      
      await _presenceService.sendTypingIndicator(widget.conversation.id, false);

      await _chatService.sendMessage(widget.conversation.id, content);
      widget.onMessageSent?.call();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      _messageController.text = content;
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _openUserProfile() {
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPostsScreen(
          userId: otherUserId,
          userName: widget.conversation.otherUserName ?? 'User',
          userAvatar: widget.conversation.otherUserAvatar,
        ),
      ),
    );
  }

  /// ✅ NOU: Verifică relația cu celălalt user
  Future<void> _checkRelationshipStatus() async {
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );

    final status = await _friendshipService.getRelationshipStatus(otherUserId);

    if (mounted) {
      setState(() => _relationshipStatus = status);
    }
  }

  /// ✅ NOU: Trimite cerere de prietenie din chat (după unfriend)
  Future<void> _sendFriendRequestFromChat() async {
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );

    final success = await _friendshipService.sendFriendRequest(otherUserId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('friend_request_sent')),
          backgroundColor: Colors.green,
        ),
      );
      // Re-verifică statusul (va fi 'pending' acum pe partea sender-ului,
      // dar nu 'friend' până când receiver-ul acceptă)
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_send_friend_request')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ✅ NOU: Unblock direct din chat
  Future<void> _unblockFromChat() async {
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );
    final friendName = widget.conversation.otherUserName ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('unblock_user')),
        content: Text('${context.tr('unblock')} $friendName ${context.tr('unblock_restore_friendship')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('unblock')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _friendshipService.unblockUser(otherUserId);

    if (!mounted) return;

    if (success) {
      setState(() => _relationshipStatus = 'friend');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$friendName ${context.tr('unblocked_restored')}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Formatează timpul mesajului - WhatsApp style
  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    
    if (messageDate.isAtSameMomentAs(today)) {
      return timeStr;
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday $timeStr';
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      return '$day/$month $timeStr';
    }
  }

  /// ✅ NOU: Confirmare Unfriend din chat
  Future<void> _confirmUnfriend() async {
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );
    final friendName = widget.conversation.otherUserName ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove, color: Colors.orange, size: 40),
        title: Text(context.tr('unfriend')),
        content: Text(
          'Are you sure you want to remove $friendName from your friends?\n\n'
          'You can send a new friend request later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.tr('unfriend')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _friendshipService.removeFriend(otherUserId);

    if (!mounted) return;

    if (success) {
      setState(() => _relationshipStatus = 'none');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$friendName ${context.tr('removed_from_friends')}'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_remove_friend')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ✅ NOU: Confirmare Block din chat
  Future<void> _confirmBlock() async {
    final colorScheme = Theme.of(context).colorScheme;
    final otherUserId = widget.conversation.getOtherParticipantId(
      _supabase.auth.currentUser!.id,
    );
    final friendName = widget.conversation.otherUserName ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.block, color: colorScheme.error, size: 40),
        title: Text(context.tr('block_user')),
        content: Text(
          'Are you sure you want to block $friendName?\n\n'
          'This will:\n'
          '• Remove them from your friends\n'
          '• Prevent them from sending you messages\n'
          '• Prevent them from sending friend requests\n\n'
          'You can unblock them later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: Text(context.tr('block')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _friendshipService.blockUser(otherUserId);

    if (!mounted) return;

    if (success) {
      setState(() => _relationshipStatus = 'blocked');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$friendName ${context.tr('has_been_blocked')}'),
          backgroundColor: colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_block_user')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ✅ NOU: Determină dacă informațiile profilului sunt vizibile
    final bool showProfileInfo = _relationshipStatus == 'friend';

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          // ✅ Dezactivează tap pe profil dacă nu sunt prieteni
          onTap: showProfileInfo ? _openUserProfile : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'chat_avatar_${widget.conversation.getOtherParticipantId(_supabase.auth.currentUser!.id)}',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: showProfileInfo
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  // ✅ Ascunde poza de profil dacă nu sunt prieteni
                  backgroundImage: showProfileInfo && widget.conversation.otherUserAvatar != null
                      ? NetworkImage(widget.conversation.otherUserAvatar!)
                      : null,
                  child: showProfileInfo && widget.conversation.otherUserAvatar == null
                      ? Text(
                          (widget.conversation.otherUserName ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : !showProfileInfo
                          ? Icon(
                              Icons.person,
                              size: 18,
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                            )
                          : null,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.conversation.otherUserName ?? 'Chat',
                      style: const TextStyle(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ✅ Ascunde statusul dacă nu sunt prieteni
                    if (showProfileInfo)
                      _buildStatusSubtitle(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'unfriend':
                  _confirmUnfriend();
                  break;
                case 'block':
                  _confirmBlock();
                  break;
                case 'unblock':
                  _unblockFromChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Unfriend - doar dacă sunt prieteni
              if (_relationshipStatus == 'friend')
                PopupMenuItem(
                  value: 'unfriend',
                  child: Row(
                    children: [
                      const Icon(Icons.person_remove, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Text(context.tr('unfriend')),
                    ],
                  ),
                ),
              // Block - dacă NU e deja blocat
              if (_relationshipStatus != 'blocked')
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Block user',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              // Unblock - doar dacă e blocat
              if (_relationshipStatus == 'blocked')
                PopupMenuItem(
                  value: 'unblock',
                  child: Row(
                    children: [
                      Icon(Icons.lock_open, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Unblock user',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList(colorScheme)),
          _buildBottomBar(colorScheme),
        ],
      ),
    );
  }

  /// ✅ NOU: Bottom bar condițional pe baza relației
  Widget _buildBottomBar(ColorScheme colorScheme) {
    switch (_relationshipStatus) {
      case 'blocked':
        return _buildBlockedBanner(colorScheme);
      case 'blocked_by':
        return _buildBlockedByBanner(colorScheme);
      case 'none':
        return _buildUnfriendedBanner(colorScheme);
      default: // 'friend'
        return _buildMessageInput(colorScheme);
    }
  }

  /// ✅ Banner: Tu ai blocat acest user
  /// ✅ Banner compact: Tu ai blocat acest user
  Widget _buildBlockedBanner(ColorScheme colorScheme) {
    return _buildStatusBanner(
      colorScheme: colorScheme,
      accentColor: colorScheme.error,
      icon: Icons.block_rounded,
      title: 'You blocked this user',
      subtitle: 'Messages are disabled',
      actionLabel: 'Unblock',
      actionIcon: Icons.lock_open_rounded,
      onAction: _unblockFromChat,
    );
  }

  /// ✅ Banner compact: Celălalt user te-a blocat
  Widget _buildBlockedByBanner(ColorScheme colorScheme) {
    return _buildStatusBanner(
      colorScheme: colorScheme,
      accentColor: colorScheme.error,
      icon: Icons.block_rounded,
      title: 'You have been blocked',
      subtitle: 'You can\'t send messages or requests',
    );
  }

  /// ✅ Banner compact: Nu mai sunteți prieteni
  Widget _buildUnfriendedBanner(ColorScheme colorScheme) {
    return _buildStatusBanner(
      colorScheme: colorScheme,
      accentColor: Colors.orange,
      icon: Icons.person_off_rounded,
      title: 'You are no longer friends',
      subtitle: 'Send a request to reconnect',
      actionLabel: 'Add Friend',
      actionIcon: Icons.person_add_rounded,
      onAction: _sendFriendRequestFromChat,
    );
  }

  /// ✅ Widget reutilizabil pentru toate bannerele
  Widget _buildStatusBanner({
    required ColorScheme colorScheme,
    required Color accentColor,
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Icon mic circular
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 17),
            ),
            const SizedBox(width: 10),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Buton (opțional)
            if (actionLabel != null && onAction != null)
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 15),
                label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSubtitle(ColorScheme colorScheme) {
    if (_isTyping) {
      return Text(
        'typing...',
        style: TextStyle(
          fontSize: 12,
          color: Colors.green[400],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (_isOnline) {
      return Text(
        'Online',
        style: TextStyle(
          fontSize: 12,
          color: Colors.green[400],
        ),
      );
    }

    return Text(
      _presenceService.formatLastSeen(_lastSeen, _isOnline),
      style: TextStyle(
        fontSize: 11,
        color: colorScheme.onSurface.withValues(alpha: 0.6),
        fontStyle: _lastSeen == null ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }

  Widget _buildMessagesList(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(context.tr('error_loading'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMessages,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('retry')),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_outlined, size: 80,
                color: colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(context.tr('No messages yet'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(context.tr('Start the conversation by sending a message!'),
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final currentUserId = _supabase.auth.currentUser?.id;
        final isMine = message.senderId == currentUserId;
        return _buildMessageBubble(message, isMine, colorScheme);
      },
    );
  }

  /// Construiește un balon de mesaj STILIZAT - WhatsApp style
  Widget _buildMessageBubble(Message message, bool isMine, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar pentru mesajele celorlalți (stânga)
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null
                  ? Text((message.senderName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                          color: colorScheme.onPrimaryContainer, fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          // Balonul cu mesajul - DESIGN NOU STILIZAT
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine
                    ? colorScheme.primaryContainer.withValues(alpha: 0.9)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMine
                      ? const Radius.circular(18)
                      : const Radius.circular(2),
                  bottomRight: isMine
                      ? const Radius.circular(2)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMine
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Spațiu pentru mesajele mele (dreapta)
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.tr('type_message'),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      Icons.send,
                      color: colorScheme.onPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}