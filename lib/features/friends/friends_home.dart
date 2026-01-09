import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/friends_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/friends/friendship_dto.dart';
import '../../models/auth/user_status.dart';
import '../../shared/widgets/app_loading.dart';
import '../../shared/widgets/app_toast.dart';
import 'add_friend_modal.dart';

/// Friends home screen (shows friends list, online friends, etc.)
class FriendsHome extends ConsumerStatefulWidget {
  const FriendsHome({super.key});

  @override
  ConsumerState<FriendsHome> createState() => _FriendsHomeState();
}

class _FriendsHomeState extends ConsumerState<FriendsHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _addFriendModalOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Fetch friends data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendsProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleAcceptRequest(String friendshipId) async {
    final success = await ref.read(friendsProvider.notifier).acceptRequest(friendshipId);
    if (mounted) {
      if (success) {
        AppToast.showSuccess(context, 'Friend request accepted');
      } else {
        final error = ref.read(friendsProvider).error;
        AppToast.showError(context, error ?? 'Failed to accept friend request');
      }
    }
  }

  Future<void> _handleDeclineRequest(String friendshipId) async {
    final success = await ref.read(friendsProvider.notifier).declineRequest(friendshipId);
    if (mounted) {
      if (success) {
        AppToast.showSuccess(context, 'Friend request declined');
      } else {
        final error = ref.read(friendsProvider).error;
        AppToast.showError(context, error ?? 'Failed to decline friend request');
      }
    }
  }

  Widget _buildFriendItem(FriendshipDto friendship, String currentUserId) {
    final otherUser = friendship.getOtherUser(currentUserId);
    if (otherUser == null) return const SizedBox.shrink();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          otherUser.username[0].toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        otherUser.username,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        otherUser.status == UserStatus.online ? 'Online' : 'Offline',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: otherUser.status == UserStatus.online
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        // Navigate to DM with this user
        // TODO: Create DM channel and navigate
      },
    );
  }

  Widget _buildPendingRequestItem(FriendshipDto friendship, String currentUserId) {
    final otherUser = friendship.getOtherUser(currentUserId);
    if (otherUser == null) return const SizedBox.shrink();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          otherUser.username[0].toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        otherUser.username,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        friendship.requesterId == currentUserId
            ? 'Outgoing request'
            : 'Incoming request',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: friendship.requesterId != currentUserId
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, size: 20),
                  color: Colors.green,
                  onPressed: () => _handleAcceptRequest(friendship.id),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.red,
                  onPressed: () => _handleDeclineRequest(friendship.id),
                ),
              ],
            )
          : Text(
              'Pending',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id ?? '';

    return Stack(
      children: [
        Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Add Friend button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.person_add, size: 24),
                    onPressed: () => setState(() => _addFriendModalOpen = true),
                    tooltip: 'Add Friend',
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Online'),
                Tab(text: 'All'),
                Tab(text: 'Pending'),
              ],
            ),
            // Content
            Expanded(
              child: friendsState.isLoading
                  ? const AppLoading()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Online tab
                        friendsState.friends
                                .where((f) {
                                  final user = f.getOtherUser(currentUserId);
                                  return user?.status == UserStatus.online;
                                })
                                .isEmpty
                            ? _buildEmptyState('No online friends')
                            : ListView(
                                children: friendsState.friends
                                    .where((f) {
                                      final user = f.getOtherUser(currentUserId);
                                      return user?.status == UserStatus.online;
                                    })
                                    .map((f) => _buildFriendItem(f, currentUserId))
                                    .toList(),
                              ),
                        // All tab
                        friendsState.friends.isEmpty
                            ? _buildEmptyState('No friends yet')
                            : ListView(
                                children: friendsState.friends
                                    .map((f) => _buildFriendItem(f, currentUserId))
                                    .toList(),
                              ),
                        // Pending tab
                        friendsState.pendingRequests.isEmpty
                            ? _buildEmptyState('No pending requests')
                            : ListView(
                                children: friendsState.pendingRequests
                                    .map((f) => _buildPendingRequestItem(f, currentUserId))
                                    .toList(),
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
        ),
        // Add Friend Modal overlay
        if (_addFriendModalOpen)
          AddFriendModal(
            open: _addFriendModalOpen,
            onOpenChange: (open) => setState(() => _addFriendModalOpen = open),
          ),
      ],
    );
  }
}
