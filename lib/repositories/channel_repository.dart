import 'package:dio/dio.dart';
import '../models/guild/channel_dto.dart';
import '../models/guild/create_channel_dto.dart';
import '../services/api/api_client.dart';

/// Channel repository for channel operations
class ChannelRepository {
  final ApiClient _apiClient;

  ChannelRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get all channels for a guild
  Future<List<ChannelDto>> fetchChannels(String guildId) async {
    try {
      final response = await _apiClient.get('/guilds/$guildId/channels');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => ChannelDto.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch channels');
    } catch (e) {
      throw Exception('Failed to fetch channels: ${e.toString()}');
    }
  }

  /// Get channel by ID
  Future<ChannelDto> getChannelById(String guildId, String channelId) async {
    try {
      final response = await _apiClient.get('/guilds/$guildId/channels/$channelId');
      return ChannelDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Channel not found');
      }
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch channel');
    } catch (e) {
      throw Exception('Failed to fetch channel: ${e.toString()}');
    }
  }

  /// Create a new channel in a guild
  Future<ChannelDto> createChannel(String guildId, CreateChannelDto dto) async {
    try {
      final response = await _apiClient.post(
        '/guilds/$guildId/channels',
        data: dto.toJson(),
      );
      return ChannelDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create channel');
    } catch (e) {
      throw Exception('Failed to create channel: ${e.toString()}');
    }
  }
}

