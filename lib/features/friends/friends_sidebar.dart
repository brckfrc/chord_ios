import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dm_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/presence_provider.dart';
import '../../models/dm/dm_dto.dart';
import '../../models/auth/user_status.dart';
import '../../models/auth/user_dto.dart';
import '../../shared/widgets/app_loading.dart';
import 'add_friend_modal.dart';

/// Friends sidebar widget (shows DM list)
class FriendsSidebar extends ConsumerStatefulWidget {
  const FriendsSidebar({super.key});

  @override
  ConsumerState<FriendsSidebar> createState() => _FriendsSidebarState();
}

class _FriendsSidebarState extends ConsumerState<FriendsSidebar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dmProvider.notifier).fetchDMs();
      ref.read(friendsProvider.notifier).fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dmState = ref.watch(dmProvider);
    final friendsState = ref.watch(friendsProvider);
    final authState = ref.watch(authProvider);
    final presenceState = ref.watch(presenceProvider);
    final currentUserId = authState.user?.id ?? '';
    final location = GoRouterState.of(context).uri.path;
    final isFriendsActive = location == '/me';

    // Get friends from friends provider OR from DMs if friends list is empty
    final friends = <UserDto>[];
    final seenUserIds = <String>{};

    // First try to get from friends provider
    debugPrint('[FriendsSidebar] currentUserId: $currentUserId');
    for (final f in friendsState.friends) {
      debugPrint(
        '[FriendsSidebar] Friendship: id=${f.id}, requesterId=${f.requesterId}, addresseeId=${f.addresseeId}',
      );
      final user = f.getOtherUser(currentUserId);
      debugPrint(
        '[FriendsSidebar] getOtherUser result: ${user?.id ?? "null"}, name=${user?.displayName ?? user?.username ?? "null"}',
      );
      if (user != null && !seenUserIds.contains(user.id)) {
        seenUserIds.add(user.id);
        // Get current status: use presence state if available, otherwise use backend status
        final presenceStatus = presenceState.userStatuses[user.id];
        final currentStatus = presenceStatus ?? user.status;
        // Create a copy with updated status
        final updatedUser = user.copyWith(status: currentStatus);
        friends.add(updatedUser);
      }
    }

    // If friends list is empty or to supplement, get from DMs
    for (final dm in dmState.dms) {
      final otherUser = dm.otherUser;
      if (otherUser != null && !seenUserIds.contains(otherUser.id)) {
        seenUserIds.add(otherUser.id);
        // Get current status: use presence state if available, otherwise use backend status
        final presenceStatus = presenceState.userStatuses[otherUser.id];
        final currentStatus = presenceStatus ?? otherUser.status;
        // Create a copy with updated status
        final updatedUser = otherUser.copyWith(status: currentStatus);
        friends.add(updatedUser);
      }
    }

    // Sort friends: Online > Idle > DND > Offline > Invisible
    friends.sort((a, b) {
      final statusOrder = {
        UserStatus.online: 0,
        UserStatus.idle: 1,
        UserStatus.dnd: 2,
        UserStatus.offline: 3,
        UserStatus.invisible: 4,
      };
      final aOrder = statusOrder[a.status] ?? 3;
      final bOrder = statusOrder[b.status] ?? 3;
      return aOrder.compareTo(bOrder);
    });

    // Filter to show only active friends (online + idle)
    final activeFriends = friends
        .where(
          (f) => f.status == UserStatus.online || f.status == UserStatus.idle,
        )
        .toList();

    // Debug: Print status info
    debugPrint(
      '[FriendsSidebar] Friends from provider: ${friendsState.friends.length}',
    );
    debugPrint('[FriendsSidebar] DMs count: ${dmState.dms.length}');
    debugPrint('[FriendsSidebar] Total friends: ${friends.length}');
    debugPrint(
      '[FriendsSidebar] Active friends (online/idle): ${activeFriends.length}',
    );
    debugPrint(
      '[FriendsSidebar] Presence state userStatuses: ${presenceState.userStatuses}',
    );
    for (final dm in dmState.dms) {
      debugPrint(
        '[FriendsSidebar] DM: id=${dm.id}, otherUser=${dm.otherUser?.id ?? "null"}, otherUser name=${dm.otherUser?.displayName ?? dm.otherUser?.username ?? "null"}',
      );
    }
    for (final friend in friends) {
      debugPrint(
        '[FriendsSidebar] Friend: ${friend.displayName ?? friend.username}, Status: ${friend.status}',
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // FRIENDS Header (Styled like Guild Header)
          InkWell(
            onTap: () {
              ref.read(dmProvider.notifier).setSelectedDM(null);
              context.go('/me');
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: const Color(0xFF1F2023), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_alt,
                    size: 20, // Match Guild Header icon size
                    color: isFriendsActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Friends', // Capitalized like Guild Name
                      style: const TextStyle(
                        fontSize: 16, // Match Guild Header font size
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Pending requests badge
                  if (friendsState.pendingCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        friendsState.pendingCount > 99
                            ? '99+'
                            : friendsState.pendingCount.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Add Friend button
                  IconButton(
                    icon: const Icon(Icons.person_add, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withOpacity(0.7),
                        builder: (context) => AddFriendModal(
                          open: true,
                          onOpenChange: (open) {
                            if (!open) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      );
                    },
                    tooltip: 'Add Friend',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
          // Horizontal Active Friends List (Online + Idle)
          if (activeFriends.isNotEmpty)
            Container(
              height: 85,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1F2023), width: 1),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: activeFriends.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final friend = activeFriends[index];
                  return InkWell(
                    onTap: () async {
                      // Mevcut DM'lerde bu kullanıcıyla DM var mı kontrol et
                      final dmState = ref.read(dmProvider);
                      final existingDMs = dmState.dms
                          .where((dm) => dm.otherUserId == friend.id)
                          .toList();
                      final existingDM =
                          existingDMs.isNotEmpty ? existingDMs.first : null;

                      if (existingDM != null) {
                        // Mevcut DM varsa, o DM'e git
                        ref.read(dmProvider.notifier).setSelectedDM(existingDM.id);
                        context.go('/me/dm/${existingDM.id}');
                      } else {
                        // DM yoksa, yeni DM oluştur
                        try {
                          final newDM =
                              await ref.read(dmProvider.notifier).createDM(friend.id);
                          if (newDM != null) {
                            // DM listesini yenile (yeni oluşturulan DM'in görünmesi için)
                            await ref.read(dmProvider.notifier).fetchDMs();
                            ref.read(dmProvider.notifier).setSelectedDM(newDM.id);
                            context.go('/me/dm/${newDM.id}');
                          } else {
                            // Error state - inform user
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to create DM. Please try again.',
                                  ),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Exception state - inform user
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    (friend.displayName?.isNotEmpty ?? false)
                                        ? friend.displayName![0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(friend.status),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            friend.displayName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // Direct Messages Section
          Expanded(
            child: dmState.isLoading
                ? const Center(child: AppLoading())
                : dmState.dms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No DMs yet',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          'DIRECT MESSAGES',
                          style: TextStyle(
                            fontSize:
                                11, // Match Channel Sidebar Section Header
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...dmState.dms.map(
                        (dm) => _DMItem(
                          dm: dm,
                          isSelected: dmState.selectedDMId == dm.id,
                          onTap: () {
                            ref.read(dmProvider.notifier).setSelectedDM(dm.id);
                            context.go('/me/dm/${dm.id}');
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.idle:
        return Colors.yellow;
      case UserStatus.dnd:
        return Colors.red;
      case UserStatus.invisible:
      case UserStatus.offline:
        return Colors.grey;
    }
  }
}

class _DMItem extends StatelessWidget {
  final DMDto dm;
  final bool isSelected;
  final VoidCallback onTap;

  const _DMItem({
    required this.dm,
    required this.isSelected,
    required this.onTap,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dateTime.day}/${dateTime.month}';
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.idle:
        return Colors.yellow;
      case UserStatus.dnd:
        return Colors.red;
      case UserStatus.invisible:
      case UserStatus.offline:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = dm.otherUser;
    if (otherUser == null) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 42, // Slightly taller than channel items for avatar
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                Container(
                  width: 32, // Smaller avatar for list
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (otherUser.displayName?.isNotEmpty ?? false)
                          ? otherUser.displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getStatusColor(otherUser.status),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Name and last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUser.displayName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dm.lastMessage != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(dm.lastMessage!.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (dm.lastMessage != null)
                    Text(
                      dm.lastMessage?.content ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            if (dm.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  dm.unreadCount > 99 ? '99+' : dm.unreadCount.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
