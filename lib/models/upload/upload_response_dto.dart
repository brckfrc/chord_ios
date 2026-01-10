/// Upload response DTO from backend
/// Backend format: { url, type, size, name, duration, mimeType }
class UploadResponseDto {
  final String url;
  final String? name; // Backend'de "name", frontend'de "fileName" olarak kullanılabilir
  final String? mimeType; // Backend'de "mimeType", frontend'de "contentType" olarak kullanılabilir
  final int? size; // Backend'de "size", frontend'de "fileSize" olarak kullanılabilir
  final String? type; // "image", "video", "document"
  final int? duration; // Video için süre (saniye)

  UploadResponseDto({
    required this.url,
    this.name,
    this.mimeType,
    this.size,
    this.type,
    this.duration,
  });

  factory UploadResponseDto.fromJson(Map<String, dynamic> json) {
    return UploadResponseDto(
      url: json['url'] as String,
      name: json['name'] as String?,
      mimeType: json['mimeType'] as String?,
      size: json['size'] as int?,
      type: json['type'] as String?,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (name != null) 'name': name,
      if (mimeType != null) 'mimeType': mimeType,
      if (size != null) 'size': size,
      if (type != null) 'type': type,
      if (duration != null) 'duration': duration,
    };
  }

  // Convenience getters for backward compatibility
  String? get fileName => name;
  String? get contentType => mimeType;
  int? get fileSize => size;

  /// Convert to MessageAttachmentDto for pending messages
  /// Note: This creates a temporary attachment DTO for UI display
  /// The actual attachment will come from backend in the message response
  Map<String, dynamic> toAttachmentJson() {
    return {
      'url': url,
      'type': type ?? 'document',
      'size': size ?? 0,
      'name': name ?? '',
      if (duration != null) 'duration': duration,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }
}
