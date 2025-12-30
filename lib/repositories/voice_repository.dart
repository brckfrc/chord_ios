import '../services/api/api_client.dart';
import '../models/voice/voice_token_dto.dart';
import '../services/logging/log_service.dart';

/// Voice repository (REST API backup)
/// Note: Primary method is SignalR via ChatHub.JoinVoiceChannel
/// This is a backup/alternative method
class VoiceRepository {
  final ApiClient _apiClient;
  final LogService _logger = LogService('VoiceRepository');

  VoiceRepository(this._apiClient);

  /// Get LiveKit token from REST API (backup method)
  /// Primary method: ChatHub.JoinVoiceChannel via SignalR
  Future<VoiceTokenResponseDto> getVoiceToken(String channelId) async {
    try {
      _logger.info('Requesting voice token via REST API (backup method)');
      
      final request = VoiceTokenRequestDto(channelId: channelId);
      final response = await _apiClient.post(
        '/Voice/token',
        data: request.toJson(),
      );

      _logger.info('Voice token received via REST API');
      return VoiceTokenResponseDto.fromJson(response.data);
    } catch (e) {
      _logger.error('Failed to get voice token via REST API: $e');
      rethrow;
    }
  }

  /// Get voice room status (optional)
  Future<Map<String, dynamic>> getRoomStatus(String roomId) async {
    try {
      final response = await _apiClient.get('/Voice/room/$roomId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get room status: $e');
      rethrow;
    }
  }
}
