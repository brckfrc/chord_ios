import 'package:flutter/foundation.dart';

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
    try {
      if (value.isEmpty) {
        debugPrint(
          '[UserStatus.fromString] Empty string provided, returning offline',
        );
        return UserStatus.offline;
      }

      final result = UserStatus.values.firstWhere(
        (status) => status.value == value || status.name == value,
        orElse: () => UserStatus.offline,
      );

      if (result == UserStatus.offline &&
          !value.toLowerCase().contains('offline') &&
          !UserStatus.values.any((s) => s.value == value || s.name == value)) {
        debugPrint(
          '[UserStatus.fromString] Warning: Unknown status string "$value", returning offline',
        );
      }

      return result;
    } catch (e) {
      debugPrint(
        '[UserStatus.fromString] Error parsing status string "$value": $e',
      );
      return UserStatus.offline;
    }
  }

  /// Parse status from int value (0-4)
  /// Accepts dynamic to handle cases where Dio might parse int as String
  static UserStatus fromInt(dynamic value) {
    try {
      int? intValue;

      // Runtime type check - handle different input types
      if (value is int) {
        intValue = value;
      } else if (value is String) {
        // Dio might parse int as String, try to parse it
        intValue = int.tryParse(value);
        if (intValue == null) {
          debugPrint(
            '[UserStatus.fromInt] Warning: Failed to parse String "$value" as int, returning offline',
          );
          return UserStatus.offline;
        }
      } else if (value is num) {
        // Handle double/num types
        intValue = value.toInt();
      } else if (value != null) {
        // Try to convert to int via string representation
        try {
          intValue = int.tryParse(value.toString());
        } catch (e) {
          debugPrint(
            '[UserStatus.fromInt] Error: Failed to convert value to int: $value (type: ${value.runtimeType}), error: $e',
          );
          return UserStatus.offline;
        }
      }

      // Validate bounds before accessing array
      if (intValue != null &&
          intValue >= 0 &&
          intValue < UserStatus.values.length) {
        return UserStatus.values[intValue];
      } else {
        debugPrint(
          '[UserStatus.fromInt] Warning: Index out of bounds: $intValue (valid range: 0-${UserStatus.values.length - 1}), returning offline',
        );
        return UserStatus.offline;
      }
    } catch (e) {
      debugPrint(
        '[UserStatus.fromInt] Error: Unexpected error parsing status: $value (type: ${value.runtimeType}), error: $e',
      );
      return UserStatus.offline;
    }
  }

  static UserStatus fromDynamic(dynamic value) {
    try {
      // Debug: Log incoming value type and value
      debugPrint(
        '[UserStatus.fromDynamic] Received value: $value (type: ${value?.runtimeType ?? 'null'})',
      );

      if (value == null) {
        debugPrint('[UserStatus.fromDynamic] Value is null, returning offline');
        return UserStatus.offline;
      }

      // Handle int type - ensure it's actually an int
      if (value is int) {
        debugPrint('[UserStatus.fromDynamic] Value is int: $value');
        return fromInt(value);
      }

      // Handle String type - try parsing as int first, then as string
      if (value is String) {
        debugPrint('[UserStatus.fromDynamic] Value is String: "$value"');
        // Try to parse as integer first (e.g., "0", "1", "2")
        final intValue = int.tryParse(value);
        if (intValue != null) {
          // Successfully parsed as int, use fromInt
          debugPrint(
            '[UserStatus.fromDynamic] Parsed String as int: $intValue',
          );
          return fromInt(intValue);
        }
        // Not a numeric string, try as status string
        debugPrint(
          '[UserStatus.fromDynamic] String is not numeric, trying as status string',
        );
        return fromString(value);
      }

      // Handle other types - try to convert to int first
      try {
        // First, try to convert directly to int if possible
        if (value is num) {
          debugPrint(
            '[UserStatus.fromDynamic] Value is num: $value, converting to int',
          );
          final intValue = value.toInt();
          return fromInt(intValue);
        }

        // Try parsing string representation as int
        final stringValue = value.toString();
        debugPrint(
          '[UserStatus.fromDynamic] Converting to string: "$stringValue"',
        );
        final intValue = int.tryParse(stringValue);
        if (intValue != null) {
          debugPrint(
            '[UserStatus.fromDynamic] Parsed string representation as int: $intValue',
          );
          return fromInt(intValue);
        }

        // If not a number, try as string
        debugPrint(
          '[UserStatus.fromDynamic] String representation is not numeric, trying as status string',
        );
        return fromString(stringValue);
      } catch (e) {
        debugPrint('[UserStatus.fromDynamic] Error during conversion: $e');
        return UserStatus.offline;
      }
    } catch (e, stackTrace) {
      // If all conversions fail, return offline
      debugPrint('[UserStatus.fromDynamic] Unexpected error: $e');
      debugPrint('[UserStatus.fromDynamic] Stack trace: $stackTrace');
      return UserStatus.offline;
    }
  }
}
