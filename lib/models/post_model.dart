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

  // Contoare
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;

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
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json, {
    int likeCount = 0,
    int commentCount = 0,
    bool isLikedByMe = false,
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
      likeCount: likeCount,
      commentCount: commentCount,
      isLikedByMe: isLikedByMe,
    );
  }

  PostModel copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
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
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}

/// Model pentru un comentariu
class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  // Date join din profiles
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
