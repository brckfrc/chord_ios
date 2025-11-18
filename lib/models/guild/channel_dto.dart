import 'channel_type.dart';

/// Channel response DTO
class ChannelDto {
  final String id;
  final String guildId;
  final String name;
  final ChannelType type;
  final String? topic;
  final int position;
  final DateTime createdAt;

  ChannelDto({
    required this.id,
    required this.guildId,
    required this.name,
    required this.type,
    this.topic,
    required this.position,
    required this.createdAt,
  });

  factory ChannelDto.fromJson(Map<String, dynamic> json) {
    return ChannelDto(
      id: json['id']?.toString() ?? '',
      guildId: json['guildId']?.toString() ?? '',
      name: json['name'] as String,
      type: ChannelType.fromDynamic(json['type']),
      topic: json['topic'] as String?,
      position: json['position'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guildId': guildId,
      'name': name,
      'type': type.value,
      if (topic != null) 'topic': topic,
      'position': position,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

