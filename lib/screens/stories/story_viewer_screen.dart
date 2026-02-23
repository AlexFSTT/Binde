import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/story_model.dart';
import '../../services/story_service.dart';

/// Full-screen story viewer — Instagram style
class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> storyGroups;
  final int initialGroupIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    required this.initialGroupIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final StoryService _storyService = StoryService();

  late PageController _pageController;
  late int _currentGroupIndex;
  int _currentStoryIndex = 0;

  // Per-story animation
  Timer? _timer;
  double _progress = 0;
  static const _imageDuration = Duration(seconds: 5);
  static const _tickInterval = Duration(milliseconds: 50);

  VideoPlayerController? _videoController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _pageController = PageController(initialPage: _currentGroupIndex);
    _startStory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  StoryGroup get _currentGroup => widget.storyGroups[_currentGroupIndex];
  StoryItem get _currentStory => _currentGroup.stories[_currentStoryIndex];

  void _startStory() {
    _timer?.cancel();
    _videoController?.dispose();
    _videoController = null;
    _progress = 0;

    // Mark as viewed
    _storyService.markAsViewed(_currentStory.id);

    if (_currentStory.isVideo) {
      _startVideoStory();
    } else {
      _startImageTimer();
    }
  }

  void _startImageTimer() {
    final totalTicks =
        _imageDuration.inMilliseconds ~/ _tickInterval.inMilliseconds;
    int currentTick = 0;

    _timer = Timer.periodic(_tickInterval, (timer) {
      if (_isPaused) return;
      currentTick++;
      setState(() => _progress = currentTick / totalTicks);
      if (currentTick >= totalTicks) {
        timer.cancel();
        _nextStory();
      }
    });
  }

  void _startVideoStory() async {
    try {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(_currentStory.mediaUrl));
      await _videoController!.initialize();
      if (!mounted) return;
      _videoController!.play();

      final duration = _videoController!.value.duration;
      final totalTicks =
          duration.inMilliseconds ~/ _tickInterval.inMilliseconds;
      int currentTick = 0;

      setState(() {});

      _timer = Timer.periodic(_tickInterval, (timer) {
        if (_isPaused) return;
        currentTick++;
        setState(() => _progress = currentTick / totalTicks.clamp(1, 999999));
        if (currentTick >= totalTicks) {
          timer.cancel();
          _nextStory();
        }
      });
    } catch (e) {
      // Fallback to image timer if video fails
      _startImageTimer();
    }
  }

  void _nextStory() {
    if (_currentStoryIndex < _currentGroup.stories.length - 1) {
      setState(() => _currentStoryIndex++);
      _startStory();
    } else {
      _nextGroup();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _startStory();
    } else {
      _previousGroup();
    }
  }

  void _nextGroup() {
    if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousGroup() {
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = 0;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _isPaused = true;
    _videoController?.pause();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _isPaused = false;
    _videoController?.play();
  }

  void _deleteCurrentStory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete story?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _timer?.cancel();
    await _storyService.deleteStory(_currentStory.id);

    if (!mounted) return;

    // Remove from local list
    _currentGroup.stories.removeAt(_currentStoryIndex);
    if (_currentGroup.stories.isEmpty) {
      Navigator.pop(context, true); // Signal refresh
    } else {
      _currentStoryIndex =
          _currentStoryIndex.clamp(0, _currentGroup.stories.length - 1);
      _startStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.storyGroups.length,
          itemBuilder: (context, groupIndex) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Media content
                _buildMedia(),

                // Text overlay
                if (_currentStory.textOverlay != null &&
                    _currentStory.textOverlay!.isNotEmpty)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentStory.textOverlay!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // Top: progress bars + user info
                _buildTopBar(),

                // Bottom: view count (own stories) or time
                _buildBottomInfo(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (_currentStory.isVideo && _videoController != null && _videoController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    return Image.network(
      _currentStory.mediaUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      },
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white38, size: 60),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Column(
        children: [
          // Progress bars
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: List.generate(_currentGroup.stories.length, (i) {
                double barProgress;
                if (i < _currentStoryIndex) {
                  barProgress = 1.0;
                } else if (i == _currentStoryIndex) {
                  barProgress = _progress;
                } else {
                  barProgress = 0.0;
                }

                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: LinearProgressIndicator(
                      value: barProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 2.5,
                    ),
                  ),
                );
              }),
            ),
          ),

          // User info row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _currentGroup.userAvatar != null
                      ? NetworkImage(_currentGroup.userAvatar!)
                      : null,
                  child: _currentGroup.userAvatar == null
                      ? Text(_currentGroup.userName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 14))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentGroup.isMyStory
                            ? 'Your story'
                            : _currentGroup.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timeago.format(_currentStory.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete (own stories)
                if (_currentGroup.isMyStory)
                  IconButton(
                    onPressed: _deleteCurrentStory,
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                  ),

                // Close
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    if (!_currentGroup.isMyStory) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                '${_currentStory.viewCount}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}