/// Voice channel participant DTO
class VoiceParticipantDto {
  final String userId;
  final String username;
  final String? displayName;
  final bool isMuted;
  final bool isDeafened;
  final bool isSpeaking;
  final bool isVideoEnabled;
  final bool isLocal;

  VoiceParticipantDto({
    required this.userId,
    required this.username,
    this.displayName,
    this.isMuted = false,
    this.isDeafened = false,
    this.isSpeaking = false,
    this.isVideoEnabled = false,
    this.isLocal = false,
  });

  factory VoiceParticipantDto.fromJson(Map<String, dynamic> json) {
    return VoiceParticipantDto(
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      isMuted: json['isMuted'] as bool? ?? false,
      isDeafened: json['isDeafened'] as bool? ?? false,
      isSpeaking: json['isSpeaking'] as bool? ?? false,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? false,
      isLocal: json['isLocal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      if (displayName != null) 'displayName': displayName,
      'isMuted': isMuted,
      'isDeafened': isDeafened,
      'isSpeaking': isSpeaking,
      'isVideoEnabled': isVideoEnabled,
      'isLocal': isLocal,
    };
  }

  VoiceParticipantDto copyWith({
    String? userId,
    String? username,
    String? displayName,
    bool? isMuted,
    bool? isDeafened,
    bool? isSpeaking,
    bool? isVideoEnabled,
    bool? isLocal,
  }) {
    return VoiceParticipantDto(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}
