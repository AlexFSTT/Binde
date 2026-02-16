import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import 'user_profile_view_screen.dart';
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

  // Pentru Realtime
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    
    _loadMessages();
    _setupRealtimeSubscription();
    _markMessagesAsRead();
    _loadUserStatus();
    _setupTypingListener();
    
    // Listener pentru când utilizatorul scrie
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
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
        builder: (context) => UserProfileViewScreen(
          userId: otherUserId,
          userName: widget.conversation.otherUserName,
          userAvatar: widget.conversation.otherUserAvatar,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _openUserProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'chat_avatar_${widget.conversation.getOtherParticipantId(_supabase.auth.currentUser!.id)}',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: widget.conversation.otherUserAvatar != null
                      ? NetworkImage(widget.conversation.otherUserAvatar!)
                      : null,
                  child: widget.conversation.otherUserAvatar == null
                      ? Text(
                          (widget.conversation.otherUserName ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
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
                    // Status sub-titlu
                    _buildStatusSubtitle(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList(colorScheme)),
          _buildMessageInput(colorScheme),
        ],
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