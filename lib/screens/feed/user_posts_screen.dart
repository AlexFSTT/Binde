import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../models/post_model.dart';
import '../../services/feed_service.dart';
import '../../services/friendship_service.dart';
import '../../services/profile_service.dart';
import 'post_detail_screen.dart';

/// Ecran profil user cu postări (Facebook-like)
class UserPostsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  final FeedService _feedService = FeedService();
  final FriendshipService _friendshipService = FriendshipService();
  final ProfileService _profileService = ProfileService();

  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _relationshipStatus = 'none';
  bool _isRelationshipLoading = true;

  Map<String, dynamic>? _profile;

  bool get _isMe =>
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAll();
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

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadRelationship(),
      _loadPosts(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _loadRelationship() async {
    if (_isMe) {
      if (mounted) setState(() => _isRelationshipLoading = false);
      return;
    }

    try {
      final status = await _friendshipService.getRelationshipStatus(widget.userId);

      if (status == 'none') {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          final pending = await Supabase.instance.client
              .from('friendships')
              .select('id')
              .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)')
              .eq('status', 'pending')
              .maybeSingle();

          if (pending != null && mounted) {
            setState(() {
              _relationshipStatus = 'pending';
              _isRelationshipLoading = false;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _relationshipStatus = status;
          _isRelationshipLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRelationshipLoading = false);
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await _feedService.getUserPosts(widget.userId, limit: 20, offset: 0);
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

    final morePosts = await _feedService.getUserPosts(
      widget.userId, limit: 20, offset: _posts.length,
    );

    if (mounted) {
      setState(() {
        _posts.addAll(morePosts);
        _isLoadingMore = false;
        _hasMore = morePosts.length >= 20;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    final success = await _friendshipService.sendFriendRequest(widget.userId);
    if (success && mounted) {
      setState(() => _relationshipStatus = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !post.isLikedByMe,
        likeCount: post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
      );
    });

    final success = await _feedService.toggleLike(post.id);
    if (!success && mounted) setState(() => _posts[index] = post);
  }

  void _openPostDetail(int index) async {
    final result = await Navigator.push<PostModel?>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: _posts[index])),
    );
    if (result != null && mounted) setState(() => _posts[index] = result);
  }

  Future<void> _openUrl(String url) async {
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    try {
      await launchUrl(Uri.parse(finalUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  String get _fullName => _profile?['full_name'] ?? widget.userName;
  String? get _avatarUrl => _profile?['avatar_url'] ?? widget.userAvatar;
  String? get _coverUrl => _profile?['cover_url'];
  String? get _bio => _profile?['bio'];
  bool get _showFullProfile => _isMe || _relationshipStatus == 'friend';

  bool get _canSeeContact {
    final vis = _profile?['contact_visibility'] ?? 'friends';
    if (vis == 'public') return true;
    if (vis == 'friends' && _relationshipStatus == 'friend') return true;
    if (_isMe) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ✅ Cover + Avatar overlap (Facebook-style)
            SliverToBoxAdapter(child: _buildCoverAndAvatar(cs)),

            // Profile info
            SliverToBoxAdapter(child: _buildProfileInfo(cs)),

            // Separator
            SliverToBoxAdapter(
              child: Container(height: 8, color: cs.surfaceContainerHighest.withValues(alpha: 0.4)),
            ),

            // Posts title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ),
            ),

            // Posts
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_posts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 60, color: cs.onSurface.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text('No posts yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.35), fontSize: 16)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return _buildPostCard(index, cs);
                  },
                  childCount: _posts.length + (_isLoadingMore ? 1 : 0),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // COVER + AVATAR (Facebook-style overlap)
  // =====================================================

  Widget _buildCoverAndAvatar(ColorScheme cs) {
    return SizedBox(
      height: 240,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover photo — 180px
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
            ),
            child: _coverUrl != null && _showFullProfile
                ? Image.network(_coverUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: cs.surfaceContainerHighest))
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primary.withValues(alpha: 0.3),
                          cs.surfaceContainerHighest,
                        ],
                      ),
                    ),
                  ),
          ),

          // Bottom area behind avatar+name (matches cover tone)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(color: cs.surfaceContainerHighest),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Avatar
          Positioned(
            bottom: 0,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.surfaceContainerHighest, width: 4),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: _showFullProfile ? cs.primaryContainer : cs.surfaceContainerHighest,
                backgroundImage: _showFullProfile && _avatarUrl != null
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _showFullProfile && _avatarUrl == null
                    ? Text(_fullName[0].toUpperCase(),
                        style: TextStyle(color: cs.onPrimaryContainer, fontSize: 32, fontWeight: FontWeight.bold))
                    : !_showFullProfile
                        ? Icon(Icons.person, size: 36, color: cs.onSurface.withValues(alpha: 0.25))
                        : null,
              ),
            ),
          ),

          // Name + username — next to avatar
          Positioned(
            bottom: 8,
            left: 120, // 16 (avatar left) + 4 (border) + 92 (avatar diameter) + 8 (gap)
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fullName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_profile?['username'] != null)
                  Text(
                    '@${_profile!['username']}',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PROFILE INFO (bio, relationship, details — no name)
  // =====================================================

  Widget _buildProfileInfo(ColorScheme cs) {
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio
          if (_showFullProfile && _bio != null && _bio!.isNotEmpty) ...[
            Text(_bio!, style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.7), height: 1.4)),
            const SizedBox(height: 10),
          ],

          // Relationship button
          if (!_isMe && !_isRelationshipLoading) ...[
            _buildRelationshipButton(cs),
            const SizedBox(height: 10),
          ],

          // Details section
          if (_showFullProfile) _buildDetailsSection(cs),
        ],
      ),
    );
  }

  // =====================================================
  // DETAILS SECTION — cu link clickable
  // =====================================================

  Widget _buildDetailsSection(ColorScheme cs) {
    final details = <_DetailItem>[];

    // Job
    if (_profile?['job_title'] != null || _profile?['job_company'] != null) {
      final job = [_profile?['job_title'], _profile?['job_company']]
          .where((e) => e != null && e.toString().isNotEmpty)
          .join(' at ');
      if (job.isNotEmpty) details.add(_DetailItem(Icons.work_outline, job));
    }

    // School
    if (_profile?['school'] != null && _profile!['school'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.school_outlined, _profile!['school']));
    }

    // Current city
    if (_profile?['current_city'] != null && _profile!['current_city'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.location_on_outlined, 'Lives in ${_profile!['current_city']}'));
    }

    // Birth city
    if (_profile?['birth_city'] != null && _profile!['birth_city'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.home_outlined, 'From ${_profile!['birth_city']}'));
    }

    // Relationship
    if (_profile?['relationship_status'] != null && _profile!['relationship_status'].toString().isNotEmpty) {
      String relText = _profile!['relationship_status'];
      if (_profile?['relationship_partner'] != null && _profile!['relationship_partner'].toString().isNotEmpty) {
        relText += ' with ${_profile!['relationship_partner']}';
      }
      details.add(_DetailItem(Icons.favorite_outline, relText));
    }

    // Religion
    if (_profile?['religion'] != null && _profile!['religion'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.church_outlined, _profile!['religion']));
    }

    // Languages
    if (_profile?['languages'] != null && _profile!['languages'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.translate, 'Speaks ${_profile!['languages']}'));
    }

    // Sports
    if (_profile?['favorite_sports'] != null && _profile!['favorite_sports'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.sports_soccer_outlined, _profile!['favorite_sports']));
    }

    // Teams
    if (_profile?['favorite_teams'] != null && _profile!['favorite_teams'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.shield_outlined, _profile!['favorite_teams']));
    }

    // Games
    if (_profile?['favorite_games'] != null && _profile!['favorite_games'].toString().isNotEmpty) {
      details.add(_DetailItem(Icons.sports_esports_outlined, _profile!['favorite_games']));
    }

    // Contact (respectă visibility)
    if (_canSeeContact) {
      if (_profile?['phone'] != null && _profile!['phone'].toString().isNotEmpty) {
        details.add(_DetailItem(Icons.phone_outlined, _profile!['phone']));
      }
      // ✅ Website — marcat ca link
      if (_profile?['website'] != null && _profile!['website'].toString().isNotEmpty) {
        details.add(_DetailItem(Icons.link, _profile!['website'], isLink: true));
      }
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 10),
        ...details.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(d.icon, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: d.isLink
                        ? GestureDetector(
                            onTap: () => _openUrl(d.text),
                            child: Text(
                              d.text,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: cs.primary.withValues(alpha: 0.4),
                                height: 1.3,
                              ),
                            ),
                          )
                        : Text(d.text, style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.7), height: 1.3)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // =====================================================
  // RELATIONSHIP BUTTON
  // =====================================================

  Widget _buildRelationshipButton(ColorScheme cs) {
    switch (_relationshipStatus) {
      case 'friend':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.check_circle, size: 18, color: cs.primary),
            label: Text('Friends', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );

      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.hourglass_top, size: 18, color: Colors.orange[700]),
            label: Text('Request sent', style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );

      case 'blocked':
      case 'blocked_by':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.block, size: 18, color: cs.error),
            label: Text('Blocked', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );

      case 'none':
      default:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sendFriendRequest,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add Friend'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );
    }
  }

  // =====================================================
  // POST CARD
  // =====================================================

  Widget _buildPostCard(int index, ColorScheme cs) {
    final post = _posts[index];
    final currentUserId = _feedService.currentUserId;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timp + visibility
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text(timeago.format(post.createdAt),
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                const SizedBox(width: 6),
                Icon(
                  post.visibility == 'friends' ? Icons.people_outline : Icons.public,
                  size: 14, color: cs.onSurface.withValues(alpha: 0.3),
                ),
                const Spacer(),
                if (post.userId == currentUserId)
                  GestureDetector(
                    onTap: () => _confirmDelete(index),
                    child: Icon(Icons.more_horiz, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                  ),
              ],
            ),
          ),

          // Content
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(post.content, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),

          // Imagine
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SizedBox(
                width: double.infinity,
                child: Image.network(post.imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ],

          // Counts
          if (post.likeCount > 0 || post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  if (post.likeCount > 0) ...[
                    Icon(Icons.favorite, size: 15, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text('${post.likeCount}', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                  if (post.likeCount > 0 && post.commentCount > 0) const Spacer(),
                  if (post.commentCount > 0)
                    Text('${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),

          Divider(indent: 16, endIndent: 16, height: 1, color: cs.outline.withValues(alpha: 0.08)),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _toggleLike(index),
                  icon: Icon(
                    post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                    size: 19,
                    color: post.isLikedByMe ? Colors.red[400] : cs.onSurface.withValues(alpha: 0.45),
                  ),
                  label: Text('Like', style: TextStyle(
                    color: post.isLikedByMe ? Colors.red[400] : cs.onSurface.withValues(alpha: 0.45), fontSize: 13)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openPostDetail(index),
                  icon: Icon(Icons.chat_bubble_outline, size: 19, color: cs.onSurface.withValues(alpha: 0.45)),
                  label: Text('Comment', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final post = _posts[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await _feedService.deletePost(post.id);
      if (success && mounted) setState(() => _posts.removeAt(index));
    }
  }
}

class _DetailItem {
  final IconData icon;
  final String text;
  final bool isLink;
  const _DetailItem(this.icon, this.text, {this.isLink = false});
}