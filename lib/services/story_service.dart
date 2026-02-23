import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../models/story_model.dart';

class StoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Create a new story
  Future<StoryItem?> createStory({
    required File file,
    required String mediaType,
    String? textOverlay,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      // Upload media
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

      // Insert story
      final response = await _supabase
          .from('stories')
          .insert({
            'user_id': userId,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'text_overlay': textOverlay,
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

      // Fetch all non-expired stories with user info
      final response = await _supabase
          .from('stories')
          .select('''
            *,
            user:profiles!stories_user_id_fkey(id, full_name, avatar_url)
          ''')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);

      if ((response as List).isEmpty) return [];

      // Fetch which stories current user has viewed
      Set<String> viewedIds = {};
      if (userId != null) {
        final views = await _supabase
            .from('story_views')
            .select('story_id')
            .eq('viewer_id', userId);
        viewedIds = (views as List).map((v) => v['story_id'] as String).toSet();
      }

      // Fetch view counts per story
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

      // Group by user
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, Map<String, dynamic>> userInfo = {};

      for (final row in response) {
        final uid = row['user_id'] as String;
        grouped.putIfAbsent(uid, () => []);
        grouped[uid]!.add(row);
        userInfo[uid] = row['user'] as Map<String, dynamic>;
      }

      // Build StoryGroups
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
            createdAt: item.createdAt,
            expiresAt: item.expiresAt,
            viewCount: viewCounts[item.id] ?? 0,
            viewedByMe: viewedIds.contains(item.id),
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
}