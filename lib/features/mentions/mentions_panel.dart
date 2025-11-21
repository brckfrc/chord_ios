import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/mention_provider.dart';
import '../../providers/channel_provider.dart';
import '../../models/mention/message_mention_dto.dart';

/// Mentions panel widget showing unread/read mentions
class MentionsPanel extends ConsumerStatefulWidget {
  const MentionsPanel({super.key});

  @override
  ConsumerState<MentionsPanel> createState() => _MentionsPanelState();
}

class _MentionsPanelState extends ConsumerState<MentionsPanel> {
  @override
  void initState() {
    super.initState();
    // Fetch mentions when panel opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mentionProvider.notifier).fetchMentions();
    });
  }

  void _handleMentionTap(MessageMentionDto mention) {
    // Mark as read
    ref.read(mentionProvider.notifier).markMentionAsRead(mention.id);

    // Navigate to the channel and message
    final message = mention.message;
    final channelId = message.channelId;
    
    // Find guildId from channel provider
    final channelState = ref.read(channelProvider);
    String? guildId;
    
    // Search through all channels to find the one with matching channelId
    for (final guildChannels in channelState.channelsByGuild.values) {
      final channel = guildChannels.firstWhere(
        (c) => c.id == channelId,
        orElse: () => guildChannels.first,
      );
      if (channel.id == channelId) {
        guildId = channel.guildId;
        break;
      }
    }
    
    // If guildId found, navigate to channel with messageId query parameter
    if (guildId != null) {
      context.go('/guilds/$guildId/channels/$channelId?messageId=${mention.messageId}');
    } else {
      // Fallback: try to fetch channel info (will be handled later)
      // For now, just show an error or navigate to home
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Channel not found'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    
    // TODO: Scroll to specific message (will be implemented in "Click to jump" task)
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return 'Yesterday $hour:$minute';
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
  }

  Widget _buildMentionItem(MessageMentionDto mention) {
    final message = mention.message;
    final user = message.user;
    final displayName = user?.displayName ?? user?.username ?? 'Unknown';
    final isUnread = !mention.isRead;

    return InkWell(
      onTap: () => _handleMentionTap(mention),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isUnread
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Message preview (truncated)
                  Text(
                    message.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mentionState = ref.watch(mentionProvider);
    final unreadMentions = mentionState.unreadMentions;
    final readMentions = mentionState.readMentions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentions'),
        actions: [
          if (mentionState.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${mentionState.unreadCount}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: mentionState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : mentionState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${mentionState.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(mentionProvider.notifier).fetchMentions();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : unreadMentions.isEmpty && readMentions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.alternate_email,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No mentions yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When someone mentions you, it will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(mentionProvider.notifier).fetchMentions();
                      },
                      child: ListView(
                        children: [
                          // Unread mentions section
                          if (unreadMentions.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'UNREAD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            ...unreadMentions.map((mention) => _buildMentionItem(mention)),
                            const Divider(height: 32),
                          ],
                          // Read mentions section
                          if (readMentions.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'OLDER',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            ...readMentions.map((mention) => _buildMentionItem(mention)),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

