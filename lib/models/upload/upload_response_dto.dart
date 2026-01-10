/// Upload response DTO from backend
class UploadResponseDto {
  final String id;
  final String url;
  final String? fileName;
  final String? contentType;
  final int? fileSize;
  final String? type; // "image", "video", "document"
  final int? duration; // Video için süre (saniye)

  UploadResponseDto({
    required this.id,
    required this.url,
    this.fileName,
    this.contentType,
    this.fileSize,
    this.type,
    this.duration,
  });

  factory UploadResponseDto.fromJson(Map<String, dynamic> json) {
    return UploadResponseDto(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String,
      fileName: json['fileName'] as String?,
      contentType: json['contentType'] as String?,
      fileSize: json['fileSize'] as int?,
      type: json['type'] as String?,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (fileName != null) 'fileName': fileName,
      if (contentType != null) 'contentType': contentType,
      if (fileSize != null) 'fileSize': fileSize,
      if (type != null) 'type': type,
      if (duration != null) 'duration': duration,
    };
  }
}
