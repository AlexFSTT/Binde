import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../models/story_model.dart';

class StoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Create a new story with overlays and location
  Future<StoryItem?> createStory({
    required File file,
    required String mediaType,
    String? textOverlay,
    List<StoryOverlay> overlays = const [],
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$userId/$fileName';
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      await _supabase.storage.from('stories').upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final mediaUrl =
          _supabase.storage.from('stories').getPublicUrl(storagePath);

      final response = await _supabase
          .from('stories')
          .insert({
            'user_id': userId,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'text_overlay': textOverlay,
            'overlays': overlays.map((o) => o.toJson()).toList(),
            'location_name': locationName,
            'location_lat': locationLat,
            'location_lng': locationLng,
          })
          .select()
          .single();

      return StoryItem.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating story: $e');
      return null;
    }
  }

  /// Get all active stories grouped by user
  Future<List<StoryGroup>> getStoryGroups() async {
    try {
      final userId = currentUserId;

      final response = await _supabase
          .from('stories')
          .select('''
            *,
            user:profiles!stories_user_id_profiles_fkey(id, full_name, avatar_url)
          ''')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);

      if ((response as List).isEmpty) return [];

      // Fetch viewed story IDs
      Set<String> viewedIds = {};
      if (userId != null) {
        final views = await _supabase
            .from('story_views')
            .select('story_id')
            .eq('viewer_id', userId);
        viewedIds =
            (views as List).map((v) => v['story_id'] as String).toSet();
      }

      // Fetch view counts
      final storyIds = (response).map((s) => s['id'] as String).toList();
      Map<String, int> viewCounts = {};
      if (storyIds.isNotEmpty) {
        final counts = await _supabase
            .from('story_views')
            .select('story_id')
            .inFilter('story_id', storyIds);
        for (final v in (counts as List)) {
          final sid = v['story_id'] as String;
          viewCounts[sid] = (viewCounts[sid] ?? 0) + 1;
        }
      }

      // Fetch reactions
      Map<String, int> reactionCounts = {};
      Map<String, String?> myReactions = {};
      if (storyIds.isNotEmpty) {
        final reactions = await _supabase
            .from('story_reactions')
            .select('story_id, user_id, reaction_type')
            .inFilter('story_id', storyIds);
        for (final r in (reactions as List)) {
          final sid = r['story_id'] as String;
          reactionCounts[sid] = (reactionCounts[sid] ?? 0) + 1;
          if (r['user_id'] == userId) {
            myReactions[sid] = r['reaction_type'] as String;
          }
        }
      }

      // Group by user
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, Map<String, dynamic>> userInfo = {};

      for (final row in response) {
        final uid = row['user_id'] as String;
        grouped.putIfAbsent(uid, () => []);
        grouped[uid]!.add(row);
        userInfo[uid] = row['user'] as Map<String, dynamic>;
      }

      final List<StoryGroup> groups = [];
      for (final entry in grouped.entries) {
        final uid = entry.key;
        final user = userInfo[uid]!;
        final stories = entry.value.map((json) {
          final item = StoryItem.fromJson(json);
          return StoryItem(
            id: item.id,
            userId: item.userId,
            mediaUrl: item.mediaUrl,
            mediaType: item.mediaType,
            textOverlay: item.textOverlay,
            overlays: item.overlays,
            locationName: item.locationName,
            locationLat: item.locationLat,
            locationLng: item.locationLng,
            createdAt: item.createdAt,
            expiresAt: item.expiresAt,
            viewCount: viewCounts[item.id] ?? 0,
            viewedByMe: viewedIds.contains(item.id),
            reactionCount: reactionCounts[item.id] ?? 0,
            myReaction: myReactions[item.id],
          );
        }).toList();

        final allViewed = stories.every((s) => s.viewedByMe);

        groups.add(StoryGroup(
          userId: uid,
          userName: user['full_name'] as String? ?? 'Unknown',
          userAvatar: user['avatar_url'] as String?,
          stories: stories,
          allViewed: allViewed,
          isMyStory: uid == userId,
        ));
      }

      // Sort: my story first, then unviewed, then viewed
      groups.sort((a, b) {
        if (a.isMyStory) return -1;
        if (b.isMyStory) return 1;
        if (!a.allViewed && b.allViewed) return -1;
        if (a.allViewed && !b.allViewed) return 1;
        return b.latestStory.createdAt.compareTo(a.latestStory.createdAt);
      });

      return groups;
    } catch (e) {
      debugPrint('❌ Error getting story groups: $e');
      return [];
    }
  }

  /// Mark story as viewed
  Future<void> markAsViewed(String storyId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      await _supabase.from('story_views').upsert({
        'story_id': storyId,
        'viewer_id': userId,
      });
    } catch (e) {
      debugPrint('Error marking story as viewed: $e');
    }
  }

  /// Toggle reaction on a story
  Future<String?> toggleReaction(String storyId, String reactionType) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final existing = await _supabase
          .from('story_reactions')
          .select()
          .eq('story_id', storyId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        if (existing['reaction_type'] == reactionType) {
          await _supabase
              .from('story_reactions')
              .delete()
              .eq('story_id', storyId)
              .eq('user_id', userId);
          return null;
        } else {
          await _supabase
              .from('story_reactions')
              .update({'reaction_type': reactionType})
              .eq('story_id', storyId)
              .eq('user_id', userId);
          return reactionType;
        }
      } else {
        await _supabase.from('story_reactions').insert({
          'story_id': storyId,
          'user_id': userId,
          'reaction_type': reactionType,
        });
        return reactionType;
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      return null;
    }
  }

  /// Delete own story
  Future<bool> deleteStory(String storyId) async {
    try {
      await _supabase.from('stories').delete().eq('id', storyId);
      return true;
    } catch (e) {
      debugPrint('Error deleting story: $e');
      return false;
    }
  }

  /// Get viewers + reactions for a story, with friend info
  Future<StoryViewersData> getStoryViewers(String storyId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return StoryViewersData.empty();

      // Get all views with user info
      final views = await _supabase
          .from('story_views')
          .select('''
            viewer_id,
            created_at,
            viewer:profiles!story_views_viewer_id_profiles_fkey(id, full_name, avatar_url)
          ''')
          .eq('story_id', storyId)
          .order('created_at', ascending: false);

      // Get all reactions with user info
      final reactions = await _supabase
          .from('story_reactions')
          .select('''
            user_id,
            reaction_type,
            created_at,
            reactor:profiles!story_reactions_user_id_profiles_fkey(id, full_name, avatar_url)
          ''')
          .eq('story_id', storyId)
          .order('created_at', ascending: false);

      // Get current user's friends
      final friendships = await _supabase
          .from('friendships')
          .select('sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');

      final friendIds = <String>{};
      for (final f in friendships as List) {
        final senderId = f['sender_id'] as String;
        final receiverId = f['receiver_id'] as String;
        friendIds.add(senderId == userId ? receiverId : senderId);
      }

      // Build viewer list
      final List<StoryViewerInfo> viewers = [];
      int anonymousCount = 0;

      for (final v in views as List) {
        final viewer = v['viewer'] as Map<String, dynamic>?;
        final viewerId = v['viewer_id'] as String;
        if (viewerId == userId) continue; // Skip self

        if (friendIds.contains(viewerId) && viewer != null) {
          viewers.add(StoryViewerInfo(
            userId: viewerId,
            name: viewer['full_name'] as String? ?? 'Unknown',
            avatarUrl: viewer['avatar_url'] as String?,
            isFriend: true,
          ));
        } else {
          anonymousCount++;
        }
      }

      // Build reaction list
      final List<StoryReactionInfo> reactionList = [];
      for (final r in reactions as List) {
        final reactor = r['reactor'] as Map<String, dynamic>?;
        final reactorId = r['user_id'] as String;

        if (friendIds.contains(reactorId) && reactor != null) {
          reactionList.add(StoryReactionInfo(
            userId: reactorId,
            name: reactor['full_name'] as String? ?? 'Unknown',
            avatarUrl: reactor['avatar_url'] as String?,
            reactionType: r['reaction_type'] as String,
            isFriend: true,
          ));
        } else {
          reactionList.add(StoryReactionInfo(
            userId: reactorId,
            name: 'Viewer',
            avatarUrl: null,
            reactionType: r['reaction_type'] as String,
            isFriend: false,
          ));
        }
      }

      return StoryViewersData(
        viewers: viewers,
        reactions: reactionList,
        anonymousViewCount: anonymousCount,
        totalViewCount: (views as List).length,
      );
    } catch (e) {
      debugPrint('Error getting story viewers: $e');
      return StoryViewersData.empty();
    }
  }
}