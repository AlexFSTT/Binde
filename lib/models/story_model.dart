/// A single story item
class StoryItem {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? textOverlay;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final bool viewedByMe;

  StoryItem({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.textOverlay,
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.viewedByMe = false,
  });

  bool get isVideo => mediaType == 'video';
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      textOverlay: json['text_overlay'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Stories grouped by user (like Instagram)
class StoryGroup {
  final String userId;
  final String userName;
  final String? userAvatar;
  final List<StoryItem> stories;
  final bool allViewed;
  final bool isMyStory;

  StoryGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.stories,
    this.allViewed = false,
    this.isMyStory = false,
  });

  StoryItem get latestStory => stories.last;
  int get totalViews => stories.fold(0, (sum, s) => sum + s.viewCount);
}