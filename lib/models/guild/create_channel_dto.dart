import 'channel_type.dart';

/// Create channel request DTO
class CreateChannelDto {
  final String name;
  final ChannelType type;
  final String? topic;

  CreateChannelDto({
    required this.name,
    this.type = ChannelType.text,
    this.topic,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.value,
      if (topic != null && topic!.isNotEmpty) 'topic': topic,
    };
  }
}

