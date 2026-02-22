import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/friendship_service.dart';

/// Ecran pentru vizualizarea profilului unui utilizator
/// Afișează informațiile publice ale utilizatorului
/// ✅ NOU: Butoane Unfriend / Block
class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userAvatar;

  const UserProfileViewScreen({
    super.key,
    required this.userId,
    this.userName,
    this.userAvatar,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FriendshipService _friendshipService = FriendshipService();
  
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isFriend = false;
  bool _isBlocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkRelationship();
  }

  /// Verifică dacă sunt prieteni sau blocați
  Future<void> _checkRelationship() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final isFriend = await _friendshipService.areFriends(currentUserId, widget.userId);
    final isBlocked = await _friendshipService.isBlocked(widget.userId);

    if (mounted) {
      setState(() {
        _isFriend = isFriend;
        _isBlocked = isBlocked;
      });
    }
  }

  /// Încarcă datele complete ale profilului
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, bio, created_at')
          .eq('id', widget.userId)
          .single();

      setState(() {
        _profileData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName ?? context.tr('profile')),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('error_loading'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final fullName = _profileData?['full_name'] as String? ?? 'Unknown User';
    final avatarUrl = _profileData?['avatar_url'] as String?;
    final bio = _profileData?['bio'] as String?;
    final createdAt = _profileData?['created_at'] != null
        ? DateTime.parse(_profileData!['created_at'] as String)
        : null;

    // ✅ NOU: Ascunde info profil dacă nu sunt prieteni
    final bool showFullProfile = _isFriend;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Avatar mare — generic dacă nu sunt prieteni
          Hero(
            tag: 'profile_avatar_${widget.userId}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (showFullProfile 
                        ? colorScheme.primary 
                        : colorScheme.onSurface).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 80,
                backgroundColor: showFullProfile
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                // ✅ Ascunde poza dacă nu sunt prieteni
                backgroundImage: showFullProfile && avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: showFullProfile && avatarUrl == null
                    ? Text(
                        fullName[0].toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : !showFullProfile
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          )
                        : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Numele — se arată mereu
          Text(
            fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),

          // ✅ NOU: Mesaj de status (blocat/deblocat)
          if (_isBlocked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Blocked',
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (!_isFriend && !_isBlocked) ...[
            const SizedBox(height: 8),
            Text(
              'Not in your friends list',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 32),
          // Card cu informații — doar dacă sunt prieteni
          if (showFullProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bio
                      if (bio != null && bio.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.tr('bio'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text(
                          bio,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Data înregistrării
                    if (createdAt != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Member since',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text(
                          '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // ✅ NOU: Butoane Unfriend / Block
          if (_isFriend || _isBlocked) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (_isFriend) ...[
                    // Unfriend
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmUnfriend(fullName),
                        icon: const Icon(Icons.person_remove, size: 20),
                        label: Text(context.tr('unfriend')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Block / Unblock
                  SizedBox(
                    width: double.infinity,
                    child: _isBlocked
                        ? OutlinedButton.icon(
                            onPressed: () => _confirmUnblock(fullName),
                            icon: const Icon(Icons.lock_open, size: 20),
                            label: Text(context.tr('unblock_user')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(color: colorScheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _confirmBlock(fullName),
                            icon: const Icon(Icons.block, size: 20),
                            label: Text(context.tr('block_user')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              side: BorderSide(color: colorScheme.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// ✅ NOU: Confirmare Unfriend
  Future<void> _confirmUnfriend(String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove, color: Colors.orange, size: 40),
        title: Text(context.tr('unfriend')),
        content: Text(
          'Are you sure you want to remove $userName from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.tr('unfriend')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _friendshipService.removeFriend(widget.userId);

    if (!mounted) return;

    if (success) {
      setState(() => _isFriend = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName ${context.tr('removed_from_friends')}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// ✅ NOU: Confirmare Block
  Future<void> _confirmBlock(String userName) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.block, color: colorScheme.error, size: 40),
        title: Text(context.tr('block_user')),
        content: Text(
          'Are you sure you want to block $userName?\n\n'
          'This will remove them from your friends and prevent all contact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: Text(context.tr('block_user')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _friendshipService.blockUser(widget.userId);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isFriend = false;
        _isBlocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('user_blocked')),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  /// ✅ NOU: Confirmare Unblock
  Future<void> _confirmUnblock(String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('unblock_user')),
        content: Text('${context.tr('confirm_unblock')} $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('unblock_user')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _friendshipService.unblockUser(widget.userId);

    if (!mounted) return;

    if (success) {
      setState(() => _isBlocked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('user_unblocked')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}