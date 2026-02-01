import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';

/// Individual Swirls video item with fullscreen player and TikTok-style UI
class SwirlsVideoItem extends StatefulWidget {
  final Video video;
  final bool isActive;

  const SwirlsVideoItem({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<SwirlsVideoItem> createState() => _SwirlsVideoItemState();
}

class _SwirlsVideoItemState extends State<SwirlsVideoItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isMuted = false;
  bool _showUI = true;
  String? _error;

  // Like animation
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  bool _showLikeAnimation = false;

  @override
  void initState() {
    super.initState();
    
    // Like animation setup
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    if (widget.isActive) {
      _initializeAndPlay();
    }
  }

  @override
  void didUpdateWidget(SwirlsVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      // Video became active - play it
      _initializeAndPlay();
    } else if (!widget.isActive && oldWidget.isActive) {
      // Video became inactive - pause it
      _controller?.pause();
    }
  }

  Future<void> _initializeAndPlay() async {
    if (_controller != null && _isInitialized) {
      _controller!.play();
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );

      await _controller!.initialize();
      
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      _controller!.setLooping(true);
      _controller!.play();

      // Auto-hide UI after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showUI && _controller!.value.isPlaying) {
          setState(() => _showUI = false);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Video error: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showUI = true;
    });

    // Auto-hide UI
    if (_controller!.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller!.value.isPlaying) {
          setState(() => _showUI = false);
        }
      });
    }
  }

  void _handleDoubleTap() {
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        _showLikeAnimation = true;
      });

      _likeAnimationController.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _showLikeAnimation = false);
          }
        });
      });
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        _buildVideoPlayer(),

        // Error overlay
        if (_error != null) _buildErrorOverlay(),

        // Loading overlay
        if (!_isInitialized && _error == null) _buildLoadingOverlay(),

        // Interactive overlay
        if (_isInitialized && _error == null) ...[
          // Tap to pause/play or show/hide UI
          GestureDetector(
            onTap: () {
              setState(() => _showUI = !_showUI);
            },
            onDoubleTap: _handleDoubleTap,
            child: Container(color: Colors.transparent),
          ),

          // Play/Pause button (center, when paused)
          if (!_controller!.value.isPlaying)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Like animation (center, double tap)
          if (_showLikeAnimation)
            Center(
              child: ScaleTransition(
                scale: _likeAnimation,
                child: Icon(
                  Icons.favorite,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),

          // Right side UI (TikTok style)
          _buildRightSideUI(),

          // Bottom info overlay
          _buildBottomInfo(),

          // Top progress indicator
          if (_showUI) _buildProgressIndicator(),

          // Mute button (top right)
          _buildMuteButton(),
        ],
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_isInitialized) {
      return Container(color: Colors.black);
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error loading video',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSideUI() {
    return Positioned(
      right: 12,
      bottom: 100,
      child: Column(
        children: [
          // Like button
          _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: widget.video.formattedLikes,
            color: _isLiked ? Colors.red : Colors.white,
            onTap: _toggleLike,
          ),
          
          const SizedBox(height: 24),

          // Comment button
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Comments',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Comments - Coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Share button
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share - Coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      left: 12,
      right: 80,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username/Creator
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: const Icon(
                  Icons.person,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '@creator',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),

          // Video title
          Text(
            widget.video.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Views count
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.video.formattedViews} views',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_controller == null) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder(
        valueListenable: _controller!,
        builder: (context, VideoPlayerValue value, child) {
          final progress = value.duration.inMilliseconds > 0
              ? value.position.inMilliseconds / value.duration.inMilliseconds
              : 0.0;
          
          return LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            minHeight: 2,
          );
        },
      ),
    );
  }

  Widget _buildMuteButton() {
    return Positioned(
      top: 60,
      right: 12,
      child: GestureDetector(
        onTap: _toggleMute,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}