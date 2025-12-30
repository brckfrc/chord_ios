import '../auth/user_dto.dart';
import 'message_dto.dart';

/// Direct Message DTO (from backend DirectMessageDto)
class DirectMessageDto {
  final String id;
  final String channelId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;

  // Sender information
  final UserDto? sender;

  DirectMessageDto({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.sender,
  });

  factory DirectMessageDto.fromJson(Map<String, dynamic> json) {
    return DirectMessageDto(
      id: json['id']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'].toString())
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      sender: json['sender'] != null
          ? UserDto.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'senderId': senderId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      'isDeleted': isDeleted,
      if (sender != null) 'sender': sender!.toJson(),
    };
  }

  /// Convert DirectMessageDto to MessageDto for compatibility with existing UI components
  /// This allows us to reuse MessageList, MessageItem, etc. without modification
  MessageDto toMessageDto() {
    return MessageDto(
      id: id,
      channelId: channelId,
      userId: senderId, // Map senderId to userId
      content: content,
      createdAt: createdAt,
      editedAt: editedAt,
      user: sender, // Map sender to user
      attachments: null, // DM messages don't have attachments in DirectMessageDto
      embeds: null, // DM messages don't have embeds in DirectMessageDto
      replyToMessageId: null, // DM messages don't support replies in DirectMessageDto
      replyToMessage: null,
      isPending: false,
    );
  }
}
