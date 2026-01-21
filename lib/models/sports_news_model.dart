/// Model pentru o știre sportivă
class SportsNews {
  final String id;
  final String title;
  final String? content;
  final String? summary;
  final String? imageUrl;
  final String sportType; // 'football', 'f1', 'tennis'
  final String? source;
  final bool isPublished;
  final DateTime publishedAt;
  final DateTime createdAt;

  SportsNews({
    required this.id,
    required this.title,
    this.content,
    this.summary,
    this.imageUrl,
    required this.sportType,
    this.source,
    this.isPublished = true,
    required this.publishedAt,
    required this.createdAt,
  });

  factory SportsNews.fromJson(Map<String, dynamic> json) {
    return SportsNews(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      summary: json['summary'] as String?,
      imageUrl: json['image_url'] as String?,
      sportType: json['sport_type'] as String,
      source: json['source'] as String?,
      isPublished: json['is_published'] as bool? ?? true,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'summary': summary,
      'image_url': imageUrl,
      'sport_type': sportType,
      'source': source,
      'is_published': isPublished,
    };
  }

  /// Numele complet al sportului
  String get sportName {
    switch (sportType) {
      case 'football':
        return 'Fotbal';
      case 'f1':
        return 'Formula 1';
      case 'tennis':
        return 'Tenis';
      default:
        return sportType;
    }
  }

  /// Timpul de când a fost publicată
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inMinutes < 60) {
      return 'Acum ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Acum ${difference.inHours} ore';
    } else if (difference.inDays < 7) {
      return 'Acum ${difference.inDays} zile';
    } else {
      return '${publishedAt.day}/${publishedAt.month}/${publishedAt.year}';
    }
  }
}