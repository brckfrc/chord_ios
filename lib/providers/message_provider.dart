import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message/message_dto.dart';
import '../models/message/create_message_dto.dart';
import '../models/auth/user_dto.dart';
import '../models/auth/user_status.dart';
import '../repositories/message_repository.dart';
import 'signalr/chat_hub_provider.dart';

/// Message state for a channel
class MessageState {
  final Map<String, List<MessageDto>> messagesByChannel;
  final Map<String, bool> isLoadingByChannel;
  final Map<String, String?> errorByChannel;
  final Map<String, bool> hasMoreByChannel;
  final Map<String, String?> oldestMessageIdByChannel;
  final Map<String, Map<String, UserDto>> typingUsersByChannel; // channelId -> userId -> UserDto

  MessageState({
    this.messagesByChannel = const {},
    this.isLoadingByChannel = const {},
    this.errorByChannel = const {},
    this.hasMoreByChannel = const {},
    this.oldestMessageIdByChannel = const {},
    this.typingUsersByChannel = const {},
  });

  List<MessageDto> getMessagesForChannel(String channelId) {
    return messagesByChannel[channelId] ?? [];
  }

  bool isLoadingChannel(String channelId) {
    return isLoadingByChannel[channelId] ?? false;
  }

  String? getErrorForChannel(String channelId) {
    return errorByChannel[channelId];
  }

  bool hasMoreMessages(String channelId) {
    return hasMoreByChannel[channelId] ?? true;
  }

  String? getOldestMessageId(String channelId) {
    return oldestMessageIdByChannel[channelId];
  }

  List<UserDto> getTypingUsers(String channelId) {
    final users = typingUsersByChannel[channelId];
    return users != null ? users.values.toList() : [];
  }

  MessageState copyWith({
    Map<String, List<MessageDto>>? messagesByChannel,
    Map<String, bool>? isLoadingByChannel,
    Map<String, String?>? errorByChannel,
    Map<String, bool>? hasMoreByChannel,
    Map<String, String?>? oldestMessageIdByChannel,
    Map<String, Map<String, UserDto>>? typingUsersByChannel,
  }) {
    return MessageState(
      messagesByChannel: messagesByChannel ?? this.messagesByChannel,
      isLoadingByChannel: isLoadingByChannel ?? this.isLoadingByChannel,
      errorByChannel: errorByChannel ?? this.errorByChannel,
      hasMoreByChannel: hasMoreByChannel ?? this.hasMoreByChannel,
      oldestMessageIdByChannel:
          oldestMessageIdByChannel ?? this.oldestMessageIdByChannel,
      typingUsersByChannel: typingUsersByChannel ?? this.typingUsersByChannel,
    );
  }
}

/// Message repository provider
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

/// Message state provider
class MessageNotifier extends StateNotifier<MessageState> {
  final MessageRepository _repository;
  final Ref _ref;
  bool _listenersRegistered = false;

  MessageNotifier(this._repository, this._ref) : super(MessageState()) {
    _setupSignalRListeners();
  }

  void _setupSignalRListeners() {
    // Connection state'i dinle ve connection kurulduğunda listener'ları kaydet
    _ref.listen<ChatHubState>(chatHubProvider, (previous, next) {
      // Connection kurulduğunda listener'ları kaydet (sadece bir kez)
      if (next.isConnected && !_listenersRegistered) {
        print('DEBUG: Connection established, setting up SignalR listeners');
        _registerListeners();
      }
    });
    
    // Eğer zaten bağlıysa hemen kaydet
    final chatHubState = _ref.read(chatHubProvider);
    if (chatHubState.isConnected && !_listenersRegistered) {
      print('DEBUG: Already connected, setting up SignalR listeners immediately');
      _registerListeners();
    } else if (!chatHubState.isConnected) {
      print('DEBUG: SignalR not connected yet, listeners will be set up after connection');
    }
  }

  void _registerListeners() {
    if (_listenersRegistered) {
      print('DEBUG: Listeners already registered, skipping');
      return;
    }

    final chatHub = _ref.read(chatHubProvider.notifier);
    final connection = _ref.read(chatHubServiceProvider).connection;
    
    if (connection == null) {
      print('DEBUG: Connection is null, cannot register listeners');
      return;
    }

    print('DEBUG: Registering SignalR listeners');
    _listenersRegistered = true;

    // Listen to ReceiveMessage event
    chatHub.on('ReceiveMessage', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final messageJson = args[0] as Map<String, dynamic>;
          final message = MessageDto.fromJson(messageJson);
          _addMessageToChannel(message.channelId, message);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to MessageEdited event
    chatHub.on('MessageEdited', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final messageJson = args[0] as Map<String, dynamic>;
          final message = MessageDto.fromJson(messageJson);
          _updateMessageInChannel(message.channelId, message);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to MessageDeleted event
    chatHub.on('MessageDeleted', (args) {
      if (args != null && args.length >= 2) {
        try {
          final channelId = args[0] as String;
          final messageId = args[1] as String;
          _removeMessageFromChannel(channelId, messageId);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to UserTyping event
    chatHub.on('UserTyping', (args) {
      print('DEBUG: UserTyping event received: $args');
      // Backend formatı: new { userId, username, channelId } - tek bir object
      if (args != null && args.length >= 1) {
        try {
          // args[0] bir Map olmalı: { userId, username, channelId }
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final channelId = data['channelId']?.toString() ?? '';
            final userId = data['userId']?.toString() ?? '';
            final username = data['username']?.toString() ?? userId;
            
            print('DEBUG: UserTyping - channelId: $channelId, userId: $userId, username: $username');
            
            // UserDto oluştur
            final user = UserDto(
              id: userId,
              username: username,
              email: '',
              createdAt: DateTime.now(),
              status: UserStatus.offline,
            );
            _addTypingUser(channelId, user);
            print('DEBUG: UserTyping - added user: $username');
          } else {
            print('DEBUG: UserTyping - args[0] is not a Map: ${args[0].runtimeType}');
          }
        } catch (e) {
          print('DEBUG: Error parsing UserTyping event: ${e.toString()}');
          print('DEBUG: Stack trace: ${StackTrace.current}');
        }
      } else {
        print('DEBUG: UserTyping event has invalid args: $args');
      }
    });

    // Listen to UserStoppedTyping event
    chatHub.on('UserStoppedTyping', (args) {
      print('DEBUG: UserStoppedTyping event received: $args');
      // Backend formatı: new { userId, channelId } - tek bir object
      if (args != null && args.length >= 1) {
        try {
          // args[0] bir Map olmalı: { userId, channelId }
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final channelId = data['channelId']?.toString() ?? '';
            final userId = data['userId']?.toString() ?? '';
            print('DEBUG: UserStoppedTyping - channelId: $channelId, userId: $userId');
            _removeTypingUser(channelId, userId);
          } else {
            print('DEBUG: UserStoppedTyping - args[0] is not a Map: ${args[0].runtimeType}');
          }
        } catch (e) {
          print('DEBUG: Error parsing UserStoppedTyping event: ${e.toString()}');
        }
      } else {
        print('DEBUG: UserStoppedTyping event has invalid args: $args');
      }
    });
    
    print('DEBUG: SignalR listeners registered successfully');
  }

  /// Fetch messages for a channel
  Future<void> fetchMessages(String channelId, {bool loadMore = false}) async {
    final currentMessages = state.getMessagesForChannel(channelId);
    final isLoading = state.isLoadingChannel(channelId);

    if (isLoading) return;

    state = state.copyWith(
      isLoadingByChannel: {
        ...state.isLoadingByChannel,
        channelId: true,
      },
      errorByChannel: {
        ...state.errorByChannel,
        channelId: null,
      },
    );

    try {
      final beforeMessageId =
          loadMore && currentMessages.isNotEmpty ? currentMessages.last.id : null;
      final messages = await _repository.fetchMessages(
        channelId,
        limit: 50,
        beforeMessageId: beforeMessageId,
      );

      final updatedMessagesByChannel =
          Map<String, List<MessageDto>>.from(state.messagesByChannel);
      final existingMessages = updatedMessagesByChannel[channelId] ?? [];

      if (loadMore) {
        // Append older messages
        updatedMessagesByChannel[channelId] = [...existingMessages, ...messages];
      } else {
        // Replace with new messages
        updatedMessagesByChannel[channelId] = messages;
      }

      // Sort by createdAt (oldest first)
      updatedMessagesByChannel[channelId]!.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );

      final oldestMessageId = messages.isNotEmpty ? messages.first.id : null;
      final hasMore = messages.length >= 50;

      state = state.copyWith(
        messagesByChannel: updatedMessagesByChannel,
        isLoadingByChannel: {
          ...state.isLoadingByChannel,
          channelId: false,
        },
        hasMoreByChannel: {
          ...state.hasMoreByChannel,
          channelId: hasMore,
        },
        oldestMessageIdByChannel: oldestMessageId != null
            ? {
                ...state.oldestMessageIdByChannel,
                channelId: oldestMessageId,
              }
            : state.oldestMessageIdByChannel,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingByChannel: {
          ...state.isLoadingByChannel,
          channelId: false,
        },
        errorByChannel: {
          ...state.errorByChannel,
          channelId: e.toString(),
        },
      );
    }
  }

  /// Create a new message
  Future<MessageDto?> createMessage(
    String channelId,
    CreateMessageDto dto,
  ) async {
    try {
      final message = await _repository.createMessage(channelId, dto);
      _addMessageToChannel(channelId, message);
      return message;
    } catch (e) {
      state = state.copyWith(
        errorByChannel: {
          ...state.errorByChannel,
          channelId: e.toString(),
        },
      );
      return null;
    }
  }

  /// Update a message
  Future<MessageDto?> updateMessage(
    String channelId,
    String messageId,
    UpdateMessageDto dto,
  ) async {
    try {
      final message = await _repository.updateMessage(channelId, messageId, dto);
      _updateMessageInChannel(channelId, message);
      return message;
    } catch (e) {
      state = state.copyWith(
        errorByChannel: {
          ...state.errorByChannel,
          channelId: e.toString(),
        },
      );
      return null;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String channelId, String messageId) async {
    try {
      await _repository.deleteMessage(channelId, messageId);
      _removeMessageFromChannel(channelId, messageId);
    } catch (e) {
      state = state.copyWith(
        errorByChannel: {
          ...state.errorByChannel,
          channelId: e.toString(),
        },
      );
    }
  }

  /// Add message to channel (used by SignalR events)
  void _addMessageToChannel(String channelId, MessageDto message) {
    final updatedMessagesByChannel =
        Map<String, List<MessageDto>>.from(state.messagesByChannel);
    final existingMessages = updatedMessagesByChannel[channelId] ?? [];

    // Check if message already exists
    if (existingMessages.any((m) => m.id == message.id)) {
      return;
    }

    // Add message and sort
    updatedMessagesByChannel[channelId] = [...existingMessages, message];
    updatedMessagesByChannel[channelId]!.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    state = state.copyWith(messagesByChannel: updatedMessagesByChannel);
  }

  /// Update message in channel (used by SignalR events)
  void _updateMessageInChannel(String channelId, MessageDto message) {
    final updatedMessagesByChannel =
        Map<String, List<MessageDto>>.from(state.messagesByChannel);
    final existingMessages = updatedMessagesByChannel[channelId] ?? [];

    final index = existingMessages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      existingMessages[index] = message;
      updatedMessagesByChannel[channelId] = existingMessages;
      state = state.copyWith(messagesByChannel: updatedMessagesByChannel);
    }
  }

  /// Remove message from channel (used by SignalR events)
  void _removeMessageFromChannel(String channelId, String messageId) {
    final updatedMessagesByChannel =
        Map<String, List<MessageDto>>.from(state.messagesByChannel);
    final existingMessages = updatedMessagesByChannel[channelId] ?? [];

    updatedMessagesByChannel[channelId] =
        existingMessages.where((m) => m.id != messageId).toList();

    state = state.copyWith(messagesByChannel: updatedMessagesByChannel);
  }

  /// Add typing user
  void _addTypingUser(String channelId, UserDto user) {
    final updatedTypingUsers =
        Map<String, Map<String, UserDto>>.from(state.typingUsersByChannel);
    final typingUsers = Map<String, UserDto>.from(updatedTypingUsers[channelId] ?? {});
    typingUsers[user.id] = user;
    updatedTypingUsers[channelId] = typingUsers;

    state = state.copyWith(typingUsersByChannel: updatedTypingUsers);
  }

  /// Remove typing user
  void _removeTypingUser(String channelId, String userId) {
    final updatedTypingUsers =
        Map<String, Map<String, UserDto>>.from(state.typingUsersByChannel);
    final typingUsers = Map<String, UserDto>.from(updatedTypingUsers[channelId] ?? {});
    typingUsers.remove(userId);
    updatedTypingUsers[channelId] = typingUsers;

    state = state.copyWith(typingUsersByChannel: updatedTypingUsers);
  }

  /// Clear messages for a channel
  void clearMessages(String channelId) {
    final updatedMessagesByChannel =
        Map<String, List<MessageDto>>.from(state.messagesByChannel);
    updatedMessagesByChannel.remove(channelId);

    final updatedTypingUsers =
        Map<String, Map<String, UserDto>>.from(state.typingUsersByChannel);
    updatedTypingUsers.remove(channelId);

    state = state.copyWith(
      messagesByChannel: updatedMessagesByChannel,
      typingUsersByChannel: updatedTypingUsers,
    );
  }
}

/// Message provider
final messageProvider =
    StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return MessageNotifier(repository, ref);
});

