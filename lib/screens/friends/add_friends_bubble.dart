import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friendship_model.dart';
import '../../services/friendship_service.dart';
import '../../l10n/app_localizations.dart';

/// Shows the add friends bubble overlay. Returns true if any changes were made.
Future<bool> showAddFriendsBubble(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddFriendsBubbleOverlay(animation: animation);
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    ),
  );
  return result ?? false;
}

class AddFriendsBubbleOverlay extends StatefulWidget {
  final Animation<double> animation;

  const AddFriendsBubbleOverlay({super.key, required this.animation});

  @override
  State<AddFriendsBubbleOverlay> createState() =>
      _AddFriendsBubbleOverlayState();
}

class _AddFriendsBubbleOverlayState extends State<AddFriendsBubbleOverlay>
    with TickerProviderStateMixin {
  final FriendshipService _friendshipService = FriendshipService();
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _jellyController;
  late AnimationController _staggerController;
  late Animation<double> _jellyX;
  late Animation<double> _jellyY;

  RealtimeChannel? _friendshipsChannel;
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults = [];
  List<FriendshipModel> _pendingRequests = [];
  bool _isSearching = false;
  bool _isLoadingPending = false;
  bool _madeChanges = false;
  int _activeTab = 0; // 0 = search, 1 = pending

  @override
  void initState() {
    super.initState();

    _jellyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _jellyX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 0.98), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.01), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.01, end: 0.995), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.995, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _jellyController,
      curve: Curves.easeOut,
    ));

    _jellyY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.02), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 0.99), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.99, end: 1.005), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.005, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _jellyController,
      curve: Curves.easeOut,
    ));

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    widget.animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _jellyController.forward();
        _staggerController.forward();
      }
    });

    if (widget.animation.isCompleted) {
      _jellyController.forward();
      _staggerController.forward();
    }

    _loadPendingRequests();
    _subscribeFriendshipsRealtime();
  }

  @override
  void dispose() {
    _friendshipsChannel?.unsubscribe();
    _jellyController.dispose();
    _staggerController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _subscribeFriendshipsRealtime() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _friendshipsChannel = _supabase
        .channel('add-friends-bubble-$uid')
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

  void _onFriendshipsChanged() {
    if (!mounted) return;
    _loadPendingRequests();
    final query = _searchController.text.trim();
    if (query.isNotEmpty) _searchUsers(query);
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

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchUsers(query.trim());
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
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
      _madeChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${context.tr('friend_request_sent_to')} $userName'),
        backgroundColor: Colors.green,
      ));
      _searchUsers(_searchController.text);
      _loadPendingRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('failed_to_send_friend_request')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _cancelRequest(String friendshipId) async {
    final success =
        await _friendshipService.cancelFriendRequest(friendshipId);
    if (!mounted) return;

    if (success) {
      _madeChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('friend_request_cancelled')),
      ));
      _loadPendingRequests();
    }
  }

  void _close() => Navigator.pop(context, _madeChanges);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final bubbleWidth = screenWidth * 0.9;
    final bubbleMaxHeight = screenHeight * 0.65;
    final bubbleRight = (screenWidth - bubbleWidth) / 2;
    final bubbleBottom = bottomPadding + 80.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: _close,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) => Container(
                color: Colors.black
                    .withValues(alpha: 0.4 * widget.animation.value),
              ),
            ),
          ),

          // Bubble
          Positioned(
            right: bubbleRight,
            bottom: bubbleBottom,
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([widget.animation, _jellyController]),
              builder: (context, child) {
                final curved = CurvedAnimation(
                  parent: widget.animation,
                  curve: Curves.easeOutBack,
                );
                final scaleX = curved.value *
                    (_jellyController.isAnimating ? _jellyX.value : 1.0);
                final scaleY = curved.value *
                    (_jellyController.isAnimating ? _jellyY.value : 1.0);

                return Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
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
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, -4),
                    ),
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(colorScheme),
                      _buildSearchBar(colorScheme),
                      _buildTabs(colorScheme),
                      Flexible(
                        child: _activeTab == 0
                            ? _buildSearchResults(colorScheme)
                            : _buildPendingList(colorScheme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
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
                    Colors.green[600]!,
                    Colors.green[400]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('add_friends'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    )),
                const SizedBox(height: 2),
                Text(
                  _pendingRequests.isNotEmpty
                      ? '${_pendingRequests.length} pending'
                      : 'Search for people',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
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

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: context.tr('search_users'),
          hintStyle: TextStyle(fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          filled: true,
          fillColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildTabs(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _buildTab(
            label: context.tr('search_results'),
            isActive: _activeTab == 0,
            colorScheme: colorScheme,
            onTap: () {
              setState(() => _activeTab = 0);
              _staggerController.forward(from: 0);
            },
          ),
          const SizedBox(width: 8),
          _buildTab(
            label: context.tr('pending_requests'),
            isActive: _activeTab == 1,
            count: _pendingRequests.length,
            colorScheme: colorScheme,
            onTap: () {
              setState(() => _activeTab = 1);
              _staggerController.forward(from: 0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    int count = 0,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(ColorScheme colorScheme) {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded,
                size: 44,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Text(
              _searchController.text.isEmpty
                  ? context.tr('start_typing_to_search')
                  : context.tr('no_users_found'),
              style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final delay = (index * 0.1).clamp(0.0, 0.5);
        final end = (delay + 0.5).clamp(0.0, 1.0);
        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final progress =
                Interval(delay, end, curve: Curves.easeOutCubic)
                    .transform(_staggerController.value);
            return Transform.translate(
              offset: Offset(0, 15 * (1 - progress)),
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: _buildUserTile(_searchResults[index], colorScheme),
        );
      },
    );
  }

  Widget _buildUserTile(
      Map<String, dynamic> user, ColorScheme colorScheme) {
    final userId = user['id'] as String;
    final fullName = user['full_name'] as String? ?? 'Unknown';
    final avatarUrl = user['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _sendFriendRequest(userId, fullName),
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.green.withValues(alpha: 0.08),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(fullName[0].toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded,
                          size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(context.tr('add'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList(ColorScheme colorScheme) {
    if (_isLoadingPending) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_pendingRequests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending_actions_rounded,
                size: 44,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Text(
              context.tr('no_pending_requests'),
              style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final delay = (index * 0.1).clamp(0.0, 0.5);
        final end = (delay + 0.5).clamp(0.0, 1.0);
        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final progress =
                Interval(delay, end, curve: Curves.easeOutCubic)
                    .transform(_staggerController.value);
            return Transform.translate(
              offset: Offset(0, 15 * (1 - progress)),
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child:
              _buildPendingTile(_pendingRequests[index], colorScheme),
        );
      },
    );
  }

  Widget _buildPendingTile(
      FriendshipModel request, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
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
                          fontSize: 15,
                        ))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.otherUserName ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(context.tr('pending'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _cancelRequest(request.id),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 14, color: colorScheme.error),
                      const SizedBox(width: 4),
                      Text(context.tr('cancel'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.error,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}