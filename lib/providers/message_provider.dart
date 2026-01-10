import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message/message_dto.dart';
import '../models/message/direct_message_dto.dart';
import '../models/message/create_message_dto.dart';
import '../models/auth/user_dto.dart';
import '../models/auth/user_status.dart';
import '../repositories/message_repository.dart';
import '../services/network/connectivity_service.dart';
import '../services/database/message_cache_service.dart';
import 'signalr/chat_hub_provider.dart';
import 'auth_provider.dart';
import 'mention_provider.dart';
import '../models/mention/message_mention_dto.dart';

/// Message state for a channel
class MessageState {
  final Map<String, List<MessageDto>> messagesByChannel;
  final Map<String, bool> isLoadingByChannel;
  final Map<String, String?> errorByChannel;
  final Map<String, bool> hasMoreByChannel;
  final Map<String, String?> oldestMessageIdByChannel;
  final Map<String, Map<String, UserDto>>
  typingUsersByChannel; // channelId -> userId -> UserDto

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
  final connectivityService = ref.watch(connectivityServiceProvider);
  return MessageRepository(connectivityService: connectivityService);
});

/// Message state provider
class MessageNotifier extends StateNotifier<MessageState> {
  final MessageRepository _repository;
  final Ref _ref;
  bool _listenersRegistered = false;

  MessageNotifier(this._repository, this._ref) : super(MessageState()) {
    _setupSignalRListeners();
    _setupConnectivityListener();
    // Cache is already initialized in main.dart via DatabaseService.init()
  }

  /// Setup connectivity listener for auto-sync
  void _setupConnectivityListener() {
    _ref.listen<AsyncValue<NetworkStatus>>(networkStatusProvider, (
      previous,
      next,
    ) {
      next.whenData((status) {
        if (status == NetworkStatus.connected) {
          // Online olduğunda tüm channel'lar için sync yap
          _syncAllChannels();
        }
      });
    });
  }

  /// Sync all channels when coming online
  Future<void> _syncAllChannels() async {
    final channelIds = state.messagesByChannel.keys.toList();
    for (final channelId in channelIds) {
      await _syncChannel(channelId);
    }
  }

  /// Sync a specific channel (fetch latest + send pending messages)
  Future<void> _syncChannel(String channelId) async {
    try {
      // Sync pending messages first
      await _repository.syncPendingMessages(channelId);

      // Then refresh messages from API
      await fetchMessages(channelId, forceRefresh: true);
    } catch (e) {
      // Ignore sync errors
    }
  }

  void _setupSignalRListeners() {
    // Connection state'i dinle ve connection kurulduğunda listener'ları kaydet
    _ref.listen<ChatHubState>(chatHubProvider, (previous, next) {
      // Connection kurulduğunda listener'ları kaydet (sadece bir kez)
      if (next.isConnected && !_listenersRegistered) {
        _registerListeners();
      }
    });

    // Eğer zaten bağlıysa hemen kaydet
    final chatHubState = _ref.read(chatHubProvider);
    if (chatHubState.isConnected && !_listenersRegistered) {
      _registerListeners();
    }
  }

  void _registerListeners() {
    if (_listenersRegistered) {
      return;
    }

    final chatHub = _ref.read(chatHubProvider.notifier);
    final connection = _ref.read(chatHubServiceProvider).connection;

    if (connection == null) {
      return;
    }

    _listenersRegistered = true;

    // Listen to ReceiveMessage event
    chatHub.on('ReceiveMessage', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final messageJson = args[0] as Map<String, dynamic>;
          print('🔔 [MessageProvider] ReceiveMessage event received');
          print('🔔 [MessageProvider] Message JSON keys: ${messageJson.keys.toList()}');
          print('🔔 [MessageProvider] Attachments field: ${messageJson['attachments']} (type: ${messageJson['attachments']?.runtimeType})');
          
          final message = MessageDto.fromJson(messageJson);
          
          print('🔔 [MessageProvider] Parsed message: id=${message.id}, attachments=${message.attachments?.length ?? 0}');

          // Check if we have a pending message with same content from current user
          final channelMessages =
              state.messagesByChannel[message.channelId] ?? [];
          final authState = _ref.read(authProvider);
          final currentUserId = authState.user?.id;

          if (currentUserId != null && message.userId == currentUserId) {
            // Try to find pending message with same content
            final pendingIndex = channelMessages.indexWhere(
              (m) =>
                  m.isPending &&
                  m.content == message.content &&
                  m.userId == message.userId,
            );

            if (pendingIndex >= 0) {
              print('🔄 [MessageProvider] Replacing pending message with real message');
              print('🔄 [MessageProvider] Pending attachments: ${channelMessages[pendingIndex].attachments?.length ?? 0}');
              print('🔄 [MessageProvider] Real message attachments: ${message.attachments?.length ?? 0}');
              // Replace pending message with real message
              _replacePendingMessage(
                message.channelId,
                channelMessages[pendingIndex].id,
                message,
              );
              return;
            }
          }

          // Normal add (not replacing pending)
          print('➕ [MessageProvider] Adding new message to channel');
          _addMessageToChannel(message.channelId, message);
        } catch (e, stackTrace) {
          print('❌ [MessageProvider] Error parsing ReceiveMessage: $e');
          print('❌ [MessageProvider] Stack trace: $stackTrace');
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
      // Backend formatı: new { userId, username, channelId } - tek bir object
      if (args != null && args.length >= 1) {
        try {
          // args[0] bir Map olmalı: { userId, username, channelId }
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final channelId = data['channelId']?.toString() ?? '';
            final userId = data['userId']?.toString() ?? '';
            final username = data['username']?.toString() ?? userId;

            // UserDto oluştur
            final user = UserDto(
              id: userId,
              username: username,
              email: '',
              createdAt: DateTime.now(),
              status: UserStatus.offline,
            );
            _addTypingUser(channelId, user);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to UserStoppedTyping event
    chatHub.on('UserStoppedTyping', (args) {
      // Backend formatı: new { userId, channelId } - tek bir object
      if (args != null && args.length >= 1) {
        try {
          // args[0] bir Map olmalı: { userId, channelId }
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final channelId = data['channelId']?.toString() ?? '';
            final userId = data['userId']?.toString() ?? '';
            _removeTypingUser(channelId, userId);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to UserMentioned event
    chatHub.on('UserMentioned', (args) {
      if (args != null && args.length >= 1) {
        try {
          // args[0] should be MessageMentionDto JSON
          if (args[0] is Map) {
            final mentionJson = args[0] as Map<String, dynamic>;
            final mention = MessageMentionDto.fromJson(mentionJson);

            // Check if mention is for current user
            final authState = _ref.read(authProvider);
            final currentUserId = authState.user?.id;

            // Ignore if user mentioned themselves
            if (currentUserId != null &&
                mention.mentionedUserId == currentUserId) {
              return;
            }

            // Add mention to mention provider
            _ref.read(mentionProvider.notifier).addMention(mention);

            // Refresh unread count
            _ref.read(mentionProvider.notifier).fetchUnreadMentionCount();

            // Show in-app notification (foreground only)
            // Note: We can't access BuildContext here, so we'll use a global navigator key
            // For now, we'll just update the state - UI can show notification based on state
            // In a real app, you'd use a notification service or overlay
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // ========== DM Event Listeners ==========

    // Listen to DMReceiveMessage event
    chatHub.on('DMReceiveMessage', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final messageJson = args[0] as Map<String, dynamic>;
          final dmMessage = DirectMessageDto.fromJson(messageJson);
          final message = dmMessage.toMessageDto(); // Convert to MessageDto

          // Check if we have a pending message with same content from current user
          final dmMessages = state.messagesByChannel[message.channelId] ?? [];
          final authState = _ref.read(authProvider);
          final currentUserId = authState.user?.id;

          if (currentUserId != null && message.userId == currentUserId) {
            // Try to find pending message with same content
            final pendingIndex = dmMessages.indexWhere(
              (m) =>
                  m.isPending &&
                  m.content == message.content &&
                  m.userId == message.userId,
            );

            if (pendingIndex >= 0) {
              // Replace pending message with real message
              _replacePendingMessage(
                message.channelId,
                dmMessages[pendingIndex].id,
                message,
              );
              return;
            }
          }

          // Normal add (not replacing pending)
          _addMessageToChannel(message.channelId, message);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to DMMessageEdited event
    chatHub.on('DMMessageEdited', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final messageJson = args[0] as Map<String, dynamic>;
          final dmMessage = DirectMessageDto.fromJson(messageJson);
          final message = dmMessage.toMessageDto(); // Convert to MessageDto
          _updateMessageInChannel(message.channelId, message);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to DMMessageDeleted event
    chatHub.on('DMMessageDeleted', (args) {
      if (args != null && args.length >= 2) {
        try {
          final dmChannelId = args[0] as String;
          final messageId = args[1] as String;
          _removeMessageFromChannel(dmChannelId, messageId);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to DMUserTyping event
    chatHub.on('DMUserTyping', (args) {
      // Backend formatı: { userId, username, dmChannelId }
      if (args != null && args.length >= 1) {
        try {
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final dmChannelId = data['dmChannelId']?.toString() ?? '';
            final userId = data['userId']?.toString() ?? '';
            final username = data['username']?.toString() ?? userId;

            // UserDto oluştur
            final user = UserDto(
              id: userId,
              username: username,
              email: '',
              createdAt: DateTime.now(),
              status: UserStatus.offline,
            );
            _addTypingUser(dmChannelId, user);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to DMUserStoppedTyping event
    chatHub.on('DMUserStoppedTyping', (args) {
      // Backend formatı: { userId, dmChannelId }
      if (args != null && args.length >= 1) {
        try {
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final dmChannelId = data['dmChannelId']?.toString() ?? '';
            final userId = data['userId']?.toString() ?? '';
            _removeTypingUser(dmChannelId, userId);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });
  }

  /// Fetch messages for a channel
  Future<void> fetchMessages(
    String channelId, {
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    final currentMessages = state.getMessagesForChannel(channelId);
    final isLoading = state.isLoadingChannel(channelId);

    if (isLoading) return;

    // If not forcing refresh and we have cached messages, load from cache first
    if (!forceRefresh && currentMessages.isEmpty) {
      final cachedMessages = MessageCacheService.getCachedMessages(channelId);
      if (cachedMessages.isNotEmpty) {
        state = state.copyWith(
          messagesByChannel: {
            ...state.messagesByChannel,
            channelId: cachedMessages,
          },
        );
        // Continue to fetch from API in background
      }
    }

    state = state.copyWith(
      isLoadingByChannel: {...state.isLoadingByChannel, channelId: true},
      errorByChannel: {...state.errorByChannel, channelId: null},
    );

    try {
      final beforeMessageId = loadMore && currentMessages.isNotEmpty
          ? currentMessages.last.id
          : null;
      final messages = await _repository.fetchMessages(
        channelId,
        limit: 50,
        beforeMessageId: beforeMessageId,
        forceRefresh: forceRefresh,
      );

      final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
        state.messagesByChannel,
      );
      final existingMessages = updatedMessagesByChannel[channelId] ?? [];

      if (loadMore) {
        // Append older messages
        updatedMessagesByChannel[channelId] = [
          ...existingMessages,
          ...messages,
        ];
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
        isLoadingByChannel: {...state.isLoadingByChannel, channelId: false},
        hasMoreByChannel: {...state.hasMoreByChannel, channelId: hasMore},
        oldestMessageIdByChannel: oldestMessageId != null
            ? {...state.oldestMessageIdByChannel, channelId: oldestMessageId}
            : state.oldestMessageIdByChannel,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingByChannel: {...state.isLoadingByChannel, channelId: false},
        errorByChannel: {...state.errorByChannel, channelId: e.toString()},
      );
    }
  }

  /// Create a new message with optimistic update
  Future<MessageDto?> createMessage(
    String channelId,
    CreateMessageDto dto,
  ) async {
    final authState = _ref.read(authProvider);
    final currentUser = authState.user;

    if (currentUser == null) {
      return null;
    }

    // Create pending message immediately (optimistic update)
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    
    // Parse attachments from DTO for pending message display
    List<MessageAttachmentDto>? pendingAttachments;
    if (dto.attachments != null && dto.attachments!.isNotEmpty) {
      try {
        final decoded = jsonDecode(dto.attachments!);
        if (decoded is List) {
          pendingAttachments = decoded
              .map((a) => MessageAttachmentDto.fromJson(a as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // Ignore parse errors for pending message
      }
    }
    
    final pendingMessage = MessageDto(
      id: pendingId,
      channelId: channelId,
      userId: currentUser.id,
      content: dto.content,
      createdAt: DateTime.now(),
      user: currentUser,
      attachments: pendingAttachments,
      isPending: true, // Mark as pending
    );

    // Add pending message to UI immediately
    _addMessageToChannel(channelId, pendingMessage);

    try {
      final message = await _repository.createMessage(channelId, dto);

      // If message is null, it means it was queued (offline mode)
      if (message == null) {
        // Keep pending message, it will be sent when online
        return null;
      }

      // Replace pending message with real message
      _replacePendingMessage(channelId, pendingId, message);

      return message;
    } catch (e) {
      // Remove pending message on error
      _removeMessageFromChannel(channelId, pendingId);

      state = state.copyWith(
        errorByChannel: {...state.errorByChannel, channelId: e.toString()},
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
      final message = await _repository.updateMessage(
        channelId,
        messageId,
        dto,
      );
      _updateMessageInChannel(channelId, message);
      return message;
    } catch (e) {
      state = state.copyWith(
        errorByChannel: {...state.errorByChannel, channelId: e.toString()},
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
        errorByChannel: {...state.errorByChannel, channelId: e.toString()},
      );
    }
  }

  /// Add message to channel (used by SignalR events)
  void _addMessageToChannel(String channelId, MessageDto message) {
    final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
      state.messagesByChannel,
    );
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

    // Cache the message
    MessageCacheService.saveMessage(message);
  }

  /// Update message in channel (used by SignalR events)
  void _updateMessageInChannel(String channelId, MessageDto message) {
    final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
      state.messagesByChannel,
    );
    final existingMessages = updatedMessagesByChannel[channelId] ?? [];

    final index = existingMessages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      existingMessages[index] = message;
      updatedMessagesByChannel[channelId] = existingMessages;
      state = state.copyWith(messagesByChannel: updatedMessagesByChannel);

      // Update cache
      MessageCacheService.saveMessage(message);
    }
  }

  /// Remove message from channel (used by SignalR events)
  void _removeMessageFromChannel(String channelId, String messageId) {
    final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
      state.messagesByChannel,
    );
    final existingMessages = updatedMessagesByChannel[channelId] ?? [];

    updatedMessagesByChannel[channelId] = existingMessages
        .where((m) => m.id != messageId)
        .toList();

    state = state.copyWith(messagesByChannel: updatedMessagesByChannel);

    // Remove from cache (only if not pending)
    final removedMessage = existingMessages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => MessageDto(
        id: '',
        channelId: channelId,
        userId: '',
        content: '',
        createdAt: DateTime.now(),
      ),
    );
    if (!removedMessage.isPending) {
      MessageCacheService.removeMessage(channelId, messageId);
    }
  }

  /// Replace pending message with real message
  void _replacePendingMessage(
    String channelId,
    String pendingId,
    MessageDto realMessage,
  ) {
    final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
      state.messagesByChannel,
    );
    final existingMessages = updatedMessagesByChannel[channelId] ?? [];

    final index = existingMessages.indexWhere((m) => m.id == pendingId);
    if (index >= 0) {
      existingMessages[index] = realMessage;
      updatedMessagesByChannel[channelId] = existingMessages;
      state = state.copyWith(messagesByChannel: updatedMessagesByChannel);

      // Cache the real message
      MessageCacheService.saveMessage(realMessage);
    }
  }

  /// Add typing user
  void _addTypingUser(String channelId, UserDto user) {
    final updatedTypingUsers = Map<String, Map<String, UserDto>>.from(
      state.typingUsersByChannel,
    );
    final typingUsers = Map<String, UserDto>.from(
      updatedTypingUsers[channelId] ?? {},
    );
    typingUsers[user.id] = user;
    updatedTypingUsers[channelId] = typingUsers;

    state = state.copyWith(typingUsersByChannel: updatedTypingUsers);
  }

  /// Remove typing user
  void _removeTypingUser(String channelId, String userId) {
    final updatedTypingUsers = Map<String, Map<String, UserDto>>.from(
      state.typingUsersByChannel,
    );
    final typingUsers = Map<String, UserDto>.from(
      updatedTypingUsers[channelId] ?? {},
    );
    typingUsers.remove(userId);
    updatedTypingUsers[channelId] = typingUsers;

    state = state.copyWith(typingUsersByChannel: updatedTypingUsers);
  }

  /// Clear messages for a channel
  void clearMessages(String channelId) {
    final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
      state.messagesByChannel,
    );
    updatedMessagesByChannel.remove(channelId);

    final updatedTypingUsers = Map<String, Map<String, UserDto>>.from(
      state.typingUsersByChannel,
    );
    updatedTypingUsers.remove(channelId);

    state = state.copyWith(
      messagesByChannel: updatedMessagesByChannel,
      typingUsersByChannel: updatedTypingUsers,
    );
  }

  // ========== DM Messages Methods ==========

  /// Fetch DM messages for a DM channel
  Future<void> fetchDMMessages(
    String dmId, {
    int page = 1,
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    final currentMessages = state.getMessagesForChannel(dmId);
    final isLoading = state.isLoadingChannel(dmId);

    if (isLoading) return;

    // If not forcing refresh and we have cached messages, load from cache first
    if (!forceRefresh && currentMessages.isEmpty) {
      final cachedMessages = MessageCacheService.getCachedMessages(dmId);
      if (cachedMessages.isNotEmpty) {
        state = state.copyWith(
          messagesByChannel: {
            ...state.messagesByChannel,
            dmId: cachedMessages,
          },
        );
        // Continue to fetch from API in background
      }
    }

    state = state.copyWith(
      isLoadingByChannel: {...state.isLoadingByChannel, dmId: true},
      errorByChannel: {...state.errorByChannel, dmId: null},
    );

    try {
      final actualPage = loadMore && currentMessages.isNotEmpty
          ? page + 1
          : page;
      
      final dmMessages = await _repository.fetchDMMessages(
        dmId,
        page: actualPage,
        pageSize: 50,
        forceRefresh: forceRefresh,
      );

      // Convert DirectMessageDto to MessageDto
      final messages = dmMessages.map((dm) => dm.toMessageDto()).toList();

      final updatedMessagesByChannel = Map<String, List<MessageDto>>.from(
        state.messagesByChannel,
      );
      final existingMessages = updatedMessagesByChannel[dmId] ?? [];

      if (loadMore) {
        // Append older messages
        updatedMessagesByChannel[dmId] = [
          ...existingMessages,
          ...messages,
        ];
      } else {
        // Replace with new messages
        updatedMessagesByChannel[dmId] = messages;
      }

      // Sort by createdAt (oldest first)
      updatedMessagesByChannel[dmId]!.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );

      // Since backend doesn't provide pagination metadata, assume hasMore if we got pageSize messages
      final hasMore = messages.length >= 50;
      final oldestMessageId = messages.isNotEmpty ? messages.first.id : null;

      state = state.copyWith(
        messagesByChannel: updatedMessagesByChannel,
        isLoadingByChannel: {...state.isLoadingByChannel, dmId: false},
        hasMoreByChannel: {...state.hasMoreByChannel, dmId: hasMore},
        oldestMessageIdByChannel: oldestMessageId != null
            ? {...state.oldestMessageIdByChannel, dmId: oldestMessageId}
            : state.oldestMessageIdByChannel,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingByChannel: {...state.isLoadingByChannel, dmId: false},
        errorByChannel: {...state.errorByChannel, dmId: e.toString()},
      );
    }
  }

  /// Create a new DM message with optimistic update
  Future<MessageDto?> createDMMessage(
    String dmId,
    CreateMessageDto dto,
  ) async {
    final authState = _ref.read(authProvider);
    final currentUser = authState.user;

    if (currentUser == null) {
      return null;
    }

    // Create pending message immediately (optimistic update)
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    
    // Parse attachments from DTO for pending message display
    List<MessageAttachmentDto>? pendingAttachments;
    if (dto.attachments != null && dto.attachments!.isNotEmpty) {
      try {
        final decoded = jsonDecode(dto.attachments!);
        if (decoded is List) {
          pendingAttachments = decoded
              .map((a) => MessageAttachmentDto.fromJson(a as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // Ignore parse errors for pending message
      }
    }
    
    final pendingMessage = MessageDto(
      id: pendingId,
      channelId: dmId,
      userId: currentUser.id,
      content: dto.content,
      createdAt: DateTime.now(),
      user: currentUser,
      attachments: pendingAttachments,
      isPending: true, // Mark as pending
    );

    // Add pending message to UI immediately
    _addMessageToChannel(dmId, pendingMessage);

    try {
      final dmMessage = await _repository.createDMMessage(dmId, dto);

      // If message is null, it means it was queued (offline mode)
      if (dmMessage == null) {
        // Keep pending message, it will be sent when online
        return null;
      }

      // Convert to MessageDto and replace pending message
      final message = dmMessage.toMessageDto();
      _replacePendingMessage(dmId, pendingId, message);

      return message;
    } catch (e) {
      // Remove pending message on error
      _removeMessageFromChannel(dmId, pendingId);

      state = state.copyWith(
        errorByChannel: {...state.errorByChannel, dmId: e.toString()},
      );
      return null;
    }
  }

  /// Update a DM message
  Future<MessageDto?> updateDMMessage(
    String dmId,
    String messageId,
    UpdateMessageDto dto,
  ) async {
    try {
      final dmMessage = await _repository.updateDMMessage(dmId, messageId, dto);
      final message = dmMessage.toMessageDto(); // Convert to MessageDto
      _updateMessageInChannel(dmId, message);
      return message;
    } catch (e) {
      state = state.copyWith(
        errorByChannel: {...state.errorByChannel, dmId: e.toString()},
      );
      return null;
    }
  }

  /// Delete a DM message
  Future<void> deleteDMMessage(String dmId, String messageId) async {
    try {
      await _repository.deleteDMMessage(dmId, messageId);
      _removeMessageFromChannel(dmId, messageId);
    } catch (e) {
      state = state.copyWith(
        errorByChannel: {...state.errorByChannel, dmId: e.toString()},
      );
    }
  }
}

/// Message provider
final messageProvider = StateNotifierProvider<MessageNotifier, MessageState>((
  ref,
) {
  final repository = ref.watch(messageRepositoryProvider);
  return MessageNotifier(repository, ref);
});
