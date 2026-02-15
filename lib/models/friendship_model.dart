/// Model pentru relațiile de prietenie
class FriendshipModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Populate info about other user (celălalt participant)
  String? otherUserId;
  String? otherUserName;
  String? otherUserAvatar;
  bool? otherUserIsOnline; // ✅ Status online/offline

  FriendshipModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.otherUserIsOnline, // ✅ ADĂUGAT
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helpers pentru status
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
}

/// Model pentru utilizatori blocați
class BlockModel {
  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;
  
  // Populate info despre utilizatorul blocat
  String? blockedUserName;
  String? blockedUserAvatar;

  BlockModel({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
    this.blockedUserName,
    this.blockedUserAvatar,
  });

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    return BlockModel(
      id: json['id'] as String,
      blockerId: json['blocker_id'] as String,
      blockedId: json['blocked_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}