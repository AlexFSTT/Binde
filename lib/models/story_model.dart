import 'dart:convert';

/// A positioned overlay on a story (text or emoji)
class StoryOverlay {
  final String type; // 'text' or 'emoji'
  final String content;
  final double x; // 0.0-1.0 relative position
  final double y;
  final double rotation; // radians
  final double scale;
  // Text-specific
  final String? color; // hex
  final double? fontSize;
  final bool? hasBg; // background behind text

  StoryOverlay({
    required this.type,
    required this.content,
    this.x = 0.5,
    this.y = 0.5,
    this.rotation = 0,
    this.scale = 1.0,
    this.color,
    this.fontSize,
    this.hasBg,
  });

  bool get isText => type == 'text';
  bool get isEmoji => type == 'emoji';

  Map<String, dynamic> toJson() => {
        'type': type,
        'content': content,
        'x': x,
        'y': y,
        'rotation': rotation,
        'scale': scale,
        if (color != null) 'color': color,
        if (fontSize != null) 'fontSize': fontSize,
        if (hasBg != null) 'hasBg': hasBg,
      };

  factory StoryOverlay.fromJson(Map<String, dynamic> json) => StoryOverlay(
        type: json['type'] as String,
        content: json['content'] as String,
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        color: json['color'] as String?,
        fontSize: (json['fontSize'] as num?)?.toDouble(),
        hasBg: json['hasBg'] as bool?,
      );

  StoryOverlay copyWith({
    double? x,
    double? y,
    double? rotation,
    double? scale,
  }) =>
      StoryOverlay(
        type: type,
        content: content,
        x: x ?? this.x,
        y: y ?? this.y,
        rotation: rotation ?? this.rotation,
        scale: scale ?? this.scale,
        color: color,
        fontSize: fontSize,
        hasBg: hasBg,
      );
}

/// Story reaction types
class StoryReactionType {
  static const String heart = 'heart';
  static const String haha = 'haha';
  static const String like = 'like';
  static const String smile = 'smile';

  static const List<String> all = [heart, haha, like, smile];

  static String emoji(String type) {
    switch (type) {
      case heart: return '❤️';
      case haha: return '😂';
      case like: return '👍';
      case smile: return '😊';
      default: return '❤️';
    }
  }
}

/// A single story item
class StoryItem {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType;
  final String? textOverlay; // legacy — kept for backwards compat
  final List<StoryOverlay> overlays;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final bool viewedByMe;
  final int reactionCount;
  final String? myReaction;

  StoryItem({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.textOverlay,
    this.overlays = const [],
    this.locationName,
    this.locationLat,
    this.locationLng,
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.viewedByMe = false,
    this.reactionCount = 0,
    this.myReaction,
  });

  bool get isVideo => mediaType == 'video';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasLocation => locationName != null && locationName!.isNotEmpty;

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    List<StoryOverlay> parsedOverlays = [];
    if (json['overlays'] != null) {
      try {
        final overlayData = json['overlays'] is String
            ? jsonDecode(json['overlays'] as String) as List
            : json['overlays'] as List;
        parsedOverlays = overlayData
            .map((o) => StoryOverlay.fromJson(o as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return StoryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      textOverlay: json['text_overlay'] as String?,
      overlays: parsedOverlays,
      locationName: json['location_name'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Stories grouped by user
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