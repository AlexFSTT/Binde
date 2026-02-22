/// Model pentru o postare din feed
class PostModel {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final String visibility; // 'public' sau 'friends'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Date join din profiles
  final String? authorName;
  final String? authorAvatar;

  // Reactions (like, haha, angry, heart, sad)
  final Map<String, int> reactionCounts; // {'like': 5, 'heart': 2, ...}
  final int totalReactions;
  final String? myReaction; // null = no reaction, 'like', 'haha', etc.

  // Comments & Shares
  final int commentCount;
  final int shareCount;
  final bool isSharedByMe;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.authorAvatar,
    this.reactionCounts = const {},
    this.totalReactions = 0,
    this.myReaction,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isSharedByMe = false,
  });

  // Backward compat
  int get likeCount => totalReactions;
  bool get isLikedByMe => myReaction != null;

  factory PostModel.fromJson(Map<String, dynamic> json, {
    Map<String, int> reactionCounts = const {},
    int totalReactions = 0,
    String? myReaction,
    int commentCount = 0,
    int shareCount = 0,
    bool isSharedByMe = false,
  }) {
    final author = json['author'] as Map<String, dynamic>?;

    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      authorName: author?['full_name'] as String?,
      authorAvatar: author?['avatar_url'] as String?,
      reactionCounts: reactionCounts,
      totalReactions: totalReactions,
      myReaction: myReaction,
      commentCount: commentCount,
      shareCount: shareCount,
      isSharedByMe: isSharedByMe,
    );
  }

  PostModel copyWith({
    Map<String, int>? reactionCounts,
    int? totalReactions,
    String? myReaction,
    bool clearMyReaction = false,
    int? commentCount,
    int? shareCount,
    bool? isSharedByMe,
    String? content,
    String? imageUrl,
    String? visibility,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorName: authorName,
      authorAvatar: authorAvatar,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      totalReactions: totalReactions ?? this.totalReactions,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      isSharedByMe: isSharedByMe ?? this.isSharedByMe,
    );
  }
}

/// Tipuri de reacții disponibile
class ReactionType {
  static const String like = 'like';
  static const String haha = 'haha';
  static const String angry = 'angry';
  static const String heart = 'heart';
  static const String sad = 'sad';

  static const List<String> all = [like, heart, haha, sad, angry];

  static String emoji(String type) {
    switch (type) {
      case like: return '👍';
      case haha: return '😂';
      case angry: return '😡';
      case heart: return '❤️';
      case sad: return '😢';
      default: return '👍';
    }
  }

  static String label(String type) {
    switch (type) {
      case like: return 'Like';
      case haha: return 'Haha';
      case angry: return 'Angry';
      case heart: return 'Heart';
      case sad: return 'Sad';
      default: return 'Like';
    }
  }
}

/// Model pentru un comentariu
class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  final String? authorName;
  final String? authorAvatar;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.authorAvatar,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;

    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: author?['full_name'] as String?,
      authorAvatar: author?['avatar_url'] as String?,
    );
  }
}