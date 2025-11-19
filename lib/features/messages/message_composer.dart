import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/message_provider.dart';
import '../../providers/signalr/chat_hub_provider.dart';
import '../../models/message/create_message_dto.dart';
import '../../providers/auth_provider.dart';
import '../../models/auth/user_dto.dart';

/// Message composer widget with typing indicator
class MessageComposer extends ConsumerStatefulWidget {
  final String channelId;

  const MessageComposer({
    super.key,
    required this.channelId,
  });

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  Timer? _typingTimer;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  String _formatTypingIndicator(List<UserDto> users) {
    if (users.isEmpty) return '';
    
    final names = users
        .map((user) => user.displayName ?? user.username)
        .toList();
    
    if (names.length == 1) {
      return '${names[0]} is typing...';
    } else if (names.length == 2) {
      return '${names[0]} and ${names[1]} are typing...';
    } else {
      return '${names[0]}, ${names[1]} and ${names.length - 2} others are typing...';
    }
  }

  void _onTextChanged(String text) {
    // Send typing indicator
    _sendTypingIndicator();

    // Cancel previous timer
    _typingTimer?.cancel();

    // Set timer to stop typing indicator after 3 seconds
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _stopTypingIndicator();
    });
  }

  Future<void> _sendTypingIndicator() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      final chatHubState = ref.read(chatHubProvider);
      
      // Connection yoksa başlatmayı dene
      if (!chatHubState.isConnected) {
        print('DEBUG: SignalR not connected, attempting to start...');
        await chatHub.start();
        // Tekrar kontrol et
        final newState = ref.read(chatHubProvider);
        if (!newState.isConnected) {
          print('DEBUG: SignalR still not connected after start attempt');
          return;
        }
      }
      
      print('DEBUG: Sending typing indicator for channel: ${widget.channelId}');
      // Backend'deki method ismi: Typing (SendTyping değil)
      await chatHub.invoke('Typing', args: [widget.channelId]);
      print('DEBUG: Typing indicator sent successfully');
    } catch (e) {
      print('DEBUG: Failed to send typing indicator: ${e.toString()}');
      // Ignore errors but log them
    }
  }

  Future<void> _stopTypingIndicator() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      final chatHubState = ref.read(chatHubProvider);
      
      // Connection yoksa başlatmayı dene
      if (!chatHubState.isConnected) {
        print('DEBUG: SignalR not connected, attempting to start...');
        await chatHub.start();
        // Tekrar kontrol et
        final newState = ref.read(chatHubProvider);
        if (!newState.isConnected) {
          print('DEBUG: SignalR still not connected after start attempt');
          return;
        }
      }
      
      print('DEBUG: Stopping typing indicator for channel: ${widget.channelId}');
      await chatHub.invoke('StopTyping', args: [widget.channelId]);
      print('DEBUG: Typing indicator stopped successfully');
    } catch (e) {
      print('DEBUG: Failed to stop typing indicator: ${e.toString()}');
      // Ignore errors but log them
    }
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final dto = CreateMessageDto(content: content);
      await ref.read(messageProvider.notifier).createMessage(
            widget.channelId,
            dto,
          );

      _controller.clear();
      _stopTypingIndicator();
    } catch (e) {
      // Show error toast or handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final typingUsers = messageState.getTypingUsers(widget.channelId);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    // Filter out current user from typing users
    final otherTypingUsers = typingUsers
        .where((user) => user.id != currentUserId)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Typing indicator
        if (otherTypingUsers.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatTypingIndicator(otherTypingUsers),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
            ),
          ),
        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text input
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onTextChanged,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message #channel',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

