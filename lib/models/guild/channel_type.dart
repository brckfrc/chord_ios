/// Channel type enum
enum ChannelType {
  text(0),
  voice(1);

  final int value;
  const ChannelType(this.value);

  static ChannelType fromInt(int value) {
    return ChannelType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChannelType.text,
    );
  }

  static ChannelType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'text':
        return ChannelType.text;
      case 'voice':
        return ChannelType.voice;
      default:
        return ChannelType.text;
    }
  }

  static ChannelType fromDynamic(dynamic value) {
    if (value is int) {
      return fromInt(value);
    } else if (value is String) {
      return fromString(value);
    }
    return ChannelType.text;
  }
}

