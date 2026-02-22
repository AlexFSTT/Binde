/// Tipuri de mesaje suportate
enum MessageType {
  text,
  image,
  video,
  file;

  static MessageType fromString(String? value) {
    switch (value) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'file': return MessageType.file;
      default: return MessageType.text;
    }
  }

  String get value {
    switch (this) {
      case MessageType.text: return 'text';
      case MessageType.image: return 'image';
      case MessageType.video: return 'video';
      case MessageType.file: return 'file';
    }
  }

  bool get isMedia => this == MessageType.image || this == MessageType.video;
}

/// Model pentru un mesaj într-o conversație
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType messageType;
  final String? attachmentUrl;
  final String? fileName;
  final int? fileSize;
  final bool isRead;
  final DateTime createdAt;

  // Informații suplimentare despre expeditor
  final String? senderName;
  final String? senderAvatar;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = MessageType.text,
    this.attachmentUrl,
    this.fileName,
    this.fileSize,
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: MessageType.fromString(json['message_type'] as String?),
      attachmentUrl: json['attachment_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType.value,
      'attachment_url': attachmentUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'is_read': isRead,
    };
  }

  String getFormattedTime() {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool isMine(String currentUserId) => senderId == currentUserId;

  /// Human-readable file size
  String get formattedFileSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageType? messageType,
    String? attachmentUrl,
    String? fileName,
    int? fileSize,
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
      messageType: messageType ?? this.messageType,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }
}