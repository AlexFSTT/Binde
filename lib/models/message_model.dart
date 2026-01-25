/// Model pentru un mesaj într-o conversație
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  // Informații suplimentare despre expeditor (încărcate din profiles)
  final String? senderName;
  final String? senderAvatar;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  /// Creează un obiect Message din JSON (datele din Supabase)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }

  /// Convertește obiectul Message în JSON (pentru trimitere la Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'is_read': isRead,
    };
  }

  /// Returnează timpul formatat pentru mesaj
  String getFormattedTime() {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Verifică dacă mesajul este al utilizatorului curent
  bool isMine(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Creează o copie a mesajului cu informații actualizate
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
    String? senderName,
    String? senderAvatar,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }
}