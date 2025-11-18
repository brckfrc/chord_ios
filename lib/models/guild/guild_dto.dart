import '../auth/user_dto.dart';

/// Guild response DTO
class GuildDto {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserDto? owner;
  final int memberCount;
  final int channelCount;

  GuildDto({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.owner,
    required this.memberCount,
    required this.channelCount,
  });

  factory GuildDto.fromJson(Map<String, dynamic> json) {
    return GuildDto(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      ownerId: json['ownerId']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
      owner: json['owner'] != null
          ? UserDto.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      memberCount: json['memberCount'] as int? ?? 0,
      channelCount: json['channelCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (owner != null) 'owner': owner!.toJson(),
      'memberCount': memberCount,
      'channelCount': channelCount,
    };
  }
}

