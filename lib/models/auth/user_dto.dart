import 'user_status.dart';

/// User DTO
class UserDto {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final UserStatus status;
  final String? customStatus;

  UserDto({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.lastSeenAt,
    required this.status,
    this.customStatus,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'].toString())
          : null,
      status: UserStatus.fromDynamic(json['status']),
      customStatus: json['customStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
      'status': status.value,
      if (customStatus != null) 'customStatus': customStatus,
    };
  }

  /// Create a copy of this user with updated fields
  UserDto copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    UserStatus? status,
    String? customStatus,
  }) {
    return UserDto(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      status: status ?? this.status,
      customStatus: customStatus ?? this.customStatus,
    );
  }
}
