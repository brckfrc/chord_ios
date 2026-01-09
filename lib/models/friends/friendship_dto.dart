import '../auth/user_dto.dart';

/// Friendship status enum
enum FriendshipStatus {
  pending,
  accepted,
  blocked;

  static FriendshipStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.pending;
    }
  }

  String get value {
    switch (this) {
      case FriendshipStatus.pending:
        return 'Pending';
      case FriendshipStatus.accepted:
        return 'Accepted';
      case FriendshipStatus.blocked:
        return 'Blocked';
    }
  }
}

/// Friendship DTO
class FriendshipDto {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final UserDto? requester;
  final UserDto? addressee;

  FriendshipDto({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.requester,
    this.addressee,
  });

  factory FriendshipDto.fromJson(Map<String, dynamic> json) {
    return FriendshipDto(
      id: json['id']?.toString() ?? '',
      requesterId: json['requesterId']?.toString() ?? '',
      addresseeId: json['addresseeId']?.toString() ?? '',
      status: json['status'] != null
          ? FriendshipStatus.fromString(json['status'].toString())
          : FriendshipStatus.pending,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'].toString())
          : null,
      requester: json['requester'] != null
          ? UserDto.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      addressee: json['addressee'] != null
          ? UserDto.fromJson(json['addressee'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'addresseeId': addresseeId,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      if (requester != null) 'requester': requester!.toJson(),
      if (addressee != null) 'addressee': addressee!.toJson(),
    };
  }

  /// Get the other user in the friendship (for current user)
  UserDto? getOtherUser(String currentUserId) {
    if (requesterId == currentUserId) {
      return addressee;
    } else if (addresseeId == currentUserId) {
      return requester;
    }
    return null;
  }

  /// Create a copy with updated fields
  FriendshipDto copyWith({
    String? id,
    String? requesterId,
    String? addresseeId,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    UserDto? requester,
    UserDto? addressee,
  }) {
    return FriendshipDto(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      addresseeId: addresseeId ?? this.addresseeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      requester: requester ?? this.requester,
      addressee: addressee ?? this.addressee,
    );
  }
}

/// Friend request DTO (for sending friend requests)
class FriendRequestDto {
  final String userId;

  FriendRequestDto({required this.userId});

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
    };
  }
}
