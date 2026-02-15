import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friendship_model.dart';
import '../../services/friendship_service.dart';
import '../../l10n/app_localizations.dart';

/// Ecran split pentru căutare useri + pending friend requests
/// ✅ REALTIME: Lista de pending se actualizează automat când cineva acceptă/refuză cererea
class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ REALTIME: Channel pentru schimbări în friendships
  RealtimeChannel? _friendshipsChannel;

  List<Map<String, dynamic>> _searchResults = [];
  List<FriendshipModel> _pendingRequests = [];
  bool _isSearching = false;
  bool _isLoadingPending = false;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    _subscribeFriendshipsRealtime(); // ✅ Pornește ascultarea în timp real
  }

  @override
  void dispose() {
    _friendshipsChannel?.unsubscribe(); // ✅ Cleanup subscription
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ REALTIME: Subscription la tabelul friendships
  /// Ascultă când cineva acceptă/refuză/șterge un friend request
  void _subscribeFriendshipsRealtime() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Cleanup dacă există deja
    _friendshipsChannel?.unsubscribe();

    // Subscribe la schimbări în friendships unde user-ul e sender SAU receiver
    _friendshipsChannel = _supabase
        .channel('friendships-changes-$uid')
        // Ascultă când user-ul e sender (a trimis cererea)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: uid,
          ),
          callback: (_) => _onFriendshipsChanged(),
        )
        // Ascultă când user-ul e receiver (a primit cererea)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: uid,
          ),
          callback: (_) => _onFriendshipsChanged(),
        )
        .subscribe();
  }

  /// ✅ REALTIME: Handler pentru schimbări
  /// Se apelează automat când se schimbă ceva în friendships
  void _onFriendshipsChanged() {
    if (!mounted) return;

    // Refresh lista de pending instant
    _loadPendingRequests();

    // Refresh search results dacă user-ul caută
    // (ca să dispară userii care au devenit pending/accepted)
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _searchUsers(query);
    }
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoadingPending = true);

    final requests = await _friendshipService.getSentFriendRequests();

    if (mounted) {
      setState(() {
        _pendingRequests = requests;
        _isLoadingPending = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await _friendshipService.searchAvailableUsers(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String userId, String userName) async {
    final success = await _friendshipService.sendFriendRequest(userId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('friend_request_sent_to')} $userName')),
      );

      // Refresh lists
      _searchUsers(_searchController.text);
      _loadPendingRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('failed_to_send_friend_request'))),
      );
    }
  }

  Future<void> _cancelRequest(String friendshipId) async {
    final success = await _friendshipService.cancelFriendRequest(friendshipId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('friend_request_cancelled'))),
      );
      _loadPendingRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('add_friends')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search_users'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildSearchSection(colorScheme)),
          Divider(
            height: 1,
            thickness: 2,
            color: colorScheme.outlineVariant,
          ),
          Expanded(child: _buildPendingSection(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.tr('search_results'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? context.tr('start_typing_to_search')
                                : context.tr('no_users_found'),
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return _buildUserCard(user, colorScheme);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPendingSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                context.tr('pending_requests'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_pendingRequests.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pendingRequests.length}',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _isLoadingPending
              ? const Center(child: CircularProgressIndicator())
              : _pendingRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pending_actions,
                            size: 64,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('no_pending_requests'),
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _pendingRequests.length,
                      itemBuilder: (context, index) {
                        final request = _pendingRequests[index];
                        return _buildPendingCard(request, colorScheme);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, ColorScheme colorScheme) {
    final userId = user['id'] as String;
    final fullName = user['full_name'] as String?;
    final avatarUrl = user['avatar_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  (fullName ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          fullName ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _sendFriendRequest(userId, fullName ?? 'User'),
          icon: const Icon(Icons.person_add, size: 18),
          label: Text(context.tr('add')),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard(FriendshipModel request, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          backgroundImage: request.otherUserAvatar != null
              ? NetworkImage(request.otherUserAvatar!)
              : null,
          child: request.otherUserAvatar == null
              ? Text(
                  (request.otherUserName ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          request.otherUserName ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          context.tr('pending'),
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: TextButton.icon(
          onPressed: () => _cancelRequest(request.id),
          icon: const Icon(Icons.close, size: 18),
          label: Text(context.tr('cancel')),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.error,
          ),
        ),
      ),
    );
  }
}