import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

/// Service pentru Feed - CRUD posts, reactions, comments, shares
class FeedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // =====================================================
  // POSTS
  // =====================================================

  /// Încarcă postări pentru feed (paginat)
  Future<List<PostModel>> getFeedPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final posts = await _supabase
          .from('posts')
          .select('''
            *,
            author:profiles!posts_user_id_fkey(id, full_name, avatar_url)
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return _enrichPostsWithCounts(posts as List);
    } catch (e) {
      debugPrint('❌ Error loading feed: $e');
      return [];
    }
  }

  /// Încarcă postările unui user specific
  Future<List<PostModel>> getUserPosts(String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final posts = await _supabase
          .from('posts')
          .select('''
            *,
            author:profiles!posts_user_id_fkey(id, full_name, avatar_url)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return _enrichPostsWithCounts(posts as List);
    } catch (e) {
      debugPrint('❌ Error loading user posts: $e');
      return [];
    }
  }

  /// Helper: adaugă reaction counts, comment counts, share counts
  Future<List<PostModel>> _enrichPostsWithCounts(List<dynamic> posts) async {
    if (posts.isEmpty) return [];

    final postIds = posts.map((p) => p['id'] as String).toList();

    // Reaction counts per post (grouped by reaction_type)
    final reactionCounts = <String, Map<String, int>>{};
    final totalReactions = <String, int>{};
    final myReactions = <String, String>{};

    try {
      final likesData = await _supabase
          .from('post_likes')
          .select('post_id, user_id, reaction_type')
          .inFilter('post_id', postIds);

      for (final like in likesData) {
        final postId = like['post_id'] as String;
        final type = like['reaction_type'] as String? ?? 'like';

        reactionCounts.putIfAbsent(postId, () => {});
        reactionCounts[postId]![type] = (reactionCounts[postId]![type] ?? 0) + 1;
        totalReactions[postId] = (totalReactions[postId] ?? 0) + 1;

        if (like['user_id'] == currentUserId) {
          myReactions[postId] = type;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading reactions: $e');
    }

    // Comment counts per post
    final commentCounts = <String, int>{};
    try {
      final commentsData = await _supabase
          .from('post_comments')
          .select('post_id')
          .inFilter('post_id', postIds);

      for (final comment in commentsData) {
        final postId = comment['post_id'] as String;
        commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('⚠️ Error loading comment counts: $e');
    }

    // Share counts per post
    final shareCounts = <String, int>{};
    final myShares = <String>{};
    try {
      final sharesData = await _supabase
          .from('post_shares')
          .select('post_id, user_id')
          .inFilter('post_id', postIds);

      for (final share in sharesData) {
        final postId = share['post_id'] as String;
        shareCounts[postId] = (shareCounts[postId] ?? 0) + 1;
        if (share['user_id'] == currentUserId) {
          myShares.add(postId);
        }
      }
    } catch (e) {
      // post_shares table might not exist yet
      debugPrint('⚠️ Shares table not available: $e');
    }

    return posts.map((json) {
      final postId = json['id'] as String;
      return PostModel.fromJson(
        json as Map<String, dynamic>,
        reactionCounts: reactionCounts[postId] ?? {},
        totalReactions: totalReactions[postId] ?? 0,
        myReaction: myReactions[postId],
        commentCount: commentCounts[postId] ?? 0,
        shareCount: shareCounts[postId] ?? 0,
        isSharedByMe: myShares.contains(postId),
      );
    }).toList();
  }

  /// Creează o postare nouă
  Future<PostModel?> createPost({
    required String content,
    required String visibility,
    File? imageFile,
  }) async {
    if (currentUserId == null) return null;

    try {
      String? imageUrl;

      if (imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = '$currentUserId/$fileName';

        await _supabase.storage
            .from('post-images')
            .upload(storagePath, imageFile);

        imageUrl = _supabase.storage
            .from('post-images')
            .getPublicUrl(storagePath);
      }

      final response = await _supabase
          .from('posts')
          .insert({
            'user_id': currentUserId,
            'content': content,
            'image_url': imageUrl,
            'visibility': visibility,
          })
          .select('''
            *,
            author:profiles!posts_user_id_fkey(id, full_name, avatar_url)
          ''')
          .single();

      debugPrint('✅ Post created');
      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      return null;
    }
  }

  /// Șterge o postare
  Future<bool> deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      return false;
    }
  }

  // =====================================================
  // REACTIONS
  // =====================================================

  /// Set reaction (or remove if same type)
  /// Returns the new reaction type (null if removed)
  Future<String?> setReaction(String postId, String reactionType) async {
    if (currentUserId == null) return null;

    try {
      // Check existing reaction
      final existing = await _supabase
          .from('post_likes')
          .select('id, reaction_type')
          .eq('post_id', postId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (existing != null) {
        if (existing['reaction_type'] == reactionType) {
          // Same reaction → remove
          await _supabase
              .from('post_likes')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', currentUserId!);
          return null;
        } else {
          // Different reaction → update
          await _supabase
              .from('post_likes')
              .update({'reaction_type': reactionType})
              .eq('post_id', postId)
              .eq('user_id', currentUserId!);
          return reactionType;
        }
      } else {
        // No reaction → insert
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
          'reaction_type': reactionType,
        });
        return reactionType;
      }
    } catch (e) {
      debugPrint('❌ Error setting reaction: $e');
      return null;
    }
  }

  /// Quick like toggle (backward compat)
  Future<bool> toggleLike(String postId) async {
    await setReaction(postId, 'like');
    return true;
  }

  // =====================================================
  // SHARES
  // =====================================================

  /// Toggle share on a post
  Future<bool> toggleShare(String postId) async {
    if (currentUserId == null) return false;

    try {
      final existing = await _supabase
          .from('post_shares')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('post_shares')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUserId!);
      } else {
        await _supabase.from('post_shares').insert({
          'post_id': postId,
          'user_id': currentUserId,
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling share: $e');
      return false;
    }
  }

  // =====================================================
  // COMMENTS
  // =====================================================

  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final response = await _supabase
          .from('post_comments')
          .select('''
            *,
            author:profiles!post_comments_user_id_fkey(id, full_name, avatar_url)
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading comments: $e');
      return [];
    }
  }

  Future<CommentModel?> addComment(String postId, String content) async {
    if (currentUserId == null) return null;

    try {
      final response = await _supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'user_id': currentUserId,
            'content': content,
          })
          .select('''
            *,
            author:profiles!post_comments_user_id_fkey(id, full_name, avatar_url)
          ''')
          .single();

      return CommentModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _supabase.from('post_comments').delete().eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      return false;
    }
  }
}