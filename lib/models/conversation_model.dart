/// Model pentru o conversație între doi utilizatori
class Conversation {
  final String id;
  final String participant1;
  final String participant2;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  // Informații suplimentare despre celălalt participant (încărcate din profiles)
  final String? otherUserName;
  final String? otherUserAvatar;

  Conversation({
    required this.id,
    required this.participant1,
    required this.participant2,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    this.otherUserName,
    this.otherUserAvatar,
  });

  /// Creează un obiect Conversation din JSON (datele din Supabase)
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      participant1: json['participant_1'] as String,
      participant2: json['participant_2'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      // Informațiile despre celălalt utilizator vor fi adăugate separat
      otherUserName: json['other_user_name'] as String?,
      otherUserAvatar: json['other_user_avatar'] as String?,
    );
  }

  /// Convertește obiectul Conversation în JSON (pentru trimitere la Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant_1': participant1,
      'participant_2': participant2,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }

  /// Returnează ID-ul celuilalt participant (nu al utilizatorului curent)
  String getOtherParticipantId(String currentUserId) {
    return participant1 == currentUserId ? participant2 : participant1;
  }

  /// Returnează timpul formatat pentru ultimul mesaj
  String getFormattedTime() {
    if (lastMessageAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt!);

    if (difference.inMinutes < 1) {
      return 'Acum';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}z';
    } else {
      return '${lastMessageAt!.day}/${lastMessageAt!.month}';
    }
  }

  /// Creează o copie a conversației cu informații actualizate
  Conversation copyWith({
    String? id,
    String? participant1,
    String? participant2,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String? otherUserName,
    String? otherUserAvatar,
  }) {
    return Conversation(
      id: id ?? this.id,
      participant1: participant1 ?? this.participant1,
      participant2: participant2 ?? this.participant2,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
    );
  }
}