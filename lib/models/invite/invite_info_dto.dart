import '../auth/user_dto.dart';

/// Invite Info DTO (from backend InviteInfoDto)
class InviteInfoDto {
  final String code;
  final String guildId;
  final String guildName;
  final String? guildIconUrl;
  final UserDto? createdBy;
  final int memberCount;
  final DateTime? expiresAt;
  final int? maxUses;
  final int uses;
  final DateTime createdAt;

  InviteInfoDto({
    required this.code,
    required this.guildId,
    required this.guildName,
    this.guildIconUrl,
    this.createdBy,
    required this.memberCount,
    this.expiresAt,
    this.maxUses,
    required this.uses,
    required this.createdAt,
  });

  factory InviteInfoDto.fromJson(Map<String, dynamic> json) {
    return InviteInfoDto(
      code: json['code']?.toString() ?? '',
      guildId: json['guildId']?.toString() ?? '',
      guildName: json['guildName'] as String? ?? '',
      guildIconUrl: json['guildIconUrl'] as String?,
      createdBy: json['createdBy'] != null
          ? UserDto.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      memberCount: json['memberCount'] as int? ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'].toString())
          : null,
      maxUses: json['maxUses'] as int?,
      uses: json['uses'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'guildId': guildId,
      'guildName': guildName,
      if (guildIconUrl != null) 'guildIconUrl': guildIconUrl,
      if (createdBy != null) 'createdBy': createdBy!.toJson(),
      'memberCount': memberCount,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (maxUses != null) 'maxUses': maxUses,
      'uses': uses,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Check if invite is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if invite has reached max uses
  bool get hasReachedMaxUses {
    if (maxUses == null) return false;
    return uses >= maxUses!;
  }
}
