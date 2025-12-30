import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/message/message_dto.dart';
import '../models/message/direct_message_dto.dart';
import '../models/message/create_message_dto.dart';
import '../services/api/api_client.dart';
import '../services/database/message_cache_service.dart';
import '../services/network/connectivity_service.dart';

/// Message repository for message operations
class MessageRepository {
  final ApiClient _apiClient;
  final ConnectivityService? _connectivityService;

  MessageRepository({
    ApiClient? apiClient,
    ConnectivityService? connectivityService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _connectivityService = connectivityService;

  /// Get messages for a channel with pagination
  /// Returns cached messages if offline, otherwise fetches from API
  Future<List<MessageDto>> fetchMessages(
    String channelId, {
    int? limit = 50,
    String? beforeMessageId,
    String? afterMessageId,
    bool forceRefresh = false,
  }) async {
    // Check connectivity
    final isOnline = _connectivityService != null
        ? await _connectivityService.checkConnectivity() ==
              NetworkStatus.connected
        : true;

    // If offline and not forcing refresh, return cached messages
    if (!isOnline && !forceRefresh) {
      final cachedMessages = MessageCacheService.getCachedMessages(channelId);
      if (cachedMessages.isNotEmpty) {
        return cachedMessages;
      }
    }

    try {
      final queryParams = <String, dynamic>{
        if (limit != null) 'limit': limit,
        if (beforeMessageId != null) 'before': beforeMessageId,
        if (afterMessageId != null) 'after': afterMessageId,
      };

      final response = await _apiClient.get(
        '/channels/$channelId/messages',
        queryParameters: queryParams,
      );

      // Handle different response formats
      // Backend returns: { "messages": [...], "totalCount": 10, ... }
      List<dynamic> data;
      final responseData = response.data;

      // Backend'in PaginatedMessagesDto formatı: Map olarak gelir, messages key'i öncelikli
      if (responseData is Map) {
        final responseMap = responseData as Map<String, dynamic>;
        // Backend'in formatı: messages key'i öncelikli
        if (responseMap.containsKey('messages')) {
          final messagesValue = responseMap['messages'];
          if (messagesValue is List) {
            data = messagesValue;
          } else {
            throw Exception(
              'Expected messages to be a List, but got ${messagesValue.runtimeType}',
            );
          }
        } else if (responseMap.containsKey('data')) {
          final dataValue = responseMap['data'];
          if (dataValue is List) {
            data = dataValue;
          } else {
            throw Exception(
              'Expected data to be a List, but got ${dataValue.runtimeType}',
            );
          }
        } else if (responseMap.containsKey('items')) {
          final itemsValue = responseMap['items'];
          if (itemsValue is List) {
            data = itemsValue;
          } else {
            throw Exception(
              'Expected items to be a List, but got ${itemsValue.runtimeType}',
            );
          }
        } else {
          // Debug: response'un içeriğini göster
          throw Exception(
            'Response does not contain messages, data, or items keys. Response keys: ${responseMap.keys.toList()}',
          );
        }
      } else if (responseData is List) {
        // Direct array response (fallback)
        data = responseData;
      } else if (responseData is String) {
        // JSON string response - parse it first
        try {
          final decoded = jsonDecode(responseData);
          if (decoded is List) {
            data = decoded;
          } else if (decoded is Map) {
            final responseMap = decoded as Map<String, dynamic>;
            // Backend'in formatı: messages key'i öncelikli
            if (responseMap.containsKey('messages')) {
              final messagesValue = responseMap['messages'];
              if (messagesValue is List) {
                data = messagesValue;
              } else {
                throw Exception(
                  'Expected messages to be a List, but got ${messagesValue.runtimeType}',
                );
              }
            } else if (responseMap.containsKey('data')) {
              final dataValue = responseMap['data'];
              if (dataValue is List) {
                data = dataValue;
              } else {
                throw Exception(
                  'Expected data to be a List, but got ${dataValue.runtimeType}',
                );
              }
            } else if (responseMap.containsKey('items')) {
              final itemsValue = responseMap['items'];
              if (itemsValue is List) {
                data = itemsValue;
              } else {
                throw Exception(
                  'Expected items to be a List, but got ${itemsValue.runtimeType}',
                );
              }
            } else {
              throw Exception(
                'Response does not contain messages, data, or items keys. Response keys: ${responseMap.keys.toList()}',
              );
            }
          } else {
            throw Exception(
              'Decoded JSON is neither List nor Map. Type: ${decoded.runtimeType}',
            );
          }
        } catch (e) {
          throw Exception('Failed to parse JSON response: ${e.toString()}');
        }
      } else {
        throw Exception(
          'Unexpected response type: ${responseData.runtimeType}. Expected Map, List, or String.',
        );
      }

      final messages = data
          .map((json) => MessageDto.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache messages if online
      if (isOnline) {
        await MessageCacheService.saveMessagesForChannel(channelId, messages);
      }

      return messages;
    } on DioException catch (e) {
      // If offline or network error, try to return cached messages
      if (!isOnline || e.type == DioExceptionType.connectionError) {
        final cachedMessages = MessageCacheService.getCachedMessages(channelId);
        if (cachedMessages.isNotEmpty) {
          return cachedMessages;
        }
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch messages',
      );
    } catch (e) {
      // If any error, try to return cached messages
      final cachedMessages = MessageCacheService.getCachedMessages(channelId);
      if (cachedMessages.isNotEmpty) {
        return cachedMessages;
      }

      throw Exception('Failed to fetch messages: ${e.toString()}');
    }
  }

  /// Get message by ID
  Future<MessageDto> getMessageById(String channelId, String messageId) async {
    try {
      final response = await _apiClient.get(
        '/channels/$channelId/messages/$messageId',
      );
      return MessageDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Message not found');
      }
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch message');
    } catch (e) {
      throw Exception('Failed to fetch message: ${e.toString()}');
    }
  }

  /// Create a new message
  /// If offline, adds to pending queue
  Future<MessageDto?> createMessage(
    String channelId,
    CreateMessageDto dto,
  ) async {
    // Check connectivity
    final isOnline = _connectivityService != null
        ? await _connectivityService.checkConnectivity() ==
              NetworkStatus.connected
        : true;

    // If offline, add to pending queue
    if (!isOnline) {
      await MessageCacheService.addPendingMessage(
        channelId,
        dto.content,
        replyToMessageId: dto.replyToMessageId,
        attachmentIds: dto.attachmentIds,
      );
      return null; // Return null to indicate message is queued
    }

    try {
      final response = await _apiClient.post(
        '/channels/$channelId/messages',
        data: dto.toJson(),
      );
      final message = MessageDto.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Cache the new message
      await MessageCacheService.saveMessage(message);

      return message;
    } on DioException catch (e) {
      // If network error, add to pending queue
      if (e.type == DioExceptionType.connectionError) {
        await MessageCacheService.addPendingMessage(
          channelId,
          dto.content,
          replyToMessageId: dto.replyToMessageId,
          attachmentIds: dto.attachmentIds,
        );
        return null;
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to create message',
      );
    } catch (e) {
      throw Exception('Failed to create message: ${e.toString()}');
    }
  }

  /// Update a message
  Future<MessageDto> updateMessage(
    String channelId,
    String messageId,
    UpdateMessageDto dto,
  ) async {
    try {
      final response = await _apiClient.put(
        '/channels/$channelId/messages/$messageId',
        data: dto.toJson(),
      );
      final message = MessageDto.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Update cache
      await MessageCacheService.saveMessage(message);

      return message;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Message not found');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to update message',
      );
    } catch (e) {
      throw Exception('Failed to update message: ${e.toString()}');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String channelId, String messageId) async {
    try {
      await _apiClient.delete('/channels/$channelId/messages/$messageId');

      // Remove from cache
      await MessageCacheService.removeMessage(channelId, messageId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Message not found');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to delete message',
      );
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  /// Sync pending messages (send queued messages when online)
  Future<void> syncPendingMessages(String channelId) async {
    final pendingMessages = MessageCacheService.getPendingMessages(channelId);
    if (pendingMessages.isEmpty) return;

    final isOnline = _connectivityService != null
        ? await _connectivityService.checkConnectivity() ==
              NetworkStatus.connected
        : true;

    if (!isOnline) {
      return;
    }

    // Send pending messages
    for (final pending in pendingMessages) {
      try {
        final dto = CreateMessageDto(
          content: pending['content'] as String,
          replyToMessageId: pending['replyToMessageId'] as String?,
          attachmentIds: pending['attachmentIds'] != null
              ? List<String>.from(pending['attachmentIds'] as List)
              : null,
        );
        await createMessage(channelId, dto);
      } catch (e) {
        // Continue with other messages
      }
    }

    // Clear pending messages after successful sync
    await MessageCacheService.clearPendingMessages(channelId);
  }

  // ========== DM Messages Methods ==========

  /// Fetch DM messages for a DM channel with pagination
  /// Returns cached messages if offline, otherwise fetches from API
  /// Backend returns List<DirectMessageDto> directly (no pagination metadata)
  Future<List<DirectMessageDto>> fetchDMMessages(
    String dmId, {
    int page = 1,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    // Check connectivity
    final isOnline = _connectivityService != null
        ? await _connectivityService.checkConnectivity() ==
              NetworkStatus.connected
        : true;

    // If offline and not forcing refresh, return cached messages
    if (!isOnline && !forceRefresh) {
      final cachedMessages = MessageCacheService.getCachedMessages(dmId);
      if (cachedMessages.isNotEmpty) {
        // Convert MessageDto to DirectMessageDto (for compatibility)
        // Note: This is a workaround since cache stores MessageDto
        // In a real scenario, we might want separate cache for DM messages
        return cachedMessages.map((msg) {
          return DirectMessageDto(
            id: msg.id,
            channelId: msg.channelId,
            senderId: msg.userId,
            content: msg.content,
            createdAt: msg.createdAt,
            editedAt: msg.editedAt,
            isDeleted: false,
            sender: msg.user,
          );
        }).toList();
      }
    }

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };

      final response = await _apiClient.get(
        '/DMs/$dmId/messages',
        queryParameters: queryParams,
      );

      // Backend returns List<DirectMessageDto> directly
      List<dynamic> data;
      final responseData = response.data;

      if (responseData is List) {
        data = responseData;
      } else if (responseData is Map) {
        // Handle wrapped response (if any)
        final responseMap = responseData as Map<String, dynamic>;
        if (responseMap.containsKey('data') && responseMap['data'] is List) {
          data = responseMap['data'] as List;
        } else {
          throw Exception('Unexpected response format from /DMs/$dmId/messages');
        }
      } else {
        throw Exception('Unexpected response type: ${responseData.runtimeType}');
      }

      final messages = data
          .map((json) => DirectMessageDto.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache messages if online (convert to MessageDto for cache compatibility)
      if (isOnline) {
        final messageDtos = messages.map((dm) => dm.toMessageDto()).toList();
        await MessageCacheService.saveMessagesForChannel(dmId, messageDtos);
      }

      return messages;
    } on DioException catch (e) {
      // If offline or network error, try to return cached messages
      if (!isOnline || e.type == DioExceptionType.connectionError) {
        final cachedMessages = MessageCacheService.getCachedMessages(dmId);
        if (cachedMessages.isNotEmpty) {
          return cachedMessages.map((msg) {
            return DirectMessageDto(
              id: msg.id,
              channelId: msg.channelId,
              senderId: msg.userId,
              content: msg.content,
              createdAt: msg.createdAt,
              editedAt: msg.editedAt,
              isDeleted: false,
              sender: msg.user,
            );
          }).toList();
        }
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch DM messages',
      );
    } catch (e) {
      // If any error, try to return cached messages
      final cachedMessages = MessageCacheService.getCachedMessages(dmId);
      if (cachedMessages.isNotEmpty) {
        return cachedMessages.map((msg) {
          return DirectMessageDto(
            id: msg.id,
            channelId: msg.channelId,
            senderId: msg.userId,
            content: msg.content,
            createdAt: msg.createdAt,
            editedAt: msg.editedAt,
            isDeleted: false,
            sender: msg.user,
          );
        }).toList();
      }

      throw Exception('Failed to fetch DM messages: ${e.toString()}');
    }
  }

  /// Create a new DM message
  /// If offline, adds to pending queue
  Future<DirectMessageDto?> createDMMessage(
    String dmId,
    CreateMessageDto dto,
  ) async {
    // Check connectivity
    final isOnline = _connectivityService != null
        ? await _connectivityService.checkConnectivity() ==
              NetworkStatus.connected
        : true;

    // If offline, add to pending queue
    if (!isOnline) {
      await MessageCacheService.addPendingMessage(
        dmId,
        dto.content,
        replyToMessageId: dto.replyToMessageId,
        attachmentIds: dto.attachmentIds,
      );
      return null; // Return null to indicate message is queued
    }

    try {
      final response = await _apiClient.post(
        '/DMs/$dmId/messages',
        data: dto.toJson(),
      );
      final message = DirectMessageDto.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Cache the new message (convert to MessageDto for cache compatibility)
      await MessageCacheService.saveMessage(message.toMessageDto());

      return message;
    } on DioException catch (e) {
      // If network error, add to pending queue
      if (e.type == DioExceptionType.connectionError) {
        await MessageCacheService.addPendingMessage(
          dmId,
          dto.content,
          replyToMessageId: dto.replyToMessageId,
          attachmentIds: dto.attachmentIds,
        );
        return null;
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to create DM message',
      );
    } catch (e) {
      throw Exception('Failed to create DM message: ${e.toString()}');
    }
  }

  /// Update a DM message
  Future<DirectMessageDto> updateDMMessage(
    String dmId,
    String messageId,
    UpdateMessageDto dto,
  ) async {
    try {
      final response = await _apiClient.put(
        '/DMs/$dmId/messages/$messageId',
        data: dto.toJson(),
      );
      final message = DirectMessageDto.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Update cache (convert to MessageDto for cache compatibility)
      await MessageCacheService.saveMessage(message.toMessageDto());

      return message;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('DM message not found');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to update DM message',
      );
    } catch (e) {
      throw Exception('Failed to update DM message: ${e.toString()}');
    }
  }

  /// Delete a DM message
  Future<void> deleteDMMessage(String dmId, String messageId) async {
    try {
      await _apiClient.delete('/DMs/$dmId/messages/$messageId');

      // Remove from cache
      await MessageCacheService.removeMessage(dmId, messageId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('DM message not found');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to delete DM message',
      );
    } catch (e) {
      throw Exception('Failed to delete DM message: ${e.toString()}');
    }
  }

  /// Sync pending DM messages (send queued messages when online)
  Future<void> syncPendingDMMessages(String dmId) async {
    final pendingMessages = MessageCacheService.getPendingMessages(dmId);
    if (pendingMessages.isEmpty) return;

    final isOnline = _connectivityService != null
        ? await _connectivityService.checkConnectivity() ==
              NetworkStatus.connected
        : true;

    if (!isOnline) {
      return;
    }

    // Send pending messages
    for (final pending in pendingMessages) {
      try {
        final dto = CreateMessageDto(
          content: pending['content'] as String,
          replyToMessageId: pending['replyToMessageId'] as String?,
          attachmentIds: pending['attachmentIds'] != null
              ? List<String>.from(pending['attachmentIds'] as List)
              : null,
        );
        await createDMMessage(dmId, dto);
      } catch (e) {
        // Continue with other messages
      }
    }

    // Clear pending messages after successful sync
    await MessageCacheService.clearPendingMessages(dmId);
  }
}
