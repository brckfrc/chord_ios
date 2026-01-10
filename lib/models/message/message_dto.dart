import 'dart:convert';
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
  final bool isPending; // Frontend-only: true if message is pending (not yet sent to server)

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
    this.isPending = false,
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
      attachments: _parseAttachments(json['attachments']),
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
      // Note: isPending is not included in toJson as it's frontend-only
    };
  }

  /// Create a copy of this message with updated fields
  MessageDto copyWith({
    String? id,
    String? channelId,
    String? userId,
    String? content,
    DateTime? createdAt,
    DateTime? editedAt,
    UserDto? user,
    List<MessageAttachmentDto>? attachments,
    List<MessageEmbedDto>? embeds,
    String? replyToMessageId,
    MessageDto? replyToMessage,
    bool? isPending,
  }) {
    return MessageDto(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      user: user ?? this.user,
      attachments: attachments ?? this.attachments,
      embeds: embeds ?? this.embeds,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      isPending: isPending ?? this.isPending,
    );
  }

  /// Parse attachments from backend response
  /// Backend sends attachments as JSON string: "[{url, type, size, name, duration}]"
  /// or as array (for backward compatibility)
  static List<MessageAttachmentDto>? _parseAttachments(dynamic attachments) {
    print('🔍 [MessageDto] Parsing attachments: $attachments (type: ${attachments.runtimeType})');
    
    if (attachments == null) {
      print('⚠️ [MessageDto] Attachments is null');
      return null;
    }

    if (attachments is String) {
      print('📝 [MessageDto] Attachments is String, parsing JSON...');
      print('📝 [MessageDto] String content: $attachments');
      try {
        final decoded = jsonDecode(attachments);
        print('✅ [MessageDto] Decoded: $decoded (type: ${decoded.runtimeType})');
        if (decoded is List) {
          print('✅ [MessageDto] Decoded is List with ${decoded.length} items');
          final result = decoded
              .map((a) {
                print('📦 [MessageDto] Parsing attachment item: $a');
                return MessageAttachmentDto.fromJson(a as Map<String, dynamic>);
              })
              .toList();
          print('✅ [MessageDto] Successfully parsed ${result.length} attachments');
          return result;
        }
        print('⚠️ [MessageDto] Decoded is not a List, it is: ${decoded.runtimeType}');
        return null;
      } catch (e, stackTrace) {
        print('❌ [MessageDto] Parse error: $e');
        print('❌ [MessageDto] Stack trace: $stackTrace');
        return null;
      }
    } else if (attachments is List) {
      print('📋 [MessageDto] Attachments is already a List with ${attachments.length} items');
      final result = attachments
          .map((a) {
            print('📦 [MessageDto] Parsing attachment item: $a');
            return MessageAttachmentDto.fromJson(a as Map<String, dynamic>);
          })
          .toList();
      print('✅ [MessageDto] Successfully parsed ${result.length} attachments from List');
      return result;
    }
    print('⚠️ [MessageDto] Unknown attachments type: ${attachments.runtimeType}');
    return null;
  }
}

/// Message Attachment DTO
/// Backend format: { url, type, size, name, duration }
class MessageAttachmentDto {
  final String url;
  final String? fileName; // Backend'de "name"
  final String? contentType; // Backend'de "type" field'ından türetilir veya "mimeType"
  final int? fileSize; // Backend'de "size"
  final String? type; // "image", "video", "document"
  final int? duration; // Video için süre (saniye)

  MessageAttachmentDto({
    required this.url,
    this.fileName,
    this.contentType,
    this.fileSize,
    this.type,
    this.duration,
  });

  factory MessageAttachmentDto.fromJson(Map<String, dynamic> json) {
    // Backend formatı: { url, type, size, name, duration, mimeType? }
    // Frontend formatı: { url, fileName, contentType, fileSize, type?, duration? }
    
    print('📦 [MessageAttachmentDto] Parsing JSON: $json');
    print('📦 [MessageAttachmentDto] JSON keys: ${json.keys.toList()}');
    
    final backendType = json['type'] as String?;
    final backendMimeType = json['mimeType'] as String?;
    
    print('📦 [MessageAttachmentDto] type: $backendType, mimeType: $backendMimeType');
    
    // contentType'ı belirle: önce mimeType, sonra type'dan türet
    String? contentType;
    if (backendMimeType != null) {
      contentType = backendMimeType;
      print('📦 [MessageAttachmentDto] Using mimeType: $contentType');
    } else if (backendType != null) {
      // type'dan mimeType türet
      switch (backendType.toLowerCase()) {
        case 'image':
          contentType = 'image/jpeg'; // Default
          break;
        case 'video':
          contentType = 'video/mp4'; // Default
          break;
        case 'document':
          contentType = 'application/pdf'; // Default
          break;
      }
      print('📦 [MessageAttachmentDto] Derived contentType from type: $contentType');
    }

    final url = json['url'] as String;
    final fileName = json['name'] as String? ?? json['fileName'] as String?;
    final fileSize = json['size'] as int? ?? json['fileSize'] as int?;
    final duration = json['duration'] as int?;
    
    print('📦 [MessageAttachmentDto] Parsed: url=$url, fileName=$fileName, contentType=$contentType, fileSize=$fileSize, type=$backendType, duration=$duration');

    return MessageAttachmentDto(
      url: url,
      fileName: fileName,
      contentType: contentType ?? json['contentType'] as String?,
      fileSize: fileSize,
      type: backendType,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (fileName != null) 'fileName': fileName,
      if (contentType != null) 'contentType': contentType,
      if (fileSize != null) 'fileSize': fileSize,
      if (type != null) 'type': type,
      if (duration != null) 'duration': duration,
    };
  }

  // Backend compatibility: id field'ı yok, url'yi id olarak kullanabiliriz
  String get id => url;
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

