/// Model pentru un Swirl (video scurt TikTok-style) din secțiunea Swirls
/// Durata: minim 10 secunde, maxim 10 minute
class Swirl {
  final String id;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? category;
  final int durationSeconds; // Validare: 10-600 secunde
  final int viewsCount;
  final int likesCount;
  final bool isPublished;
  final DateTime createdAt;

  Swirl({
    required this.id,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.category,
    this.durationSeconds = 0,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.isPublished = true,
    required this.createdAt,
  });

  /// Validează durata video-ului pentru Swirls
  /// Minim: 10 secunde, Maxim: 10 minute (600 secunde)
  bool get isValidDuration {
    return durationSeconds >= 10 && durationSeconds <= 600;
  }

  /// Creează un Swirl din JSON
  factory Swirl.fromJson(Map<String, dynamic> json) {
    return Swirl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      category: json['category'] as String?,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convertește Swirl în JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'category': category,
      'duration_seconds': durationSeconds,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'is_published': isPublished,
    };
  }

  /// Returnează durata formatată (ex: "2:30")
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returnează vizualizările formatate (ex: "1.2K")
  String get formattedViews {
    if (viewsCount >= 1000000) {
      return '${(viewsCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewsCount >= 1000) {
      return '${(viewsCount / 1000).toStringAsFixed(1)}K';
    }
    return viewsCount.toString();
  }

  /// Returnează like-urile formatate
  String get formattedLikes {
    if (likesCount >= 1000000) {
      return '${(likesCount / 1000000).toStringAsFixed(1)}M';
    } else if (likesCount >= 1000) {
      return '${(likesCount / 1000).toStringAsFixed(1)}K';
    }
    return likesCount.toString();
  }
}
