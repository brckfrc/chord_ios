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
      // TODO: Replace with real API endpoint when backend is ready
      // For now, return empty list (backend doesn't have DM endpoints yet)
      // const response = await _apiClient.get('/users/me/dms');
      // return (response.data as List)
      //     .map((json) => DMDto.fromJson(json))
      //     .toList();
      
      // Mock data for now
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
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
      
      throw Exception('DM not found');
    } catch (e) {
      throw Exception('Failed to get DM: $e');
    }
  }

  /// Create a new DM with a user
  Future<DMDto> createDM(String userId) async {
    try {
      // TODO: Replace with real API endpoint when backend is ready
      // const response = await _apiClient.post('/users/$userId/dm');
      // return DMDto.fromJson(response.data);
      
      throw Exception('DM creation not implemented yet');
    } catch (e) {
      throw Exception('Failed to create DM: $e');
    }
  }
}

