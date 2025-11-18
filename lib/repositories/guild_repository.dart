import 'package:dio/dio.dart';
import '../models/guild/guild_dto.dart';
import '../models/guild/create_guild_dto.dart';
import '../services/api/api_client.dart';

/// Guild repository for guild operations
class GuildRepository {
  final ApiClient _apiClient;

  GuildRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get all guilds for the current user
  Future<List<GuildDto>> fetchGuilds() async {
    try {
      final response = await _apiClient.get('/guilds');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => GuildDto.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch guilds');
    } catch (e) {
      throw Exception('Failed to fetch guilds: ${e.toString()}');
    }
  }

  /// Get guild by ID
  Future<GuildDto> getGuildById(String id) async {
    try {
      final response = await _apiClient.get('/guilds/$id');
      return GuildDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Guild not found');
      }
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch guild');
    } catch (e) {
      throw Exception('Failed to fetch guild: ${e.toString()}');
    }
  }

  /// Create a new guild
  Future<GuildDto> createGuild(CreateGuildDto dto) async {
    try {
      final response = await _apiClient.post('/guilds', data: dto.toJson());
      return GuildDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create guild');
    } catch (e) {
      throw Exception('Failed to create guild: ${e.toString()}');
    }
  }
}

