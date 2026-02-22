import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post_model.dart';
import '../../services/feed_service.dart';
import '../../services/friendship_service.dart';
import 'post_detail_screen.dart';

/// Ecran cu postările unui user + header profil + friend request
class UserPostsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  final FeedService _feedService = FeedService();
  final FriendshipService _friendshipService = FriendshipService();

  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Relationship
  String _relationshipStatus = 'none'; // friend, blocked, blocked_by, none, pending
  bool _isRelationshipLoading = true;

  // Profile data
  String? _bio;
  String? _avatarUrl;
  String _fullName = '';

  bool get _isMe =>
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fullName = widget.userName;
    _avatarUrl = widget.userAvatar;
    _loadAll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadRelationship(),
      _loadPosts(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url, bio')
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _fullName = profile['full_name'] as String? ?? widget.userName;
          _avatarUrl = profile['avatar_url'] as String? ?? widget.userAvatar;
          _bio = profile['bio'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRelationship() async {
    if (_isMe) {
      if (mounted) setState(() => _isRelationshipLoading = false);
      return;
    }

    try {
      final status =
          await _friendshipService.getRelationshipStatus(widget.userId);

      // Also check for pending friend request
      if (status == 'none') {
        final currentUserId =
            Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          final pending = await Supabase.instance.client
              .from('friendships')
              .select('id')
              .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)')
              .eq('status', 'pending')
              .maybeSingle();

          if (pending != null && mounted) {
            setState(() {
              _relationshipStatus = 'pending';
              _isRelationshipLoading = false;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _relationshipStatus = status;
          _isRelationshipLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRelationshipLoading = false);
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts =
        await _feedService.getUserPosts(widget.userId, limit: 20, offset: 0);
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
        _hasMore = posts.length >= 20;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final morePosts = await _feedService.getUserPosts(
      widget.userId,
      limit: 20,
      offset: _posts.length,
    );

    if (mounted) {
      setState(() {
        _posts.addAll(morePosts);
        _isLoadingMore = false;
        _hasMore = morePosts.length >= 20;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    final success = await _friendshipService.sendFriendRequest(widget.userId);
    if (success && mounted) {
      setState(() => _relationshipStatus = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !post.isLikedByMe,
        likeCount:
            post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
      );
    });

    final success = await _feedService.toggleLike(post.id);
    if (!success && mounted) {
      setState(() => _posts[index] = post);
    }
  }

  void _openPostDetail(int index) async {
    final result = await Navigator.push<PostModel?>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: _posts[index]),
      ),
    );
    if (result != null && mounted) {
      setState(() => _posts[index] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showFullProfile = _isMe || _relationshipStatus == 'friend';

    return Scaffold(
      appBar: AppBar(title: Text(_fullName)),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Profile header
            SliverToBoxAdapter(
              child: _buildProfileHeader(colorScheme, showFullProfile),
            ),

            // Divider
            SliverToBoxAdapter(
              child: Divider(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  height: 1),
            ),

            // Posts
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 60,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return _buildPostCard(index, colorScheme);
                  },
                  childCount:
                      _posts.length + (_isLoadingMore ? 1 : 0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme, bool showFullProfile) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: showFullProfile
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            backgroundImage: showFullProfile && _avatarUrl != null
                ? NetworkImage(_avatarUrl!)
                : null,
            child: showFullProfile && _avatarUrl == null
                ? Text(
                    _fullName[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : !showFullProfile
                    ? Icon(Icons.person,
                        size: 44,
                        color: colorScheme.onSurface.withValues(alpha: 0.3))
                    : null,
          ),
          const SizedBox(height: 12),

          // Nume
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Bio
          if (showFullProfile && _bio != null && _bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],

          // Relationship button
          if (!_isMe && !_isRelationshipLoading) ...[
            const SizedBox(height: 16),
            _buildRelationshipButton(colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildRelationshipButton(ColorScheme colorScheme) {
    switch (_relationshipStatus) {
      case 'friend':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Friends',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );

      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 6),
              Text(
                'Request sent',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );

      case 'blocked':
      case 'blocked_by':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 16, color: colorScheme.error),
              const SizedBox(width: 6),
              Text(
                'Blocked',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );

      case 'none':
      default:
        return FilledButton.icon(
          onPressed: _sendFriendRequest,
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add Friend'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
    }
  }

  Widget _buildPostCard(int index, ColorScheme colorScheme) {
    final post = _posts[index];
    final currentUserId = _feedService.currentUserId;

    return Container(
      margin: const EdgeInsets.only(top: 0.5),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                post.content,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          // Timp + visibility
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Text(
                  timeago.format(post.createdAt),
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  post.visibility == 'friends'
                      ? Icons.people_outline
                      : Icons.public,
                  size: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          // Imagine
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(height: 0),
                ),
              ),
            ),
          ],

          // Counts
          if (post.likeCount > 0 || post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  if (post.likeCount > 0) ...[
                    Icon(Icons.favorite, size: 15, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likeCount}',
                      style: TextStyle(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (post.likeCount > 0 && post.commentCount > 0)
                    const Spacer(),
                  if (post.commentCount > 0)
                    Text(
                      '${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

          Divider(
            indent: 16,
            endIndent: 16,
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _toggleLike(index),
                  icon: Icon(
                    post.isLikedByMe
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 19,
                    color: post.isLikedByMe
                        ? Colors.red[400]
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  label: Text(
                    'Like',
                    style: TextStyle(
                      color: post.isLikedByMe
                          ? Colors.red[400]
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openPostDetail(index),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 19,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  label: Text(
                    'Comment',
                    style: TextStyle(
                      color:
                          colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              // Delete (doar dacă e al meu)
              if (post.userId == currentUserId)
                IconButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete post?'),
                        content:
                            const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Delete',
                                style: TextStyle(
                                    color: colorScheme.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final success =
                          await _feedService.deletePost(post.id);
                      if (success && mounted) {
                        setState(() => _posts.removeAt(index));
                      }
                    }
                  },
                  icon: Icon(Icons.delete_outline,
                      size: 19,
                      color: colorScheme.onSurface.withValues(alpha: 0.3)),
                ),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}
