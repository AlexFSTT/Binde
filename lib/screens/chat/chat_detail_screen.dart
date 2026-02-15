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
/// INCLUDE: Bubble design îmbunătățit + fix avatar Realtime + fix timezone
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
              final response = await _supabase
                  .from('messages')
                  .select('''
                    id,
                    conversation_id,
                    sender_id,
                    content,
                    is_read,
                    created_at,
                    profiles:sender_id (
                      full_name,
                      avatar_url
                    )
                  ''')
                  .eq('id', messageId)
                  .single();

              final newMessage = Message.fromJson(response);
              
              if (mounted) {
                setState(() {
                  _messages.add(newMessage);
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                final currentUserId = _supabase.auth.currentUser?.id;
                if (newMessage.senderId != currentUserId) {
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
            content: Text('${context.tr('message_error')}: $e'),
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
                          (widget.conversation.otherUserName ?? '?')[0]
                              .toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.conversation.otherUserName ?? 'Unknown User',
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildStatusText(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(colorScheme),
          ),
          _buildWhatsAppStyleMessageInput(colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusText(ColorScheme colorScheme) {
    String statusText;
    Color statusColor;

    if (_isTyping) {
      statusText = 'typing...';
      statusColor = colorScheme.primary;
    } else if (_isOnline) {
      statusText = 'Online';
      statusColor = Colors.green;
    } else {
      statusText = _presenceService.formatLastSeen(_lastSeen, _isOnline);
      statusColor = colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Text(
      statusText,
      style: TextStyle(
        fontSize: 12,
        color: statusColor,
        fontStyle: _isTyping ? FontStyle.italic : FontStyle.normal,
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
                // Background mai întunecat
                color: isMine
                    ? colorScheme.primaryContainer.withValues(alpha: 0.9)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                // Partea rotundă lângă avatar - ca un balon
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMine
                      ? const Radius.circular(18)
                      : const Radius.circular(2), // ← Colt ascuțit lângă avatar
                  bottomRight: isMine
                      ? const Radius.circular(2)  // ← Colt ascuțit lângă avatar
                      : const Radius.circular(18),
                ),
                // Shadow pentru depth
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
                  // ✅ TIMP ÎMBUNĂTĂȚIT - ora/yesterday/data
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formatează timpul pentru mesaje - WhatsApp style
  /// ✅ FIX TIMEZONE: Folosim .toLocal() pentru ora locală a device-ului
  /// - Astăzi → "14:30"
  /// - Ieri → "yesterday"
  /// - Altă zi → "23/01/2025"
  String _formatMessageTime(DateTime? messageTime) {
    if (messageTime == null) return '';

    // ✅ CONVERTIM LA TIMEZONE LOCAL
    final localTime = messageTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);

    // Formatăm ora LOCALĂ
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');

    // Astăzi → doar ora
    if (messageDate.isAtSameMomentAs(today)) {
      return '$hour:$minute';
    }

    // Ieri → "yesterday"
    if (messageDate.isAtSameMomentAs(yesterday)) {
      return 'yesterday';
    }

    // Altă zi → data completă
    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    final year = localTime.year;

    return '$day/$month/$year';
  }

  Widget _buildWhatsAppStyleMessageInput(ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: context.tr('type_message'),
                    hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    prefixIcon: Icon(Icons.emoji_emotions_outlined,
                        color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                  color: colorScheme.primary, shape: BoxShape.circle),
              child: IconButton(
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary)))
                    : Icon(Icons.send,
                        color: colorScheme.onPrimary, size: 22),
                onPressed: _isSending ? null : _sendMessage,
                splashRadius: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}