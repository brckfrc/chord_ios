import 'package:flutter/material.dart';
import '../../models/auth/user_status.dart';

/// User status indicator widget (badge on avatar)
class UserStatusIndicator extends StatelessWidget {
  final UserStatus status;
  final double size; // Badge size (default: 12)

  const UserStatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
  });

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF23A55A); // Green
      case UserStatus.idle:
        return const Color(0xFFF0B232); // Yellow
      case UserStatus.dnd:
        return const Color(0xFFF23F43); // Red
      case UserStatus.invisible:
      case UserStatus.offline:
        return const Color(0xFF80848E); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    );
  }
}

/// Avatar with status indicator
class AvatarWithStatus extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final UserStatus status;
  final double avatarRadius;
  final double statusSize;

  const AvatarWithStatus({
    super.key,
    this.avatarUrl,
    required this.displayName,
    required this.status,
    this.avatarRadius = 20,
    this.statusSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: avatarRadius * 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        // Status indicator (bottom right)
        Positioned(
          right: 0,
          bottom: 0,
          child: UserStatusIndicator(
            status: status,
            size: statusSize,
          ),
        ),
      ],
    );
  }
}

