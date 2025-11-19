import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/message/message_dto.dart';
import '../models/message/create_message_dto.dart';
import '../services/api/api_client.dart';

/// Message repository for message operations
class MessageRepository {
  final ApiClient _apiClient;

  MessageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Get messages for a channel with pagination
  Future<List<MessageDto>> fetchMessages(
    String channelId, {
    int? limit = 50,
    String? beforeMessageId,
    String? afterMessageId,
  }) async {
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

      // Debug: Response'u logla
      print('DEBUG: Response type: ${response.data.runtimeType}');
      print('DEBUG: Response data: ${response.data}');
      if (response.data is Map) {
        print('DEBUG: Response keys: ${(response.data as Map).keys.toList()}');
        if ((response.data as Map).containsKey('messages')) {
          print(
            'DEBUG: messages type: ${(response.data as Map)['messages'].runtimeType}',
          );
          print('DEBUG: messages value: ${(response.data as Map)['messages']}');
        }
      }

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

      return data
          .map((json) => MessageDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch messages',
      );
    } catch (e) {
      // Daha detaylı hata mesajı
      final errorMessage = 'Failed to fetch messages: ${e.toString()}';
      if (e is TypeError) {
        print('DEBUG: TypeError details: ${e.toString()}');
        print('DEBUG: Stack trace: ${StackTrace.current}');
      }
      print('DEBUG: Exception type: ${e.runtimeType}');
      print('DEBUG: Exception message: ${e.toString()}');
      throw Exception(errorMessage);
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
  Future<MessageDto> createMessage(
    String channelId,
    CreateMessageDto dto,
  ) async {
    try {
      final response = await _apiClient.post(
        '/channels/$channelId/messages',
        data: dto.toJson(),
      );
      return MessageDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
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
      return MessageDto.fromJson(response.data as Map<String, dynamic>);
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
}
