/// Create message request DTO
/// Backend format: { content, attachments: string? (JSON string) }
class CreateMessageDto {
  final String content;
  final String? replyToMessageId;
  final String? attachments; // JSON string format: "[{url, type, size, name, duration}]"

  CreateMessageDto({
    required this.content,
    this.replyToMessageId,
    this.attachments,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (attachments != null && attachments!.isNotEmpty)
        'attachments': attachments,
    };
  }
}

/// Update message request DTO
class UpdateMessageDto {
  final String content;

  UpdateMessageDto({required this.content});

  Map<String, dynamic> toJson() {
    return {
      'content': content,
    };
  }
}

