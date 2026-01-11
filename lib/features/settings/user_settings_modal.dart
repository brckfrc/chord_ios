import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/auth/user_status.dart';
import '../../providers/presence_provider.dart';
import '../../providers/signalr/presence_hub_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../shared/widgets/user_status_indicator.dart';

/// User settings modal with tabs for status and notifications
class UserSettingsModal extends ConsumerStatefulWidget {
  final bool open;
  final void Function(bool) onOpenChange;

  const UserSettingsModal({
    super.key,
    required this.open,
    required this.onOpenChange,
  });

  @override
  ConsumerState<UserSettingsModal> createState() => _UserSettingsModalState();
}

class _UserSettingsModalState extends ConsumerState<UserSettingsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getStatusLabel(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'Online';
      case UserStatus.idle:
        return 'Idle';
      case UserStatus.dnd:
        return 'Do Not Disturb';
      case UserStatus.invisible:
        return 'Invisible';
      case UserStatus.offline:
        return 'Offline';
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    UserStatus newStatus,
  ) async {
    try {
      final presenceHub = ref.read(presenceHubProvider.notifier);
      final presenceHubState = ref.read(presenceHubProvider);

      // Connection kontrolü
      if (!presenceHubState.isConnected) {
        await presenceHub.start();
        // Tekrar kontrol et
        final newState = ref.read(presenceHubProvider);
        if (!newState.isConnected) {
          throw Exception('PresenceHub connection failed');
        }
      }

      // Backend expects int (enum index), not string
      // Backend enum: Online=0, Idle=1, DoNotDisturb=2, Invisible=3, Offline=4
      // Flutter enum: online=0, idle=1, dnd=2, invisible=3, offline=4
      final statusInt = UserStatus.values.indexOf(newStatus);

      // Backend method signature: UpdateStatus(int status, string? customStatus = null)
      // customStatus'u null olarak gönder
      await presenceHub.invoke('UpdateStatus', args: [statusInt, null]);

      // Update current user status in AuthProvider
      final authNotifier = ref.read(authProvider.notifier);
      authNotifier.updateUserStatus(newStatus);

      final currentUser = ref.read(authProvider).user;

      // Update presence provider
      if (currentUser != null) {
        ref
            .read(presenceProvider.notifier)
            .updateUserStatus(currentUser.id, newStatus);
      }

      // Close modal
      widget.onOpenChange(false);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) {
      return const SizedBox.shrink();
    }

    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final currentStatus = currentUser?.status ?? UserStatus.offline;
    final notificationPrefs = ref.watch(notificationPreferencesProvider);

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'User Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => widget.onOpenChange(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // TabBar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Set Status'),
                Tab(text: 'Notifications'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            // TabBarView
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Set Status Tab
                  _buildStatusTab(context, ref, currentStatus),
                  // Notifications Tab
                  _buildNotificationsTab(context, ref, notificationPrefs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab(
    BuildContext context,
    WidgetRef ref,
    UserStatus currentStatus,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status options (Offline excluded - Invisible already shows as offline)
          ...UserStatus.values
              .where((status) => status != UserStatus.offline)
              .map((status) {
            final isSelected = status == currentStatus;
            return InkWell(
              onTap: () => _updateStatus(context, ref, status),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    UserStatusIndicator(status: status, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferencesState notificationPrefs,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Control which notifications you receive',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          // Channel Notifications Toggle
          InkWell(
            onTap: () {
              ref
                  .read(notificationPreferencesProvider.notifier)
                  .setChannelNotificationsEnabled(!notificationPrefs.channelEnabled);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Channel Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Receive notifications for messages in channels',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: notificationPrefs.channelEnabled,
                    onChanged: (value) {
                      ref
                          .read(notificationPreferencesProvider.notifier)
                          .setChannelNotificationsEnabled(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // DM Notifications Toggle
          InkWell(
            onTap: () {
              ref
                  .read(notificationPreferencesProvider.notifier)
                  .setDMNotificationsEnabled(!notificationPrefs.dmEnabled);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DM Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Receive notifications for direct messages',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: notificationPrefs.dmEnabled,
                    onChanged: (value) {
                      ref
                          .read(notificationPreferencesProvider.notifier)
                          .setDMNotificationsEnabled(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
