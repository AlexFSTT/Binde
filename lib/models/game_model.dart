/// Model pentru un joc din secțiunea Games
class Game {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? category;
  final bool isAvailable;
  final DateTime createdAt;

  Game({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.category,
    this.isAvailable = true,
    required this.createdAt,
  });

  /// Creează un Game din JSON
  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convertește Game în JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'is_available': isAvailable,
    };
  }
}