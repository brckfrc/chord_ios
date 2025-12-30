import 'package:dio/dio.dart';
import '../models/invite/invite_info_dto.dart';
import '../models/guild/guild_dto.dart';
import '../services/api/api_client.dart';

/// Invite repository for invite operations
class InviteRepository {
  final ApiClient _apiClient;

  InviteRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Get invite info by code (public endpoint, no auth required)
  Future<InviteInfoDto> getInviteInfo(String code) async {
    try {
      final response = await _apiClient.get('/invites/$code');
      return InviteInfoDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Invite not found');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch invite info',
      );
    } catch (e) {
      throw Exception('Failed to fetch invite info: ${e.toString()}');
    }
  }

  /// Accept invite and join guild (requires authentication)
  Future<GuildDto> acceptInvite(String code) async {
    try {
      final response = await _apiClient.post('/invites/$code/accept');
      return GuildDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Invite not found');
      }
      if (e.response?.statusCode == 400) {
        // Backend might return specific error messages
        final errorMessage = e.response?.data['message'] as String?;
        if (errorMessage != null) {
          throw Exception(errorMessage);
        }
        throw Exception('Invalid invite code');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Failed to accept invite',
      );
    } catch (e) {
      throw Exception('Failed to accept invite: ${e.toString()}');
    }
  }
}
