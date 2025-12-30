/// Voice token request DTO
class VoiceTokenRequestDto {
  final String channelId;

  VoiceTokenRequestDto({
    required this.channelId,
  });

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
    };
  }
}

/// Voice token response DTO (from backend)
class VoiceTokenResponseDto {
  final String token;
  final String url;
  final String roomName;
  final String? participantId;

  VoiceTokenResponseDto({
    required this.token,
    required this.url,
    required this.roomName,
    this.participantId,
  });

  factory VoiceTokenResponseDto.fromJson(Map<String, dynamic> json) {
    return VoiceTokenResponseDto(
      token: json['token'] as String? ?? json['liveKitToken'] as String,
      url: json['url'] as String? ?? json['liveKitUrl'] as String,
      roomName: json['roomName'] as String,
      participantId: json['participantId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'url': url,
      'roomName': roomName,
      if (participantId != null) 'participantId': participantId,
    };
  }
}
