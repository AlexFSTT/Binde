import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post_model.dart';
import '../../services/feed_service.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'user_posts_screen.dart';
import '../../l10n/app_localizations.dart';

/// Ecranul principal de Feed (Facebook-like)
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();

  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
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

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await _feedService.getFeedPosts(limit: 20, offset: 0);
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

    final morePosts = await _feedService.getFeedPosts(
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

  Future<void> _onRefresh() async {
    final posts = await _feedService.getFeedPosts(limit: 20, offset: 0);
    if (mounted) {
      setState(() {
        _posts = posts;
        _hasMore = posts.length >= 20;
      });
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    // Optimistic update
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !post.isLikedByMe,
        likeCount: post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
      );
    });

    final success = await _feedService.toggleLike(post.id);
    if (!success && mounted) {
      // Revert
      setState(() {
        _posts[index] = post;
      });
    }
  }

  Future<void> _deletePost(int index) async {
    final post = _posts[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_post_confirm')),
        content: Text(context.tr('action_cannot_undo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('delete'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _feedService.deletePost(post.id);
      if (success && mounted) {
        setState(() => _posts.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('post_deleted'))),
          );
        }
      }
    }
  }

  void _openCreatePost() async {
    final newPost = await Navigator.push<PostModel>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (newPost != null && mounted) {
      setState(() => _posts.insert(0, newPost));
    }
  }

  void _openPostDetail(int index) async {
    final result = await Navigator.push<PostModel?>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: _posts[index]),
      ),
    );
    // Refresh post data dacă s-a schimbat (like/comment)
    if (result != null && mounted) {
      setState(() => _posts[index] = result);
    }
  }

  void _openUserPosts(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPostsScreen(
          userId: post.userId,
          userName: post.authorName ?? 'User',
          userAvatar: post.authorAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Binde',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _openCreatePost,
            tooltip: context.tr('new_post'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmptyState(colorScheme)
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return _PostCard(
                        post: _posts[index],
                        onLike: () => _toggleLike(index),
                        onComment: () => _openPostDetail(index),
                        onDelete: _posts[index].userId ==
                                _feedService.currentUserId
                            ? () => _deletePost(index)
                            : null,
                        onTapUser: () => _openUserPosts(_posts[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_outlined,
              size: 80, color: colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openCreatePost,
            icon: const Icon(Icons.edit, size: 18),
            label: Text(context.tr('create_post')),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// POST CARD WIDGET
// =====================================================

class _PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onDelete;
  final VoidCallback onTapUser;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    this.onDelete,
    required this.onTapUser,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0.5),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + nume + timp + menu
          _buildHeader(context, colorScheme),

          // Content text
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                post.content,
                style: const TextStyle(fontSize: 15, height: 1.4),
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
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Like/Comment counts
          _buildCounts(colorScheme),

          // Divider
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),

          // Action buttons
          _buildActions(colorScheme),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: onTapUser,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: post.authorAvatar != null
                  ? NetworkImage(post.authorAvatar!)
                  : null,
              child: post.authorAvatar == null
                  ? Text(
                      (post.authorName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // Nume + timp + visibility
          Expanded(
            child: GestureDetector(
              onTap: onTapUser,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        timeago.format(post.createdAt),
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        post.visibility == 'friends'
                            ? Icons.people_outline
                            : Icons.public,
                        size: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Menu (delete dacă e al meu)
          if (onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz,
                  color: colorScheme.onSurface.withValues(alpha: 0.5)),
              onSelected: (value) {
                if (value == 'delete') onDelete!();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Text(context.tr('delete_post'),
                          style: TextStyle(color: colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCounts(ColorScheme colorScheme) {
    if (post.likeCount == 0 && post.commentCount == 0) {
      return const SizedBox(height: 10);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          if (post.likeCount > 0) ...[
            Icon(Icons.favorite, size: 16, color: Colors.red[400]),
            const SizedBox(width: 4),
            Text(
              '${post.likeCount}',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
          if (post.likeCount > 0 && post.commentCount > 0)
            const Spacer(),
          if (post.commentCount > 0)
            Text(
              '${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Like
          Expanded(
            child: TextButton.icon(
              onPressed: onLike,
              icon: Icon(
                post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                size: 20,
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // Comment
          Expanded(
            child: TextButton.icon(
              onPressed: onComment,
              icon: Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              label: Text(
                'Comment',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}