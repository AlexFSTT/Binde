/// Model pentru un update despre aplicație (doar admini pot posta)
class AppUpdate {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUpdate({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.authorId,
    this.authorName,
    this.authorAvatar,
    this.isPublished = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      authorId: json['author_id'] as String?,
      authorName: json['profiles']?['full_name'] as String?,
      authorAvatar: json['profiles']?['avatar_url'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'author_id': authorId,
      'is_published': isPublished,
    };
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
