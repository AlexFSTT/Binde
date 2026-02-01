import 'package:flutter/material.dart';
import '../../models/swirl_model.dart';
import '../../services/swirls_service.dart';

/// Player pentru un singur Swirl (TikTok-style)
class SwirlPlayerScreen extends StatefulWidget {
  final Swirl swirl;
  final bool isActive;

  const SwirlPlayerScreen({
    super.key,
    required this.swirl,
    this.isActive = true,
  });

  @override
  State<SwirlPlayerScreen> createState() => _SwirlPlayerScreenState();
}

class _SwirlPlayerScreenState extends State<SwirlPlayerScreen> {
  final SwirlsService _swirlsService = SwirlsService();
  bool _hasIncrementedViews = false;
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.swirl.likesCount;
    _incrementViews();
  }

  Future<void> _incrementViews() async {
    if (!_hasIncrementedViews) {
      await _swirlsService.incrementViews(widget.swirl.id);
      _hasIncrementedViews = true;
    }
  }

  Future<void> _toggleLike() async {
    if (!_isLiked) {
      await _swirlsService.incrementLikes(widget.swirl.id);
      setState(() {
        _isLiked = true;
        _likesCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player background (placeholder - replace with actual video player)
        _buildVideoBackground(),

        // Safe area for top content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Top bar (optional - can add categories, search, etc)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Swirls',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.white),
                  ],
                ),
                const Spacer(),
                // Bottom content
                _buildBottomContent(),
              ],
            ),
          ),
        ),

        // Right side action buttons (TikTok style)
        Positioned(
          bottom: 100,
          right: 12,
          child: _buildActionButtons(),
        ),
      ],
    );
  }

  Widget _buildVideoBackground() {
    // TODO: Replace with actual video player (video_player package)
    // For now, show thumbnail or black background
    if (widget.swirl.thumbnailUrl != null) {
      return Image.network(
        widget.swirl.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 100,
                color: Colors.white54,
              ),
            ),
          );
        },
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 100,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildBottomContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                widget.swirl.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              if (widget.swirl.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.swirl.description!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Stats
              Row(
                children: [
                  const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.swirl.formattedViews,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.swirl.formattedDuration,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 60), // Space for action buttons
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button
        _buildActionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(_likesCount),
          onTap: _toggleLike,
          color: _isLiked ? Colors.red : Colors.white,
        ),
        const SizedBox(height: 24),
        
        // Comment button
        _buildActionButton(
          icon: Icons.comment,
          label: '0',
          onTap: () {
            // TODO: Open comments
          },
        ),
        const SizedBox(height: 24),
        
        // Share button
        _buildActionButton(
          icon: Icons.share,
          label: 'Share',
          onTap: () {
            // TODO: Share functionality
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 32),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
