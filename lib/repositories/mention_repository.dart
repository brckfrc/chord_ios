import 'package:dio/dio.dart';
import '../models/mention/message_mention_dto.dart';
import '../services/api/api_client.dart';

/// Mention repository for mention operations
class MentionRepository {
  final ApiClient _apiClient;

  MentionRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Get all mentions for the current user
  /// [unreadOnly] if true, returns only unread mentions
  Future<List<MessageMentionDto>> getUserMentions({
    bool unreadOnly = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (unreadOnly) 'unreadOnly': 'true',
      };

      final response = await _apiClient.get(
        '/mentions',
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => MessageMentionDto.fromJson(
                json as Map<String, dynamic>,
              ))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch mentions',
      );
    } catch (e) {
      throw Exception('Failed to fetch mentions: ${e.toString()}');
    }
  }

  /// Get unread mention count for the current user
  Future<int> getUnreadMentionCount() async {
    try {
      final response = await _apiClient.get('/mentions/unread-count');
      final data = response.data as Map<String, dynamic>;
      return data['count'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch unread mention count',
      );
    } catch (e) {
      throw Exception(
        'Failed to fetch unread mention count: ${e.toString()}',
      );
    }
  }

  /// Mark a mention as read
  Future<void> markMentionAsRead(String mentionId) async {
    try {
      await _apiClient.patch('/mentions/$mentionId/mark-read');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Mention not found');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to mark mention as read',
      );
    } catch (e) {
      throw Exception(
        'Failed to mark mention as read: ${e.toString()}',
      );
    }
  }
}

