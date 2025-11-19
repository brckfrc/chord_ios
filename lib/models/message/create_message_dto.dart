/// Create message request DTO
class CreateMessageDto {
  final String content;
  final String? replyToMessageId;
  final List<String>? attachmentIds;

  CreateMessageDto({
    required this.content,
    this.replyToMessageId,
    this.attachmentIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (attachmentIds != null && attachmentIds!.isNotEmpty)
        'attachmentIds': attachmentIds,
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

