import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message/message_dto.dart';
import '../../providers/auth_provider.dart';

/// Message item widget with Discord-like grouping
class MessageItem extends ConsumerWidget {
  final MessageDto message;
  final MessageDto? previousMessage;
  final bool isGrouped; // If true, hide avatar and username (grouped with previous)

  const MessageItem({
    super.key,
    required this.message,
    this.previousMessage,
    this.isGrouped = false,
  });

  /// Check if message should be grouped with previous
  static bool shouldGroup(MessageDto current, MessageDto? previous) {
    if (previous == null) return false;
    if (current.userId != previous.userId) return false;
    
    // Group if messages are within 5 minutes
    final timeDiff = current.createdAt.difference(previous.createdAt);
    return timeDiff.inMinutes < 5;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today: show time only
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return 'Yesterday $hour:$minute';
    } else {
      // Older: show date and time
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
  }

  /// Build mention-highlighted text
  List<TextSpan> _buildMentionText(
    BuildContext context,
    String text,
    String? currentUserId,
  ) {
    final spans = <TextSpan>[];
    final mentionPattern = RegExp(r'@(\w+)');
    int lastIndex = 0;

    for (final match in mentionPattern.allMatches(text)) {
      // Add text before mention
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.375,
            ),
          ),
        );
      }

      // Add mention with highlight
      final mentionText = match.group(0)!; // Full match: @username
      spans.add(
        TextSpan(
          text: mentionText,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(0.3),
            height: 1.375,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.375,
          ),
        ),
      );
    }

    // If no mentions found, return plain text
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.375,
          ),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = message.user;
    final displayName = user?.displayName ?? user?.username ?? 'Unknown';
    final isPending = message.isPending;
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    return Opacity(
      opacity: isPending ? 0.6 : 1.0, // Pending mesajlar yarı saydam
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (hidden if grouped)
            if (!isGrouped) ...[
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
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 52), // Spacer for alignment
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username and timestamp (hidden if grouped)
                  if (!isGrouped) ...[
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
                        if (message.editedAt != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Message content with pending indicator and mention highlight
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: _buildMentionText(
                              context,
                              message.content,
                              currentUserId,
                            ),
                          ),
                        ),
                      ),
                      // Pending indicator
                      if (isPending) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Attachments (if any)
                  if (message.attachments != null &&
                      message.attachments!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...message.attachments!.map(
                      (attachment) => _buildAttachment(context, attachment),
                    ),
                  ],
                  // Embeds (if any)
                  if (message.embeds != null && message.embeds!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...message.embeds!.map(
                      (embed) => _buildEmbed(context, embed),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(BuildContext context, attachment) {
    // Placeholder for attachment display
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName ?? 'Attachment',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbed(BuildContext context, embed) {
    // Placeholder for embed display
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: embed.color != null
                ? Color(embed.color!)
                : Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (embed.title != null)
            Text(
              embed.title!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          if (embed.description != null) ...[
            if (embed.title != null) const SizedBox(height: 4),
            Text(
              embed.description!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

