import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post_model.dart';
import '../../services/feed_service.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'user_posts_screen.dart';
import '../../l10n/app_localizations.dart';

/// Ecranul principal de Feed — card-based cu reactions & shares
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

  Future<void> _setReaction(int index, String reactionType) async {
    final post = _posts[index];
    final oldReaction = post.myReaction;
    final isRemove = oldReaction == reactionType;

    // Optimistic update
    final newCounts = Map<String, int>.from(post.reactionCounts);
    if (oldReaction != null) {
      newCounts[oldReaction] = (newCounts[oldReaction] ?? 1) - 1;
      if (newCounts[oldReaction]! <= 0) newCounts.remove(oldReaction);
    }
    if (!isRemove) {
      newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;
    }
    final newTotal = newCounts.values.fold(0, (a, b) => a + b);

    setState(() {
      _posts[index] = post.copyWith(
        myReaction: isRemove ? null : reactionType,
        clearMyReaction: isRemove,
        reactionCounts: newCounts,
        totalReactions: newTotal,
      );
    });

    await _feedService.setReaction(post.id, reactionType);
  }

  Future<void> _toggleShare(int index) async {
    final post = _posts[index];
    final wasShared = post.isSharedByMe;

    setState(() {
      _posts[index] = post.copyWith(
        isSharedByMe: !wasShared,
        shareCount: wasShared ? post.shareCount - 1 : post.shareCount + 1,
      );
    });

    // Also trigger system share
    if (!wasShared) {
      await SharePlus.instance.share(
        ShareParams(
          text: '${post.authorName ?? "Someone"}: ${post.content}',
          title: 'Binde Post',
        ),
      );
    }

    await _feedService.toggleShare(post.id);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('post_deleted'))),
        );
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
    final cs = Theme.of(context).colorScheme;

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
              ? _buildEmptyState(cs)
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 16, bottom: 80),
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
                        onReact: (type) => _setReaction(index, type),
                        onComment: () => _openPostDetail(index),
                        onShare: () => _toggleShare(index),
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

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_outlined,
              size: 80, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            context.tr('no_posts_yet'),
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurface.withValues(alpha: 0.5),
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

// =============================================================
// POST CARD — Card-based cu avatar 30% outside
// =============================================================
class _PostCard extends StatefulWidget {
  final PostModel post;
  final Function(String) onReact;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  final VoidCallback onTapUser;

  const _PostCard({
    required this.post,
    required this.onReact,
    required this.onComment,
    required this.onShare,
    this.onDelete,
    required this.onTapUser,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  OverlayEntry? _overlayEntry;

  void _showReactions(BuildContext btnContext) {
    final RenderBox box = btnContext.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);
    final cs = Theme.of(context).colorScheme;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Dismiss layer
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideReactions,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Reaction picker bubble
          Positioned(
            left: position.dx - 20,
            top: position.dy - 56,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(28),
              color: cs.surface,
              surfaceTintColor: cs.surfaceTint,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ReactionType.all.map((type) {
                    final isSelected = widget.post.myReaction == type;
                    return GestureDetector(
                      onTap: () {
                        _hideReactions();
                        widget.onReact(type);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer.withValues(alpha: 0.5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ReactionType.emoji(type),
                          style: TextStyle(fontSize: isSelected ? 28 : 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideReactions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideReactions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double avatarRadius = 20;
    const double borderWidth = 3;
    const double avatarOverlap = avatarRadius * 0.6; // 30% of diameter = 60% of radius

    return Padding(
      padding: EdgeInsets.fromLTRB(12, avatarOverlap, 12, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The card body
          Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (name + time) — indented for avatar space
                _buildHeader(cs),

                // Content text
                if (widget.post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      widget.post.content,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),

                // Image
                if (widget.post.imageUrl != null)
                  _buildImage(cs),

                // Reaction counts row
                _buildReactionSummary(cs),

                // Divider
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withValues(alpha: 0.1),
                ),

                // Action buttons
                _buildActions(cs),

                const SizedBox(height: 4),
              ],
            ),
          ),

          // Avatar — positioned to overlap card top
          Positioned(
            top: -avatarOverlap,
            left: 12,
            child: GestureDetector(
              onTap: widget.onTapUser,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.surface,
                    width: borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: widget.post.authorAvatar != null
                      ? NetworkImage(widget.post.authorAvatar!)
                      : null,
                  child: widget.post.authorAvatar == null
                      ? Text(
                          (widget.post.authorName ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onTapUser,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.authorName ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        timeago.format(widget.post.createdAt),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        widget.post.visibility == 'friends'
                            ? Icons.people_outline
                            : Icons.public,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz,
                  color: cs.onSurface.withValues(alpha: 0.5), size: 20),
              onSelected: (value) {
                if (value == 'delete') widget.onDelete!();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: cs.error, size: 20),
                      const SizedBox(width: 12),
                      Text(ctx.tr('delete_post'),
                          style: TextStyle(color: cs.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImage(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SizedBox(
          width: double.infinity,
          child: ClipRRect(
            child: Image.network(
              widget.post.imageUrl!,
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
                      color: cs.onSurface.withValues(alpha: 0.2)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionSummary(ColorScheme cs) {
    final post = widget.post;
    if (post.totalReactions == 0 && post.commentCount == 0 && post.shareCount == 0) {
      return const SizedBox(height: 8);
    }

    // Build emoji summary (top 3 reactions)
    final sortedReactions = post.reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEmojis = sortedReactions
        .take(3)
        .map((e) => ReactionType.emoji(e.key))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (post.totalReactions > 0) ...[
            // Stacked emoji badges
            SizedBox(
              width: topEmojis.length * 18.0 + 4,
              height: 22,
              child: Stack(
                children: topEmojis.asMap().entries.map((entry) {
                  return Positioned(
                    left: entry.key * 14.0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${post.totalReactions}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
          const Spacer(),
          if (post.commentCount > 0)
            Text(
              '${post.commentCount} ${post.commentCount == 1 ? context.tr('comment_singular') : context.tr('comment_plural')}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          if (post.commentCount > 0 && post.shareCount > 0)
            Text(
              '  ·  ',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3)),
            ),
          if (post.shareCount > 0)
            Text(
              '${post.shareCount} ${context.tr('shares')}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme cs) {
    final post = widget.post;
    final hasReaction = post.myReaction != null;
    final reactionEmoji = hasReaction ? ReactionType.emoji(post.myReaction!) : null;
    final reactionLabel = hasReaction ? ReactionType.label(post.myReaction!) : context.tr('like');
    final reactionColor = hasReaction
        ? _getReactionColor(post.myReaction!)
        : cs.onSurface.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // React button (tap = quick like, long press = picker)
          Expanded(
            child: Builder(
              builder: (btnContext) => GestureDetector(
                onLongPress: () => _showReactions(btnContext),
                child: TextButton.icon(
                  onPressed: () => widget.onReact(post.myReaction ?? 'like'),
                  icon: hasReaction
                      ? Text(reactionEmoji!, style: const TextStyle(fontSize: 18))
                      : Icon(Icons.thumb_up_outlined, size: 19, color: reactionColor),
                  label: Text(
                    reactionLabel,
                    style: TextStyle(color: reactionColor, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
          ),
          // Comment
          Expanded(
            child: TextButton.icon(
              onPressed: widget.onComment,
              icon: Icon(
                Icons.chat_bubble_outline,
                size: 19,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              label: Text(
                context.tr('comment'),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // Share
          Expanded(
            child: TextButton.icon(
              onPressed: widget.onShare,
              icon: Icon(
                post.isSharedByMe ? Icons.share : Icons.share_outlined,
                size: 19,
                color: post.isSharedByMe
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.5),
              ),
              label: Text(
                context.tr('share'),
                style: TextStyle(
                  color: post.isSharedByMe
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.5),
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

  Color _getReactionColor(String type) {
    switch (type) {
      case 'like': return Colors.blue;
      case 'heart': return Colors.red;
      case 'haha': return Colors.amber.shade700;
      case 'sad': return Colors.amber.shade700;
      case 'angry': return Colors.orange.shade800;
      default: return Colors.blue;
    }
  }
}