import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

/// Service pentru Feed - CRUD posts, likes, comments
class FeedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // =====================================================
  // POSTS
  // =====================================================

  /// Încarcă postări pentru feed (paginat)
  /// RLS se ocupă de visibility + block filtering
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

  /// Helper: adaugă like count, comment count, isLikedByMe
  Future<List<PostModel>> _enrichPostsWithCounts(List<dynamic> posts) async {
    if (posts.isEmpty) return [];

    final postIds = posts.map((p) => p['id'] as String).toList();

    // Like counts per post
    final likeCounts = <String, int>{};
    final myLikes = <String>{};

    final likesData = await _supabase
        .from('post_likes')
        .select('post_id, user_id')
        .inFilter('post_id', postIds);

    for (final like in likesData) {
      final postId = like['post_id'] as String;
      likeCounts[postId] = (likeCounts[postId] ?? 0) + 1;
      if (like['user_id'] == currentUserId) {
        myLikes.add(postId);
      }
    }

    // Comment counts per post
    final commentCounts = <String, int>{};

    final commentsData = await _supabase
        .from('post_comments')
        .select('post_id')
        .inFilter('post_id', postIds);

    for (final comment in commentsData) {
      final postId = comment['post_id'] as String;
      commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
    }

    return posts.map((json) {
      final postId = json['id'] as String;
      return PostModel.fromJson(
        json as Map<String, dynamic>,
        likeCount: likeCounts[postId] ?? 0,
        commentCount: commentCounts[postId] ?? 0,
        isLikedByMe: myLikes.contains(postId),
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

      // Upload imagine dacă există
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

  /// Șterge o postare (doar propria)
  Future<bool> deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);
      debugPrint('✅ Post deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      return false;
    }
  }

  // =====================================================
  // LIKES
  // =====================================================

  /// Toggle like pe o postare
  Future<bool> toggleLike(String postId) async {
    if (currentUserId == null) return false;

    try {
      // Verifică dacă am dat deja like
      final existing = await _supabase
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUserId!);
        debugPrint('👎 Unliked post');
      } else {
        // Like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
        });
        debugPrint('👍 Liked post');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      return false;
    }
  }

  // =====================================================
  // COMMENTS
  // =====================================================

  /// Încarcă comentariile unei postări
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

  /// Adaugă un comentariu
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

      debugPrint('✅ Comment added');
      return CommentModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      return null;
    }
  }

  /// Șterge un comentariu (doar propriul)
  Future<bool> deleteComment(String commentId) async {
    try {
      await _supabase.from('post_comments').delete().eq('id', commentId);
      debugPrint('✅ Comment deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      return false;
    }
  }
}
