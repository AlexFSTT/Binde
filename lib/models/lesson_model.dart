/// Model pentru o lecție din secțiunea Learn
class Lesson {
  final String id;
  final String title;
  final String? description;
  final String? content;
  final String? category;
  final String? imageUrl;
  final int durationMinutes;
  final int orderIndex;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lesson({
    required this.id,
    required this.title,
    this.description,
    this.content,
    this.category,
    this.imageUrl,
    this.durationMinutes = 0,
    this.orderIndex = 0,
    this.isPublished = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creează un obiect Lesson din JSON (datele din Supabase)
  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      content: json['content'] as String?,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      orderIndex: json['order_index'] as int? ?? 0,
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convertește obiectul Lesson în JSON (pentru trimitere la Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'category': category,
      'image_url': imageUrl,
      'duration_minutes': durationMinutes,
      'order_index': orderIndex,
      'is_published': isPublished,
    };
  }

  /// Returnează durata formatată (ex: "10 min")
  String get formattedDuration {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    } else {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }
}