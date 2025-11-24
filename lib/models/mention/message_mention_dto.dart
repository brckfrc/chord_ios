import '../message/message_dto.dart';
import '../auth/user_dto.dart';

/// Message Mention DTO
class MessageMentionDto {
  final String id;
  final String messageId;
  final String mentionedUserId;
  final bool isRead;
  final DateTime createdAt;
  final MessageDto message;
  final UserDto mentionedUser;

  MessageMentionDto({
    required this.id,
    required this.messageId,
    required this.mentionedUserId,
    required this.isRead,
    required this.createdAt,
    required this.message,
    required this.mentionedUser,
  });

  factory MessageMentionDto.fromJson(Map<String, dynamic> json) {
    return MessageMentionDto(
      id: json['id']?.toString() ?? '',
      messageId: json['messageId']?.toString() ?? '',
      mentionedUserId: json['mentionedUserId']?.toString() ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      message: MessageDto.fromJson(json['message'] as Map<String, dynamic>),
      mentionedUser: UserDto.fromJson(
        json['mentionedUser'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'mentionedUserId': mentionedUserId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'message': message.toJson(),
      'mentionedUser': mentionedUser.toJson(),
    };
  }

  MessageMentionDto copyWith({
    String? id,
    String? messageId,
    String? mentionedUserId,
    bool? isRead,
    DateTime? createdAt,
    MessageDto? message,
    UserDto? mentionedUser,
  }) {
    return MessageMentionDto(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      mentionedUserId: mentionedUserId ?? this.mentionedUserId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      message: message ?? this.message,
      mentionedUser: mentionedUser ?? this.mentionedUser,
    );
  }
}

/// Unread Mention Count DTO
class UnreadMentionCountDto {
  final int count;

  UnreadMentionCountDto({required this.count});

  factory UnreadMentionCountDto.fromJson(Map<String, dynamic> json) {
    return UnreadMentionCountDto(
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
    };
  }
}




