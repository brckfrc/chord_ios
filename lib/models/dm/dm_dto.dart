import '../auth/user_dto.dart';

/// Direct Message DTO
class DMDto {
  final String id;
  final String userId;
  final String otherUserId;
  final UserDto? otherUser;
  final DMLastMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;

  DMDto({
    required this.id,
    required this.userId,
    required this.otherUserId,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory DMDto.fromJson(Map<String, dynamic> json) {
    return DMDto(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      otherUserId: json['otherUserId']?.toString() ?? '',
      otherUser: json['otherUser'] != null
          ? UserDto.fromJson(json['otherUser'])
          : null,
      lastMessage: json['lastMessage'] != null
          ? DMLastMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'otherUserId': otherUserId,
      'otherUser': otherUser?.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// DM Last Message DTO
class DMLastMessage {
  final String id;
  final String content;
  final DateTime createdAt;

  DMLastMessage({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory DMLastMessage.fromJson(Map<String, dynamic> json) {
    return DMLastMessage(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

