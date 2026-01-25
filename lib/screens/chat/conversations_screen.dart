import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'user_selector_screen.dart';

/// Ecran pentru lista de conversații
/// Afișează toate conversațiile utilizatorului curent
/// și permite navigarea către ecranul de chat 1-la-1
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  /// Încarcă conversațiile din Supabase
  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await _chatService.getConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Navighează către ecranul de chat cu un utilizator
  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          conversation: conversation,
          onMessageSent: _loadConversations, // Reîncarcă lista când se trimite un mesaj
        ),
      ),
    );
  }

  /// Navighează către ecranul de selectare utilizatori
  void _openUserSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserSelectorScreen(),
      ),
    ).then((_) {
      // Când revenim din ecranul de selectare, reîncărcăm conversațiile
      _loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav_chat')),
        actions: [
          // Buton pentru a actualiza lista
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
          ),
        ],
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: FloatingActionButton(
        onPressed: _openUserSelector,
        child: const Icon(Icons.edit),
      ),
    );
  }

  /// Construiește corpul ecranului în funcție de stare
  Widget _buildBody(ColorScheme colorScheme) {
    // Dacă se încarcă, afișăm un indicator de loading
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Dacă există o eroare, afișăm mesajul de eroare
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
              onPressed: _loadConversations,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('retry')),
            ),
          ],
        ),
      );
    }

    // Dacă nu există conversații, afișăm un mesaj informativ
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_conversations'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('start_conversation'),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // Afișăm lista de conversații
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _buildConversationItem(conversation, colorScheme);
        },
      ),
    );
  }

  /// Construiește un item din lista de conversații
  Widget _buildConversationItem(Conversation conversation, ColorScheme colorScheme) {
    return ListTile(
      // Avatar-ul celuilalt participant
      leading: CircleAvatar(
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
                ),
              )
            : null,
      ),
      // Numele celuilalt participant
      title: Text(
        conversation.otherUserName ?? 'Unknown User',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      // Ultimul mesaj
      subtitle: conversation.lastMessage != null
          ? Text(
              conversation.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          : Text(
              context.tr('no_messages'),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
      // Timpul ultimului mesaj
      trailing: conversation.lastMessageAt != null
          ? Text(
              conversation.getFormattedTime(),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            )
          : null,
      // La tap, deschidem conversația
      onTap: () => _openChat(conversation),
    );
  }
}