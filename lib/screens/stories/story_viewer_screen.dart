import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/story_model.dart';
import '../../services/story_service.dart';
import '../../services/friendship_service.dart';
import '../../services/chat_service.dart';
import '../../l10n/app_localizations.dart';

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
  final FriendshipService _friendshipService = FriendshipService();
  final ChatService _chatService = ChatService();

  late PageController _pageController;
  late int _currentGroupIndex;
  int _currentStoryIndex = 0;

  Timer? _timer;
  double _progress = 0;
  static const _imageDuration = Duration(seconds: 5);
  static const _tickInterval = Duration(milliseconds: 50);

  VideoPlayerController? _videoController;
  bool _isPaused = false;
  bool? _isFriend; // null = loading

  // Reply
  final TextEditingController _replyController = TextEditingController();
  bool _showReplyInput = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _pageController = PageController(initialPage: _currentGroupIndex);
    _startStory();
    _checkFriendship();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  StoryGroup get _currentGroup => widget.storyGroups[_currentGroupIndex];
  StoryItem get _currentStory => _currentGroup.stories[_currentStoryIndex];

  Future<void> _checkFriendship() async {
    if (_currentGroup.isMyStory) {
      setState(() => _isFriend = false);
      return;
    }
    final areFriends = await _friendshipService.areFriends(
      _friendshipService.currentUserId ?? '',
      _currentGroup.userId,
    );
    if (mounted) setState(() => _isFriend = areFriends);
  }

  void _startStory() {
    _timer?.cancel();
    _videoController?.dispose();
    _videoController = null;
    _progress = 0;

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
      if (_isPaused || _showReplyInput) return;
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
        if (_isPaused || _showReplyInput) return;
        currentTick++;
        setState(() => _progress = currentTick / totalTicks.clamp(1, 999999));
        if (currentTick >= totalTicks) {
          timer.cancel();
          _nextStory();
        }
      });
    } catch (e) {
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
        _isFriend = null;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
      _checkFriendship();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousGroup() {
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = 0;
        _isFriend = null;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
      _checkFriendship();
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_showReplyInput) return;
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

  // ============ REACTIONS (non-friends + friends) ============

  void _onReaction(String type) async {
    // Quick haptic-like visual feedback
    final result = await _storyService.toggleReaction(_currentStory.id, type);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result != null
              ? '${StoryReactionType.emoji(type)} ${context.tr('reacted')}'
              : context.tr('reaction_removed')),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============ REPLY (friends only) ============

  void _openReplyInput() {
    setState(() {
      _showReplyInput = true;
      _isPaused = true;
      _videoController?.pause();
    });
  }

  void _closeReplyInput() {
    setState(() {
      _showReplyInput = false;
      _isPaused = false;
      _videoController?.play();
    });
    _replyController.clear();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    // Capture translations before async
    final repliedText = context.tr('replied_to_story');
    final sentText = context.tr('reply_sent');
    final storyId = _currentStory.id;

    // Send as a message in conversation with story owner
    try {
      final conversation = await _chatService.getOrCreateConversation(
        _currentGroup.userId,
      );

      final replyText = '📖 $repliedText: $text';
      await _chatService.sendMessage(
        conversation.id,
        replyText,
        replyToStoryId: storyId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sentText),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending reply: $e');
    }

    _closeReplyInput();
  }

  // ============ VIEWERS SHEET (own stories) ============

  void _openViewersSheet() {
    _isPaused = true;
    _videoController?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StoryViewersSheet(
        storyId: _currentStory.id,
        storyService: _storyService,
      ),
    ).then((_) {
      if (mounted) {
        _isPaused = false;
        _videoController?.play();
      }
    });
  }

  // ============ DELETE (own stories) ============

  void _deleteCurrentStory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_story')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _timer?.cancel();
    await _storyService.deleteStory(_currentStory.id);

    if (!mounted) return;

    _currentGroup.stories.removeAt(_currentStoryIndex);
    if (_currentGroup.stories.isEmpty) {
      Navigator.pop(context, true);
    } else {
      _currentStoryIndex =
          _currentStoryIndex.clamp(0, _currentGroup.stories.length - 1);
      _startStory();
    }
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
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
                // Media
                _buildMedia(),

                // Overlays (text + emoji)
                ..._buildOverlays(),

                // Location badge
                if (_currentStory.hasLocation)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(_currentStory.locationName!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Legacy text overlay
                if (_currentStory.textOverlay != null &&
                    _currentStory.textOverlay!.isNotEmpty &&
                    _currentStory.overlays.isEmpty)
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

                // Top bar
                _buildTopBar(),

                // Bottom: reactions/reply OR view count
                _buildBottomSection(),

                // Reply input overlay
                if (_showReplyInput) _buildReplyInput(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (_currentStory.isVideo &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
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
          child:
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white38, size: 60),
      ),
    );
  }

  List<Widget> _buildOverlays() {
    final size = MediaQuery.of(context).size;
    return _currentStory.overlays.map((o) {
      return Positioned(
        left: o.x * size.width - (o.isEmoji ? 25 : 75),
        top: o.y * size.height - 20,
        child: Transform.rotate(
          angle: o.rotation,
          child: Transform.scale(
            scale: o.scale,
            child: o.isEmoji
                ? Text(o.content, style: const TextStyle(fontSize: 40))
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: o.hasBg == true
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      o.content,
                      style: TextStyle(
                        color: o.color != null
                            ? Color(int.parse(
                                '0xFF${o.color!.replaceFirst('#', '')}'))
                            : Colors.white,
                        fontSize: o.fontSize ?? 24,
                        fontWeight: FontWeight.w600,
                        shadows: o.hasBg != true
                            ? const [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(1, 1)),
                              ]
                            : null,
                      ),
                    ),
                  ),
          ),
        ),
      );
    }).toList();
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
          // User info
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
                            ? context.tr('your_story')
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
                if (_currentGroup.isMyStory)
                  IconButton(
                    onPressed: _deleteCurrentStory,
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
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

  Widget _buildBottomSection() {
    // Own story → show view count
    if (_currentGroup.isMyStory) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: GestureDetector(
            onTap: _openViewersSheet,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility_outlined,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text('${_currentStory.viewCount}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (_currentStory.reactionCount > 0) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 4),
                    Text('${_currentStory.reactionCount}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_up,
                      color: Colors.white.withValues(alpha: 0.4), size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Others → reaction bar + reply (if friend)
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Reply button (friends only)
              if (_isFriend == true)
                Expanded(
                  child: GestureDetector(
                    onTap: _openReplyInput,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        context.tr('reply_to_story'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
              if (_isFriend == true) const SizedBox(width: 12),

              // Reaction buttons
              ...StoryReactionType.all.map((type) {
                final isSelected = _currentStory.myReaction == type;
                return GestureDetector(
                  onTap: () => _onReaction(type),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      StoryReactionType.emoji(type),
                      style: TextStyle(fontSize: isSelected ? 28 : 24),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        padding: EdgeInsets.only(
          left: 16,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.tr('type_reply'),
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendReply,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
              IconButton(
                onPressed: _closeReplyInput,
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// VIEWERS & REACTIONS SHEET
// =============================================================

class _StoryViewersSheet extends StatefulWidget {
  final String storyId;
  final StoryService storyService;

  const _StoryViewersSheet({
    required this.storyId,
    required this.storyService,
  });

  @override
  State<_StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<_StoryViewersSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StoryViewersData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await widget.storyService.getStoryViewers(widget.storyId);
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('${_data?.totalViewCount ?? 0}'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_outline, size: 18),
                    const SizedBox(width: 6),
                    Text('${_data?.reactions.length ?? 0}'),
                  ],
                ),
              ),
            ],
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildViewersList(cs),
                      _buildReactionsList(cs),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewersList(ColorScheme cs) {
    if (_data == null) return const SizedBox.shrink();

    final viewers = _data!.viewers;
    final anonCount = _data!.anonymousViewCount;

    if (viewers.isEmpty && anonCount == 0) {
      return Center(
        child: Text(
          'No viewers yet',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Friend viewers (with name + avatar)
        ...viewers.map((v) => ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    v.avatarUrl != null ? NetworkImage(v.avatarUrl!) : null,
                child: v.avatarUrl == null
                    ? Text(v.name[0].toUpperCase())
                    : null,
              ),
              title: Text(v.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            )),

        // Anonymous viewers
        if (anonCount > 0)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.surfaceContainerHighest,
              child: Icon(Icons.group,
                  size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
            title: Text(
              '$anonCount other${anonCount > 1 ? 's' : ''} viewed',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReactionsList(ColorScheme cs) {
    if (_data == null || _data!.reactions.isEmpty) {
      return Center(
        child: Text(
          'No reactions yet',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _data!.reactions.length,
      itemBuilder: (_, i) {
        final r = _data!.reactions[i];
        return ListTile(
          leading: r.isFriend
              ? CircleAvatar(
                  backgroundImage:
                      r.avatarUrl != null ? NetworkImage(r.avatarUrl!) : null,
                  child: r.avatarUrl == null
                      ? Text(r.name[0].toUpperCase())
                      : null,
                )
              : CircleAvatar(
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(Icons.person,
                      size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
          title: Text(
            r.isFriend ? r.name : 'Someone',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontStyle: r.isFriend ? FontStyle.normal : FontStyle.italic,
              color: r.isFriend
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: Text(
            StoryReactionType.emoji(r.reactionType),
            style: const TextStyle(fontSize: 22),
          ),
        );
      },
    );
  }
}