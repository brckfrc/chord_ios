import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/message_provider.dart';
import 'message_item.dart';

/// Message list widget with infinite scroll
class MessageList extends ConsumerStatefulWidget {
  final String channelId;
  final String? scrollToMessageId; // Optional message ID to scroll to

  const MessageList({
    super.key,
    required this.channelId,
    this.scrollToMessageId,
  });

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  String? _lastScrolledMessageId;

  @override
  void initState() {
    super.initState();
    // Fetch initial messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageProvider.notifier).fetchMessages(widget.channelId);
    });

    // Listen to scroll for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to message if scrollToMessageId changed
    if (widget.scrollToMessageId != null &&
        widget.scrollToMessageId != _lastScrolledMessageId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessage(widget.scrollToMessageId!);
      });
    }
  }

  void _scrollToMessage(String messageId) {
    final messageState = ref.read(messageProvider);
    final messages = messageState.getMessagesForChannel(widget.channelId);
    
    // Find message index
    final messageIndex = messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) {
      // Message not found, might need to load more
      return;
    }

    // Calculate scroll position (reverse list, so we need to calculate from bottom)
    // In reverse list, index 0 is at the bottom
    final itemCount = messages.length;
    final targetIndex = itemCount - 1 - messageIndex;
    
    // Wait for layout to complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate approximate position (each message is roughly 60-80px)
        final estimatedItemHeight = 70.0;
        final targetPosition = targetIndex * estimatedItemHeight;
        
        // Scroll to position
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        
        _lastScrolledMessageId = messageId;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    final messageState = ref.read(messageProvider);
    if (!messageState.hasMoreMessages(widget.channelId) ||
        messageState.isLoadingChannel(widget.channelId)) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    await ref
        .read(messageProvider.notifier)
        .fetchMessages(widget.channelId, loadMore: true);

    setState(() {
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final messages = messageState.getMessagesForChannel(widget.channelId);
    final isLoading = messageState.isLoadingChannel(widget.channelId);
    final error = messageState.getErrorForChannel(widget.channelId);

    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load messages',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(messageProvider.notifier)
                    .fetchMessages(widget.channelId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to send a message!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Show newest at bottom, scroll to bottom for new messages
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the bottom (for loading older messages)
        if (index == messages.length && _isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Reverse index for reverse list
        final messageIndex = messages.length - 1 - index;
        final message = messages[messageIndex];
        final previousMessage =
            messageIndex > 0 ? messages[messageIndex - 1] : null;

        final isGrouped = MessageItem.shouldGroup(message, previousMessage);

        return MessageItem(
          message: message,
          previousMessage: previousMessage,
          isGrouped: isGrouped,
        );
      },
    );
  }
}

