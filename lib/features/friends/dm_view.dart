import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dm_provider.dart';
import '../../providers/signalr/chat_hub_provider.dart';
import '../../providers/message_provider.dart';
import '../messages/message_list.dart';
import '../messages/message_composer.dart';

/// DM view showing messages with a user
class DMView extends ConsumerStatefulWidget {
  final String channelId;

  const DMView({
    super.key,
    required this.channelId,
  });

  @override
  ConsumerState<DMView> createState() => _DMViewState();
}

class _DMViewState extends ConsumerState<DMView> {
  @override
  void initState() {
    super.initState();
    // Join DM when view is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinDM();
      _fetchMessages();
    });
  }

  @override
  void dispose() {
    // Leave DM when view is closed
    _leaveDM();
    super.dispose();
  }

  Future<void> _joinDM() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      await chatHub.joinDM(widget.channelId);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _leaveDM() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      await chatHub.leaveDM(widget.channelId);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchMessages() async {
    try {
      await ref.read(messageProvider.notifier).fetchDMMessages(widget.channelId);
      // Mark DM as read when viewing
      await ref.read(dmProvider.notifier).markDMAsRead(widget.channelId);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final dmState = ref.watch(dmProvider);
    final dm = dmState.dms.firstWhere(
      (d) => d.id == widget.channelId,
      orElse: () => dmState.dms.isNotEmpty ? dmState.dms.first : throw StateError('DM not found'),
    );

    final otherUser = dm.otherUser;

    if (otherUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'DM not found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This direct message could not be found.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // DM Header
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF1F2023), // Darker gray separator
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: Theme.of(context).colorScheme.onSurface,
                    onPressed: () {
                      context.go('/me');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // Avatar
                  Container(
                    width: 32,
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
                  const SizedBox(width: 8),
                  // Name
                  Text(
                    otherUser.displayName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Messages Area
            Expanded(
              child: MessageList(
                channelId: widget.channelId,
              ),
            ),
            // Message Composer
            MessageComposer(
              channelId: widget.channelId,
              guildId: null, // DM'lerde guild yok
            ),
          ],
        ),
      ),
    );
  }
}

