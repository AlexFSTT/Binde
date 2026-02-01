/// Model pentru un comment la un Swirl
class SwirlComment {
  final String id;
  final String swirlId;
  final String userId;
  final String username;
  final String? userAvatar;
  final String text;
  final DateTime createdAt;

  SwirlComment({
    required this.id,
    required this.swirlId,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.text,
    required this.createdAt,
  });

  /// Creează un SwirlComment din JSON
  factory SwirlComment.fromJson(Map<String, dynamic> json) {
    return SwirlComment(
      id: json['id'] as String,
      swirlId: json['swirl_id'] as String,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Unknown',
      userAvatar: json['user_avatar'] as String?,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convertește SwirlComment în JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'swirl_id': swirlId,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar,
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Returnează timpul relativ (ex: "2h ago", "5m ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
