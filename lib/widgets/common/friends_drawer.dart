import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friendship_model.dart';
import '../../services/friendship_service.dart';
import '../../services/chat_service.dart';
import '../../screens/chat/chat_detail_screen.dart';
import '../../l10n/app_localizations.dart';

/// Drawer pentru lista de prieteni
/// ✅ REALTIME: Statusul online/offline se actualizează INSTANT
///    Nu mai e nevoie să închizi și redeschizi drawer-ul
class FriendsDrawer extends StatefulWidget {
  final VoidCallback onChatOpened;

  const FriendsDrawer({
    super.key,
    required this.onChatOpened,
  });

  @override
  State<FriendsDrawer> createState() => _FriendsDrawerState();
}

class _FriendsDrawerState extends State<FriendsDrawer> {
  final FriendshipService _friendshipService = FriendshipService();
  final ChatService _chatService = ChatService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<FriendshipModel> _friends = [];
  bool _isLoading = true;

  // ✅ NOU: Realtime channel pentru status updates
  RealtimeChannel? _profilesChannel;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _subscribeToProfileChanges(); // ✅ Pornește ascultarea realtime
  }

  @override
  void dispose() {
    // ✅ Cleanup realtime subscription
    _profilesChannel?.unsubscribe();
    super.dispose();
  }

  /// ✅ NOU: Abonare la schimbări în tabela profiles (is_online)
  /// Când un prieten se conectează/deconectează → reload instant
  void _subscribeToProfileChanges() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Cleanup dacă există deja
    _profilesChannel?.unsubscribe();

    _profilesChannel = _supabase
        .channel('friends-online-status-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final changedColumn = payload.oldRecord.keys.toList();
            debugPrint('👤 Profile changed: ${payload.newRecord['id']} - columns: $changedColumn');
            
            // Verificăm dacă s-a schimbat is_online
            // Reîncărcăm lista de prieteni pentru a actualiza statusul
            _loadFriends();
          },
        )
        .subscribe();

    debugPrint('✅ Subscribed to profiles changes for realtime online status');
  }

  Future<void> _loadFriends() async {
    if (_friends.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    final friends = await _friendshipService.getFriends();
    
    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    }
  }

  Future<void> _openChatWithFriend(FriendshipModel friend) async {
    if (friend.otherUserId == null) return;

    // Închide drawer-ul
    Navigator.pop(context);

    // Arată loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Creează sau obține conversația
      final conversation = await _chatService.getOrCreateConversation(friend.otherUserId!);

      if (!mounted) return;

      // Închide loading
      Navigator.pop(context);

      // Deschide chat
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
      
      // Închide loading
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('failed_open_chat')}: $e')),
      );
    }
  }

  /// ✅ NOU: Arată opțiuni pentru un prieten (Unfriend / Block)
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
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  friendName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              // Unfriend
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.orange),
                title: Text(context.tr('unfriend')),
                subtitle: Text('${context.tr('remove_from_friends')} $friendName'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmUnfriend(friend);
                },
              ),
              // Block
              ListTile(
                leading: Icon(Icons.block, color: colorScheme.error),
                title: Text(
                  'Block user',
                  style: TextStyle(color: colorScheme.error),
                ),
                subtitle: Text('${context.tr('block_and_remove')} $friendName'),
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

  /// ✅ NOU: Confirmare Unfriend
  Future<void> _confirmUnfriend(FriendshipModel friend) async {
    final friendName = friend.otherUserName ?? 'this user';

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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text(context.tr('unfriend')),
          ),
        ],
      ),
    );

    if (confirmed != true || friend.otherUserId == null) return;

    final success = await _friendshipService.removeFriend(friend.otherUserId!);

    if (!mounted) return;

    if (success) {
      setState(() {
        _friends.removeWhere((f) => f.id == friend.id);
      });
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

  /// ✅ NOU: Confirmare Block
  Future<void> _confirmBlock(FriendshipModel friend) async {
    final colorScheme = Theme.of(context).colorScheme;
    final friendName = friend.otherUserName ?? 'this user';

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
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: Text(context.tr('block')),
          ),
        ],
      ),
    );

    if (confirmed != true || friend.otherUserId == null) return;

    final success = await _friendshipService.blockUser(friend.otherUserId!);

    if (!mounted) return;

    if (success) {
      setState(() {
        _friends.removeWhere((f) => f.id == friend.id);
      });
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

    return Drawer(
      child: Column(
        children: [
          // Header
          _buildHeader(colorScheme),

          // Lista de prieteni
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : RefreshIndicator(
                        onRefresh: _loadFriends,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _friends.length,
                          itemBuilder: (context, index) {
                            return _buildFriendCard(_friends[index], colorScheme);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    // Numără prietenii online
    final onlineCount = _friends.where((f) => f.otherUserIsOnline == true).length;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: colorScheme.onPrimary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Friends',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_friends.length} ${_friends.length == 1 ? 'friend' : 'friends'}'
            '${onlineCount > 0 ? ' · $onlineCount online' : ''}',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to start chatting',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendshipModel friend, ColorScheme colorScheme) {
    // ✅ Status REAL din database - acum se actualizează INSTANT via Realtime
    final isOnline = friend.otherUserIsOnline ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openChatWithFriend(friend),
        onLongPress: () => _showFriendOptions(friend),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar cu status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: friend.otherUserAvatar != null
                        ? NetworkImage(friend.otherUserAvatar!)
                        : null,
                    child: friend.otherUserAvatar == null
                        ? Text(
                            (friend.otherUserName ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  // Online status indicator (bulină verde)
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nume
                    Text(
                      friend.otherUserName ?? 'Unknown User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Status text (Online/Offline)
                    Row(
                      children: [
                        if (isOnline)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Online',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Offline',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Chat icon
              Icon(
                Icons.chat_bubble_outline,
                color: colorScheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}