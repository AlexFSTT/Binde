import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/swirl_model.dart';
import '../../models/swirl_comment_model.dart';
import '../../services/swirls_service.dart';

/// Player pentru Swirl cu like animation FIXATĂ
class SwirlsPlayerScreen extends StatefulWidget {
  final Swirl swirl;
  final bool isActive;

  const SwirlsPlayerScreen({
    super.key,
    required this.swirl,
    required this.isActive,
  });

  @override
  State<SwirlsPlayerScreen> createState() => _SwirlsPlayerScreenState();
}

class _SwirlsPlayerScreenState extends State<SwirlsPlayerScreen> with SingleTickerProviderStateMixin {
  final SwirlsService _swirlsService = SwirlsService();
  late VideoPlayerController _controller;
  late AnimationController _likeAnimationController;
  bool _isInitialized = false;
  bool _showUI = true;
  bool _isLiked = false;
  bool _isMuted = false;
  bool _isTogglingLike = false;
  int _likesCount = 0;
  bool _hasIncrementedViews = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.swirl.likesCount;
    
    // ✅ Animation controller pentru like
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _initializeVideo();
    _checkLikeStatus();
  }

  @override
  void didUpdateWidget(SwirlsPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-play/pause când isActive se schimbă
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.play();
        // Incrementează views doar o dată
        if (!_hasIncrementedViews) {
          _swirlsService.incrementViews(widget.swirl.id);
          _hasIncrementedViews = true;
        }
      } else {
        _controller.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.swirl.videoUrl),
    );

    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });

      // ✅ NU pornește automat - așteaptă ca isActive să fie true
      // Doar dacă e deja activ de la început
      if (widget.isActive && mounted) {
        _controller.play();
        if (!_hasIncrementedViews) {
          _swirlsService.incrementViews(widget.swirl.id);
          _hasIncrementedViews = true;
        }
      }

      _controller.setLooping(true);
      _hideUIAfterDelay();
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _hideUIAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showUI && _controller.value.isPlaying) {
        setState(() {
          _showUI = false;
        });
      }
    });
  }

  Future<void> _checkLikeStatus() async {
    try {
      final hasLiked = await _swirlsService.hasUserLikedSwirl(widget.swirl.id);
      if (mounted) {
        setState(() {
          _isLiked = hasLiked;
        });
      }
    } catch (e) {
      debugPrint('Error checking like status: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showUI = true;
      } else {
        _controller.play();
        _hideUIAfterDelay();
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_isTogglingLike) return;

    setState(() {
      _isTogglingLike = true;
    });

    try {
      final newLikeStatus = await _swirlsService.toggleLike(widget.swirl.id);
      
      setState(() {
        _isLiked = newLikeStatus;
        _likesCount = newLikeStatus ? _likesCount + 1 : _likesCount - 1;
      });
      
      // ✅ FIX: Animație DOAR când DAI like (newLikeStatus == true)
      if (newLikeStatus) {
        _likeAnimationController.forward(from: 0.0);
      }
      
    } catch (e) {
      debugPrint('Error toggling like: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('logged in') 
                ? 'Please log in to like' 
                : 'Failed to like'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isTogglingLike = false;
      });
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(
        swirl: widget.swirl,
        swirlsService: _swirlsService,
      ),
    );
  }

  Future<void> _shareSwirl() async {
    try {
      final shareLink = _swirlsService.generateShareLink(widget.swirl.id);
      final shareText = '${widget.swirl.title}\n\nWatch on Binde: $shareLink';
      
      await Share.share(
        shareText,
        subject: widget.swirl.title,
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  String _formatLikes(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildVideoPlayer(),

          GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTap: _toggleLike,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          // ✅ Play/Pause icon
          if (!_controller.value.isPlaying && _isInitialized)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

          if (_showUI || !_controller.value.isPlaying) ...[
            _buildProgressBar(),
            _buildUserInfo(),
            _buildActionButtons(),
            _buildMuteButton(),
          ],

          // ✅ LIKE ANIMATION - folosește AnimationController
          AnimatedBuilder(
            animation: _likeAnimationController,
            builder: (context, child) {
              if (_likeAnimationController.value == 0.0) {
                return const SizedBox.shrink();
              }
              
              return Center(
                child: Transform.scale(
                  scale: 1.0 + (_likeAnimationController.value * 0.5), // Crește de la 1.0 la 1.5
                  child: Opacity(
                    opacity: 1.0 - _likeAnimationController.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: VideoProgressIndicator(
        _controller,
        allowScrubbing: true,
        colors: VideoProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.white.withValues(alpha: 0.3),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Positioned(
      left: 16,
      bottom: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: widget.swirl.userAvatar != null
                ? NetworkImage(widget.swirl.userAvatar!)
                : null,
            child: widget.swirl.userAvatar == null
                ? const Icon(Icons.person, size: 24)
                : null,
          ),
          const SizedBox(height: 12),
          
          Text(
            '@${widget.swirl.username}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 8),
          
          if (widget.swirl.title.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                widget.swirl.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              const Icon(Icons.play_circle_outline, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.swirl.formattedViews,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      right: 16,
      bottom: 80,
      child: Column(
        children: [
          _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatLikes(_likesCount),
            onTap: _toggleLike,
            color: _isLiked ? Colors.red : Colors.white,
          ),
          const SizedBox(height: 24),
          
          _buildActionButton(
            icon: Icons.comment_outlined,
            label: 'Comment',
            onTap: _openComments,
          ),
          const SizedBox(height: 24),
          
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: _shareSwirl,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: color ?? Colors.white),
            iconSize: 32,
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ],
    );
  }

  Widget _buildMuteButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: IconButton(
          icon: Icon(
            _isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          ),
          onPressed: _toggleMute,
        ),
      ),
    );
  }
}

// Comments Bottom Sheet - PĂSTRAT IDENTIC
class _CommentsBottomSheet extends StatefulWidget {
  final Swirl swirl;
  final SwirlsService swirlsService;

  const _CommentsBottomSheet({
    required this.swirl,
    required this.swirlsService,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  List<SwirlComment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    try {
      final comments = await widget.swirlsService.getComments(widget.swirl.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final newComment = await widget.swirlsService.addComment(widget.swirl.id, text);
      
      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
        _isSubmitting = false;
      });

      _commentFocusNode.unfocus();
    } catch (e) {
      setState(() => _isSubmitting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('logged in')
                ? 'Please log in to comment'
                : 'Failed to post comment'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(SwirlComment comment) async {
    try {
      await widget.swirlsService.deleteComment(comment.id, comment.userId);
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Text('No comments yet\nBe the first!', textAlign: TextAlign.center))
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) => _buildComment(_comments[index]),
                          ),
              ),
              
              _buildCommentInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComment(SwirlComment comment) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == comment.userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment.userAvatar != null
                ? NetworkImage(comment.userAvatar!)
                : null,
            child: comment.userAvatar == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('@${comment.username}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(comment.timeAgo, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.text, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.grey,
              onPressed: () => _deleteComment(comment),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: InputDecoration(
                hintText: 'Add comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              enabled: !_isSubmitting,
            ),
          ),
          const SizedBox(width: 8),
          
          IconButton(
            icon: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            onPressed: _isSubmitting ? null : _submitComment,
          ),
        ],
      ),
    );
  }
}
