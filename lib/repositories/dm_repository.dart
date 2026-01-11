import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/dm/dm_dto.dart';
import '../services/api/api_client.dart';

/// DM Repository
class DMRepository {
  final ApiClient _apiClient;

  DMRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetch all DMs for current user
  Future<List<DMDto>> fetchDMs() async {
    try {
      final response = await _apiClient.get('/DMs');
      
      // Backend returns List<DMDto>
      if (response.data is List) {
        return (response.data as List)
            .map((json) => DMDto.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map) {
        // Handle case where response might be wrapped
        final responseMap = response.data as Map<String, dynamic>;
        if (responseMap.containsKey('data') && responseMap['data'] is List) {
          return (responseMap['data'] as List)
              .map((json) => DMDto.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      throw Exception('Unexpected response format from /DMs endpoint');
    } catch (e) {
      throw Exception('Failed to fetch DMs: $e');
    }
  }

  /// Get DM by ID
  Future<DMDto> getDMById(String dmId) async {
    try {
      // TODO: Replace with real API endpoint when backend is ready
      // const response = await _apiClient.get('/dms/$dmId');
      // return DMDto.fromJson(response.data);
      
      // Mock implementation
      final dms = await fetchDMs();
      final dm = dms.firstWhere(
        (dm) => dm.id == dmId,
        orElse: () => throw Exception('DM not found'),
      );
      return dm;
    } catch (e) {
      throw Exception('Failed to get DM: $e');
    }
  }

  /// Create a new DM with a user
  Future<DMDto> createDM(String userId) async {
    try {
      debugPrint('[DMRepository] Creating DM with user: $userId');
      final response = await _apiClient.post('/dms/users/$userId');
      debugPrint('[DMRepository] DM created successfully: ${response.data['id']}');
      return DMDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        '[DMRepository] DioException: ${e.type}, status: ${e.response?.statusCode}, message: ${e.response?.data}',
      );
      // Backend'den gelen error message'ı kullan
      final errorMessage = e.response?.data?['message'] as String?;
      if (errorMessage != null) {
        throw Exception(errorMessage);
      }
      // Fallback: generic error message
      throw Exception('Failed to create DM: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      debugPrint('[DMRepository] General exception: $e');
      throw Exception('Failed to create DM: ${e.toString()}');
    }
  }

  /// Mark DM as read
  Future<void> markDMAsRead(String dmId) async {
    try {
      await _apiClient.post('/DMs/$dmId/mark-read');
    } catch (e) {
      throw Exception('Failed to mark DM as read: $e');
    }
  }
}

