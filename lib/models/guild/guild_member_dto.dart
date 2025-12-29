import '../auth/user_dto.dart';

/// Guild Member DTO
class GuildMemberDto {
  final String guildId;
  final String userId;
  final DateTime joinedAt;
  final String? nickname;
  final String role; // Owner, Admin, Member
  final UserDto? user;

  GuildMemberDto({
    required this.guildId,
    required this.userId,
    required this.joinedAt,
    this.nickname,
    this.role = 'Member',
    this.user,
  });

  factory GuildMemberDto.fromJson(Map<String, dynamic> json) {
    return GuildMemberDto(
      guildId: json['guildId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'].toString())
          : DateTime.now(),
      nickname: json['nickname'] as String?,
      role: json['role'] as String? ?? 'Member',
      user: json['user'] != null
          ? UserDto.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guildId': guildId,
      'userId': userId,
      'joinedAt': joinedAt.toIso8601String(),
      if (nickname != null) 'nickname': nickname,
      'role': role,
      if (user != null) 'user': user!.toJson(),
    };
  }

  /// Get display name (nickname or user displayName or username)
  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    }
    return user?.displayName ?? user?.username ?? 'Unknown';
  }

  /// Get username for mention (@username)
  String get username {
    return user?.username ?? 'unknown';
  }
}
