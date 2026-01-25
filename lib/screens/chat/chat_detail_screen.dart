import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';

/// Ecran pentru chat 1-la-1 între utilizatorul curent și un alt utilizator
/// Afișează mesajele existente și permite trimiterea de mesaje noi
/// Mesajele se actualizează în timp real folosind Supabase Realtime
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  // Pentru Realtime subscription
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _removeRealtimeSubscription();
    super.dispose();
  }

  /// Încarcă mesajele existente din Supabase
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

      // Scroll la ultimul mesaj după ce se încarcă
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

  /// Configurează subscription-ul Realtime pentru mesaje noi
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
          callback: (payload) {
            // Când primim un mesaj nou, îl adăugăm la listă
            final newMessage = Message.fromJson(payload.newRecord);
            setState(() {
              _messages.add(newMessage);
            });

            // Scroll la mesajul nou
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });

            // Marcăm mesajul ca citit dacă nu este al nostru
            final currentUserId = _supabase.auth.currentUser?.id;
            if (newMessage.senderId != currentUserId) {
              _markMessagesAsRead();
            }
          },
        )
        .subscribe();
  }

  /// Elimină subscription-ul Realtime când părăsim ecranul
  void _removeRealtimeSubscription() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
  }

  /// Marchează toate mesajele ca citite
  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.conversation.id);
  }

  /// Trimite un mesaj nou
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Ștergem textul din input înainte de trimitere pentru UX mai bun
      _messageController.clear();

      await _chatService.sendMessage(widget.conversation.id, content);

      // Notificăm callback-ul că s-a trimis un mesaj
      widget.onMessageSent?.call();

      // Scroll la ultimul mesaj
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      // Dacă apare o eroare, afișăm un mesaj
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('message_error')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      // Punem textul înapoi în input
      _messageController.text = content;
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// Scroll automat la ultimul mesaj
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Avatar-ul celuilalt participant
            CircleAvatar(
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
            const SizedBox(width: 12),
            // Numele celuilalt participant
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.otherUserName ?? 'Unknown User',
                    style: const TextStyle(fontSize: 16),
                  ),
                  // TODO: În viitor, aici putem afișa status online/offline
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Lista de mesaje
          Expanded(
            child: _buildMessagesList(colorScheme),
          ),
          // Input pentru mesaje noi - stil WhatsApp
          _buildWhatsAppStyleMessageInput(colorScheme),
        ],
      ),
    );
  }

  /// Construiește lista de mesaje
  Widget _buildMessagesList(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
              context.tr('error_loading'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
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
            Icon(
              Icons.chat_outlined,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_messages'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('say_hi'),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
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

  /// Construiește un balon de mesaj
  Widget _buildMessageBubble(
    Message message,
    bool isMine,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                  ? Text(
                      (message.senderName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          // Balonul cu mesajul
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMine
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMine
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMine
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.getFormattedTime(),
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

  /// Construiește input-ul pentru mesaje noi - Stil WhatsApp
  /// Design curat, fără background container, doar TextField și buton
  Widget _buildWhatsAppStyleMessageInput(ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Câmpul de text - stil WhatsApp
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
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    // Iconița de emoji (opțional - poți să o scoți)
                    prefixIcon: Icon(
                      Icons.emoji_emotions_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Buton de trimitere - stil WhatsApp
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: colorScheme.onPrimary,
                        size: 22,
                      ),
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