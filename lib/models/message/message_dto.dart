import '../auth/user_dto.dart';

/// Message DTO
class MessageDto {
  final String id;
  final String channelId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final UserDto? user;
  final List<MessageAttachmentDto>? attachments;
  final List<MessageEmbedDto>? embeds;
  final String? replyToMessageId;
  final MessageDto? replyToMessage;

  MessageDto({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.user,
    this.attachments,
    this.embeds,
    this.replyToMessageId,
    this.replyToMessage,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    return MessageDto(
      id: json['id']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['authorId']?.toString() ?? '', // Backend'den authorId gelebilir
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'].toString())
          : (json['updatedAt'] != null // Backend'den updatedAt gelebilir
              ? DateTime.parse(json['updatedAt'].toString())
              : null),
      user: json['user'] != null
          ? UserDto.fromJson(json['user'] as Map<String, dynamic>)
          : (json['author'] != null // Backend'den author gelebilir
              ? UserDto.fromJson(json['author'] as Map<String, dynamic>)
              : null),
      attachments: json['attachments'] != null && json['attachments'] is List
          ? (json['attachments'] as List)
              .map((a) => MessageAttachmentDto.fromJson(a as Map<String, dynamic>))
              .toList()
          : null,
      embeds: json['embeds'] != null && json['embeds'] is List
          ? (json['embeds'] as List)
              .map((e) => MessageEmbedDto.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      replyToMessageId: json['replyToMessageId']?.toString(),
      replyToMessage: json['replyToMessage'] != null
          ? MessageDto.fromJson(json['replyToMessage'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'userId': userId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
      if (attachments != null)
        'attachments': attachments!.map((a) => a.toJson()).toList(),
      if (embeds != null) 'embeds': embeds!.map((e) => e.toJson()).toList(),
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToMessage != null) 'replyToMessage': replyToMessage!.toJson(),
    };
  }
}

/// Message Attachment DTO
class MessageAttachmentDto {
  final String id;
  final String url;
  final String? fileName;
  final String? contentType;
  final int? fileSize;

  MessageAttachmentDto({
    required this.id,
    required this.url,
    this.fileName,
    this.contentType,
    this.fileSize,
  });

  factory MessageAttachmentDto.fromJson(Map<String, dynamic> json) {
    return MessageAttachmentDto(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String,
      fileName: json['fileName'] as String?,
      contentType: json['contentType'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (fileName != null) 'fileName': fileName,
      if (contentType != null) 'contentType': contentType,
      if (fileSize != null) 'fileSize': fileSize,
    };
  }
}

/// Message Embed DTO
class MessageEmbedDto {
  final String? title;
  final String? description;
  final String? url;
  final String? thumbnailUrl;
  final String? imageUrl;
  final int? color;

  MessageEmbedDto({
    this.title,
    this.description,
    this.url,
    this.thumbnailUrl,
    this.imageUrl,
    this.color,
  });

  factory MessageEmbedDto.fromJson(Map<String, dynamic> json) {
    return MessageEmbedDto(
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      color: json['color'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (url != null) 'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (color != null) 'color': color,
    };
  }
}

