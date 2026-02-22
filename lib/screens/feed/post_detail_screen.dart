import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post_model.dart';
import '../../services/feed_service.dart';
import 'user_posts_screen.dart';

/// Ecran detaliu postare cu comentarii
class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  late PostModel _post;
  List<CommentModel> _comments = [];
  bool _isLoadingComments = true;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    final comments = await _feedService.getComments(_post.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
        _post = _post.copyWith(commentCount: comments.length);
      });
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _post = _post.copyWith(
        isLikedByMe: !_post.isLikedByMe,
        likeCount: _post.isLikedByMe
            ? _post.likeCount - 1
            : _post.likeCount + 1,
      );
    });

    final success = await _feedService.toggleLike(_post.id);
    if (!success && mounted) {
      setState(() => _post = widget.post);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);

    final comment = await _feedService.addComment(_post.id, text);

    if (mounted) {
      setState(() => _isSendingComment = false);

      if (comment != null) {
        _commentController.clear();
        _commentFocus.unfocus();
        setState(() {
          _comments.add(comment);
          _post = _post.copyWith(commentCount: _comments.length);
        });
      }
    }
  }

  Future<void> _deleteComment(int index) async {
    final comment = _comments[index];
    final success = await _feedService.deleteComment(comment.id);
    if (success && mounted) {
      setState(() {
        _comments.removeAt(index);
        _post = _post.copyWith(commentCount: _comments.length);
      });
    }
  }

  void _openUserPosts(String userId, String? userName, String? userAvatar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPostsScreen(
          userId: userId,
          userName: userName ?? 'User',
          userAvatar: userAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _feedService.currentUserId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _post);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // Post content
                  _buildPostContent(colorScheme),

                  Divider(color: colorScheme.outline.withValues(alpha: 0.1)),

                  // Comments header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),

                  // Comments list
                  if (_isLoadingComments)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_comments.length, (index) {
                      final comment = _comments[index];
                      return _buildCommentItem(
                        comment,
                        colorScheme,
                        canDelete: comment.userId == currentUserId,
                        onDelete: () => _deleteComment(index),
                      );
                    }),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Comment input
            _buildCommentInput(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openUserPosts(
                      _post.userId, _post.authorName, _post.authorAvatar),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: _post.authorAvatar != null
                        ? NetworkImage(_post.authorAvatar!)
                        : null,
                    child: _post.authorAvatar == null
                        ? Text(
                            (_post.authorName ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openUserPosts(
                        _post.userId, _post.authorName, _post.authorAvatar),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _post.authorName ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              timeago.format(_post.createdAt),
                              style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _post.visibility == 'friends'
                                  ? Icons.people_outline
                                  : Icons.public,
                              size: 13,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content text
          if (_post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _post.content,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),

          // Imagine
          if (_post.imageUrl != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Image.network(
                _post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(height: 0),
              ),
            ),
          ],

          // Like count + action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                if (_post.likeCount > 0) ...[
                  Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${_post.likeCount}',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${_post.commentCount} comment${_post.commentCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            indent: 16,
            endIndent: 16,
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),

          // Like button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton.icon(
              onPressed: _toggleLike,
              icon: Icon(
                _post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: _post.isLikedByMe
                    ? Colors.red[400]
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              label: Text(
                'Like',
                style: TextStyle(
                  color: _post.isLikedByMe
                      ? Colors.red[400]
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    CommentModel comment,
    ColorScheme colorScheme, {
    required bool canDelete,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openUserPosts(
                comment.userId, comment.authorName, comment.authorAvatar),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: comment.authorAvatar != null
                  ? NetworkImage(comment.authorAvatar!)
                  : null,
              child: comment.authorAvatar == null
                  ? Text(
                      (comment.authorName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.content,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    children: [
                      Text(
                        timeago.format(comment.createdAt),
                        style: TextStyle(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                      if (canDelete) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: onDelete,
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: colorScheme.error.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocus,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.35),
                  fontSize: 14,
                ),
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _isSendingComment ? null : _sendComment,
            icon: _isSendingComment
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colorScheme.primary),
                  )
                : Icon(Icons.send_rounded, color: colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
