import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/channel_provider.dart';
import '../../providers/signalr/chat_hub_provider.dart';
import '../../models/guild/channel_type.dart';
import '../modals/create_channel_modal.dart';
import '../messages/message_list.dart';
import '../messages/message_composer.dart';

/// Channel view showing messages and content
class ChannelView extends ConsumerStatefulWidget {
  final String guildId;
  final String channelId;

  const ChannelView({
    super.key,
    required this.guildId,
    required this.channelId,
  });

  @override
  ConsumerState<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends ConsumerState<ChannelView> {
  @override
  void initState() {
    super.initState();
    // Join channel when view is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinChannel();
    });
  }

  @override
  void dispose() {
    // Leave channel when view is closed
    _leaveChannel();
    super.dispose();
  }

  Future<void> _joinChannel() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      await chatHub.invoke('JoinChannel', args: [widget.channelId]);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _leaveChannel() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      await chatHub.invoke('LeaveChannel', args: [widget.channelId]);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelState = ref.watch(channelProvider);
    final channels = channelState.getChannelsForGuild(widget.guildId);

    // Get messageId from query parameters (for scroll to message)
    final routerState = GoRouterState.of(context);
    final scrollToMessageId = routerState.uri.queryParameters['messageId'];

    // If no channels exist and not loading, show empty state
    if (channels.isEmpty && !channelState.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tag, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No channels yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a channel to get started',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withOpacity(0.7),
                        builder: (context) => CreateChannelModal(
                          open: true,
                          onOpenChange: (open) {
                            if (!open) {
                              Navigator.of(context).pop();
                            }
                          },
                          guildId: widget.guildId,
                          defaultChannelType: ChannelType.text,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Create Channel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final channel = channels.isNotEmpty
        ? channels.firstWhere(
            (c) => c.id == widget.channelId,
            orElse: () => channels.first,
          )
        : null;

    // Set selected channel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(channelProvider.notifier).setSelectedChannel(widget.channelId);
    });

    // If channel not found and channels exist, show error
    if (channel == null && channels.isNotEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Channel not found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This channel could not be found.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.go('/guilds/${widget.guildId}');
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // If still loading, show loading
    if (channel == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Voice channels will have a different view (for future implementation)
    if (channel.type == ChannelType.voice) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Voice Channel: ${channel.name}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Voice channels will be implemented soon',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Text channel: show messages area
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Channel Header
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
                      // Navigate back to guild view
                      context.go('/guilds/${widget.guildId}');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.tag, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    channel.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (channel.topic != null && channel.topic!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '• ${channel.topic}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Messages Area
            Expanded(
              child: MessageList(
                channelId: widget.channelId,
                scrollToMessageId: scrollToMessageId,
              ),
            ),
            // Message Composer
            MessageComposer(
              channelId: widget.channelId,
              guildId: widget.guildId,
            ),
          ],
        ),
      ),
    );
  }
}
