import 'package:flutter/material.dart';
import '../../models/story_model.dart';
import '../../services/story_service.dart';
import '../../screens/stories/story_viewer_screen.dart';
import '../../screens/stories/create_story_screen.dart';

/// Horizontal stories bar — sits at top of feed
class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => StoriesBarState();
}

class StoriesBarState extends State<StoriesBar> {
  final StoryService _storyService = StoryService();
  List<StoryGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    final groups = await _storyService.getStoryGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  void _openCreateStory() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    );
    if (result == true) loadStories();
  }

  void _openStoryViewer(int groupIndex) async {
    // Skip "add" button index — find actual group index
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => StoryViewerScreen(
          storyGroups: _groups,
          initialGroupIndex: groupIndex,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (result == true) loadStories();
    // Refresh viewed state
    loadStories();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 100,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _groups.length + 1, // +1 for "Add" button
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildAddStoryButton(cs);
                }
                final group = _groups[index - 1];
                return _buildStoryAvatar(group, index - 1, cs);
              },
            ),
    );
  }

  Widget _buildAddStoryButton(ColorScheme cs) {
    final hasMyStory = _groups.any((g) => g.isMyStory);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: hasMyStory
            ? () {
                final idx = _groups.indexWhere((g) => g.isMyStory);
                if (idx >= 0) _openStoryViewer(idx);
              }
            : _openCreateStory,
        onLongPress: hasMyStory ? _openCreateStory : null,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: hasMyStory && _groups.firstWhere((g) => g.isMyStory).userAvatar != null
                        ? CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(
                                _groups.firstWhere((g) => g.isMyStory).userAvatar!),
                          )
                        : CircleAvatar(
                            radius: 30,
                            backgroundColor: cs.surfaceContainerHighest,
                            child: Icon(Icons.person,
                                size: 28,
                                color: cs.onSurface.withValues(alpha: 0.4)),
                          ),
                  ),
                  // "+" badge
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hasMyStory ? 'My story' : 'Add story',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryAvatar(StoryGroup group, int groupIndex, ColorScheme cs) {
    // Skip showing "my story" in the list — it's handled by Add button
    if (group.isMyStory) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _openStoryViewer(groupIndex),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with gradient ring
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: group.allViewed
                      ? null
                      : const LinearGradient(
                          colors: [
                            Color(0xFF833AB4), // Purple
                            Color(0xFFF77737), // Orange
                            Color(0xFFE1306C), // Pink
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: group.allViewed
                      ? Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                          width: 2,
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage: group.userAvatar != null
                        ? NetworkImage(group.userAvatar!)
                        : null,
                    child: group.userAvatar == null
                        ? Text(
                            group.userName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                group.userName.split(' ').first,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      group.allViewed ? FontWeight.normal : FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: group.allViewed ? 0.5 : 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}