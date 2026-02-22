/// Model pentru notificări cu separare pe categorii
class NotificationModel {
  final String id;
  final String userId;
  final String type; // 'friend_request'
  final String category; // 'chat'
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.title,
    required this.message,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      category: json['category'] as String? ?? _inferCategory(json['type'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'category': category,
      'title': title,
      'message': message,
      'data': data,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? category,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Inferă categoria din tip (pentru compatibilitate cu notificări vechi)
  static String _inferCategory(String type) {
    return 'chat';
  }
}