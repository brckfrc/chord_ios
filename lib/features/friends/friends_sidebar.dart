import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dm_provider.dart';
import '../../models/dm/dm_dto.dart';
import '../../models/auth/user_status.dart';
import '../../shared/widgets/app_loading.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final dmState = ref.watch(dmProvider);
    final location = GoRouterState.of(context).uri.path;
    final isFriendsActive = location == '/me';

    // Extract unique users from DMs to simulate a friends list
    final friends = dmState.dms
        .map((dm) => dm.otherUser)
        .where((user) => user != null)
        .toSet()
        .toList();

    // Sort friends: Online > Idle > DND > Offline > Invisible
    friends.sort((a, b) {
      final statusOrder = {
        UserStatus.online: 0,
        UserStatus.idle: 1,
        UserStatus.dnd: 2,
        UserStatus.offline: 3,
        UserStatus.invisible: 4,
      };
      final aOrder = statusOrder[a!.status] ?? 3;
      final bOrder = statusOrder[b!.status] ?? 3;
      return aOrder.compareTo(bOrder);
    });

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
                  bottom: BorderSide(
                    color: const Color(0xFF1F2023),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_alt,
                    size: 20, // Match Guild Header icon size
                    color: isFriendsActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
                ],
              ),
            ),
          ),
          // Horizontal Friend List
          if (friends.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF1F2023),
                    width: 1,
                  ),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: friends.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final friend = friends[index]!;
                  return Column(
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
                                  color: Theme.of(context).colorScheme.onPrimary,
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
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
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
                                fontSize: 11, // Match Channel Sidebar Section Header
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...dmState.dms.map((dm) => _DMItem(
                                dm: dm,
                                isSelected: dmState.selectedDMId == dm.id,
                                onTap: () {
                                  ref.read(dmProvider.notifier).setSelectedDM(dm.id);
                                  context.go('/me/dm/${dm.id}');
                                },
                              )),
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
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
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

