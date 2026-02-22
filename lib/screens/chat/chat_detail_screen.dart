import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
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
  bool _showAttachMenu = false;
  final ImagePicker _imagePicker = ImagePicker();

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
                    message_type,
                    attachment_url,
                    file_name,
                    file_size,
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

  // =====================================================
  // MEDIA PICKING & SENDING
  // =====================================================

  Future<void> _pickAndSendImage() async {
    setState(() => _showAttachMenu = false);
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _sendMediaFile(File(picked.path), MessageType.image);
  }

  Future<void> _pickAndSendVideo() async {
    setState(() => _showAttachMenu = false);
    final picked = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    await _sendMediaFile(File(picked.path), MessageType.video);
  }

  Future<void> _pickAndSendFile() async {
    setState(() => _showAttachMenu = false);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _sendMediaFile(File(path), MessageType.file);
  }

  Future<void> _sendMediaFile(File file, MessageType type) async {
    setState(() => _isSending = true);
    try {
      await _chatService.sendMediaMessage(
        conversationId: widget.conversation.id,
        file: file,
        messageType: type,
      );
      widget.onMessageSent?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
          // Balonul cu mesajul
          Flexible(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isMine
                    ? colorScheme.primary.withValues(alpha: 0.22)
                    : colorScheme.surfaceContainerHigh,
                border: isMine
                    ? Border.all(color: colorScheme.primary.withValues(alpha: 0.15))
                    : Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
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
                  // Media content
                  if (message.messageType == MessageType.image && message.attachmentUrl != null)
                    _buildImageBubble(message, colorScheme)
                  else if (message.messageType == MessageType.video && message.attachmentUrl != null)
                    _buildVideoBubble(message, colorScheme)
                  else if (message.messageType == MessageType.file && message.attachmentUrl != null)
                    _buildFileBubble(message, isMine, colorScheme),

                  // Text content (or caption for media)
                  if (message.messageType == MessageType.text ||
                      (message.content.isNotEmpty &&
                       !message.content.startsWith('📷') &&
                       !message.content.startsWith('🎥') &&
                       !message.content.startsWith('📎')))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                    ),

                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: Text(
                      _formatMessageTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine
                            ? colorScheme.primary.withValues(alpha: 0.7)
                            : colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
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

  Widget _buildImageBubble(Message message, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _openMediaGallery(message),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 300),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(17),
            topRight: Radius.circular(17),
          ),
          child: Image.network(
            message.attachmentUrl!,
            fit: BoxFit.cover,
            width: 260,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: 150,
                width: 260,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => SizedBox(
              height: 100,
              width: 260,
              child: Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 40, color: colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(Message message, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _openMediaGallery(message),
      child: _ChatVideoThumbnail(
        url: message.attachmentUrl!,
        fileName: message.fileName,
        fileSize: message.formattedFileSize,
      ),
    );
  }

  Widget _buildFileBubble(Message message, bool isMine, ColorScheme colorScheme) {
    return _ChatFileCard(
      url: message.attachmentUrl!,
      fileName: message.fileName ?? 'File',
      fileSize: message.formattedFileSize,
      colorScheme: colorScheme,
    );
  }

  /// Collect all media messages and open gallery at the tapped item
  void _openMediaGallery(Message tappedMessage) {
    final mediaMessages = _messages
        .where((m) =>
            m.attachmentUrl != null &&
            (m.messageType == MessageType.image || m.messageType == MessageType.video))
        .toList();

    if (mediaMessages.isEmpty) return;

    final startIndex = mediaMessages.indexWhere((m) => m.id == tappedMessage.id);

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => _MediaGalleryScreen(
          mediaMessages: mediaMessages,
          initialIndex: startIndex >= 0 ? startIndex : 0,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thin separator
        Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),

        // Attach menu (expandable)
        if (_showAttachMenu)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _buildAttachOption(
                  icon: Icons.image_outlined,
                  label: context.tr('photo'),
                  color: Colors.green[600]!,
                  onTap: _pickAndSendImage,
                ),
                _buildAttachOption(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  color: Colors.red[400]!,
                  onTap: _pickAndSendVideo,
                ),
                _buildAttachOption(
                  icon: Icons.insert_drive_file_outlined,
                  label: context.tr('file'),
                  color: Colors.blue[400]!,
                  onTap: _pickAndSendFile,
                ),
              ],
            ),
          ),

        // Input row
        Padding(
          padding: EdgeInsets.only(
            left: 6,
            right: 6,
            top: 6,
            bottom: MediaQuery.of(context).padding.bottom + 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach button
              IconButton(
                onPressed: () => setState(() => _showAttachMenu = !_showAttachMenu),
                icon: AnimatedRotation(
                  turns: _showAttachMenu ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: _showAttachMenu
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 26,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),

              // Text field — clean, no background
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: context.tr('type_message'),
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    filled: false,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Send button
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
                          size: 20,
                        ),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// =============================================================
// Video Thumbnail in chat bubble (tap opens gallery)
// =============================================================
class _ChatVideoThumbnail extends StatefulWidget {
  final String url;
  final String? fileName;
  final String fileSize;

  const _ChatVideoThumbnail({
    required this.url,
    this.fileName,
    this.fileSize = '',
  });

  @override
  State<_ChatVideoThumbnail> createState() => _ChatVideoThumbnailState();
}

class _ChatVideoThumbnailState extends State<_ChatVideoThumbnail> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _ctrl!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Thumbnail failed — show placeholder
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 300),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(17),
          topRight: Radius.circular(17),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video first frame or placeholder
            if (_ready && _ctrl != null)
              AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio > 0.1
                    ? _ctrl!.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(_ctrl!),
              )
            else
              Container(
                width: 260,
                height: 180,
                color: cs.onSurface.withValues(alpha: 0.08),
                child: Icon(
                  Icons.videocam_rounded,
                  size: 40,
                  color: cs.onSurface.withValues(alpha: 0.2),
                ),
              ),

            // Play icon overlay
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),

            // Duration badge bottom-right
            if (_ready && _ctrl != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _fmtDur(_ctrl!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// =============================================================
// Media Gallery — swipe between images & videos (WhatsApp style)
// =============================================================
class _MediaGalleryScreen extends StatefulWidget {
  final List<Message> mediaMessages;
  final int initialIndex;

  const _MediaGalleryScreen({
    required this.mediaMessages,
    required this.initialIndex,
  });

  @override
  State<_MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<_MediaGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.mediaMessages[_currentIndex];
    final total = widget.mediaMessages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          children: [
            Text(
              msg.senderName ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_currentIndex + 1} / $total',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final item = widget.mediaMessages[index];
          if (item.messageType == MessageType.video) {
            return _GalleryVideoPage(url: item.attachmentUrl!);
          }
          return _GalleryImagePage(url: item.attachmentUrl!);
        },
      ),
    );
  }
}

// --- Gallery Image Page (pinch-to-zoom) ---
class _GalleryImagePage extends StatelessWidget {
  final String url;
  const _GalleryImagePage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (_, _, _) => Icon(
            Icons.broken_image_outlined,
            size: 60,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// --- Gallery Video Page (full player with controls) ---
class _GalleryVideoPage extends StatefulWidget {
  final String url;
  const _GalleryVideoPage({required this.url});

  @override
  State<_GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends State<_GalleryVideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {'Accept': '*/*'},
    );
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _controller.value.isPlaying) {
            setState(() => _showControls = false);
          }
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _hasError = true);
    });
    _controller.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (_controller.value.position >= _controller.value.duration &&
          _controller.value.duration > Duration.zero) {
        _controller.seekTo(Duration.zero);
        _controller.pause();
        setState(() => _showControls = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _showControls = true);
    } else {
      _controller.play();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load video',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }

    final isPlaying = _controller.value.isPlaying;
    final ar = _controller.value.aspectRatio;

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: ar > 0.1 ? ar : 16 / 9,
              child: VideoPlayer(_controller),
            ),

            // Play/Pause
            if (_showControls || !isPlaying)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

            // Progress bar
            if (_showControls || !isPlaying)
              Positioned(
                left: 16,
                right: 16,
                bottom: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 20,
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white.withValues(alpha: 0.3),
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmtDur(_controller.value.position),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          _fmtDur(_controller.value.duration),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// File Card — in-app download & open
// =============================================================
class _ChatFileCard extends StatefulWidget {
  final String url;
  final String fileName;
  final String fileSize;
  final ColorScheme colorScheme;

  const _ChatFileCard({
    required this.url,
    required this.fileName,
    this.fileSize = '',
    required this.colorScheme,
  });

  @override
  State<_ChatFileCard> createState() => _ChatFileCardState();
}

class _ChatFileCardState extends State<_ChatFileCard> {
  _FileDownloadState _state = _FileDownloadState.idle;
  double _progress = 0;
  String? _localPath;

  IconData get _iconData {
    final ext = widget.fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip;
    if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) return Icons.audiotrack;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    if (['txt', 'csv', 'json'].contains(ext)) return Icons.article;
    return Icons.insert_drive_file;
  }

  Color get _iconColor {
    final ext = widget.fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Colors.red;
    if (['doc', 'docx'].contains(ext)) return Colors.blue[700]!;
    if (['xls', 'xlsx'].contains(ext)) return Colors.green[700]!;
    if (['zip', 'rar', '7z'].contains(ext)) return Colors.orange;
    if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) return Colors.purple;
    if (['ppt', 'pptx'].contains(ext)) return Colors.deepOrange;
    return Colors.blueGrey;
  }

  Future<void> _downloadAndOpen() async {
    if (_state == _FileDownloadState.downloading) return;

    // If already downloaded, just open
    if (_localPath != null && await File(_localPath!).exists()) {
      await OpenFilex.open(_localPath!);
      return;
    }

    setState(() {
      _state = _FileDownloadState.downloading;
      _progress = 0;
    });

    try {
      // Get download directory
      final dir = await getApplicationDocumentsDirectory();
      final bindeDir = Directory('${dir.path}/Binde');
      if (!await bindeDir.exists()) await bindeDir.create(recursive: true);
      final filePath = '${bindeDir.path}/${widget.fileName}';

      // Download with progress
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 0;

      final file = File(filePath);
      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _progress = received / totalBytes);
        }
      }
      await sink.close();

      if (mounted) {
        setState(() {
          _localPath = filePath;
          _state = _FileDownloadState.done;
        });
        // Auto-open after download
        await OpenFilex.open(filePath);
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      if (mounted) {
        setState(() => _state = _FileDownloadState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isDownloading = _state == _FileDownloadState.downloading;
    final isDone = _state == _FileDownloadState.done;

    return GestureDetector(
      onTap: _downloadAndOpen,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon with progress ring
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconData, color: _iconColor, size: 24),
                  ),
                  if (isDownloading)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        strokeWidth: 2.5,
                        color: _iconColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (widget.fileSize.isNotEmpty)
                        Text(
                          widget.fileSize,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      if (widget.fileSize.isNotEmpty && !isDownloading)
                        Text(
                          '  ·  ',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3)),
                        ),
                      if (isDownloading)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${(_progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: _iconColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Text(
                          isDone ? 'Tap to open' : 'Tap to download',
                          style: TextStyle(
                            fontSize: 11,
                            color: _iconColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Action icon
            Icon(
              isDownloading
                  ? Icons.downloading_rounded
                  : isDone
                      ? Icons.open_in_new_rounded
                      : Icons.download_rounded,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FileDownloadState { idle, downloading, done, error }