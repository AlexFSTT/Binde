import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/video_model.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _showControls = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );

      await _controller.initialize();
      
      setState(() {
        _isInitialized = true;
      });

      // Auto-hide controls after 3 seconds
      _controller.addListener(() {
        if (_controller.value.isPlaying && _showControls) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _controller.value.isPlaying) {
              setState(() => _showControls = false);
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Nu s-a putut încărca video-ul: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.video.title,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Distribuire - în curând!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Player video
          Expanded(
            flex: 2,
            child: _buildVideoPlayer(colorScheme),
          ),

          // Informații video
          Expanded(
            flex: 1,
            child: _buildVideoInfo(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(ColorScheme colorScheme) {
    // Eroare
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _error = null);
                  _initializeVideo();
                },
                child: const Text('Încearcă din nou'),
              ),
            ],
          ),
        ),
      );
    }

    // Loading
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Se încarcă video-ul...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // Player real
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),

          // Overlay cu controale
          if (_showControls)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause button
                  IconButton(
                    iconSize: 80,
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                ],
              ),
            ),

          // Progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _showControls
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Row(
                      children: [
                        // Timp curent
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) {
                            return Text(
                              _formatDuration(value.position),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),

                        // Progress slider
                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: _controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return Slider(
                                value: value.position.inMilliseconds.toDouble(),
                                min: 0,
                                max: value.duration.inMilliseconds.toDouble(),
                                activeColor: colorScheme.primary,
                                inactiveColor: Colors.white30,
                                onChanged: (newValue) {
                                  _controller.seekTo(Duration(milliseconds: newValue.toInt()));
                                },
                              );
                            },
                          ),
                        ),

                        // Durată totală
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: colorScheme.primary,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white10,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titlu
            Text(
              widget.video.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            // Statistici și acțiuni
            Row(
              children: [
                // Vizualizări
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.video.formattedViews} vizualizări',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),

                const Spacer(),

                // Like button
                IconButton(
                  onPressed: () {
                    setState(() => _isLiked = !_isLiked);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isLiked ? 'Ți-a plăcut!' : 'Like eliminat'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : colorScheme.onSurface,
                  ),
                ),
                Text(widget.video.formattedLikes),

                const SizedBox(width: 16),

                // Share button
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.share_outlined,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Categorie
            if (widget.video.category != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.video.category!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Durată: ${widget.video.formattedDuration}',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Descriere
            if (widget.video.description != null)
              Text(
                widget.video.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}