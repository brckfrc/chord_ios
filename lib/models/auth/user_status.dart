/// User status enum
enum UserStatus {
  online('Online'),
  idle('Idle'),
  dnd('DoNotDisturb'),
  invisible('Invisible'),
  offline('Offline');

  final String value;
  const UserStatus(this.value);

  static UserStatus fromString(String value) {
    return UserStatus.values.firstWhere(
      (status) => status.value == value || status.name == value,
      orElse: () => UserStatus.offline,
    );
  }

  static UserStatus fromInt(int value) {
    if (value >= 0 && value < UserStatus.values.length) {
      return UserStatus.values[value];
    }
    return UserStatus.offline;
  }

  static UserStatus fromDynamic(dynamic value) {
    if (value == null) {
      return UserStatus.offline;
    }
    
    if (value is int) {
      return fromInt(value);
    }
    
    if (value is String) {
      // Try to parse as integer first
      final intValue = int.tryParse(value);
      if (intValue != null) {
        return fromInt(intValue);
      }
      return fromString(value);
    }
    
    // Try to convert to string and parse
    try {
      final intValue = int.tryParse(value.toString());
      if (intValue != null) {
        return fromInt(intValue);
      }
    } catch (_) {
      // Ignore
    }
    
    return UserStatus.offline;
  }
}
