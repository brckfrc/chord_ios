import 'package:signalr_core/signalr_core.dart';
import '../../core/config/app_config.dart';
import '../storage/secure_storage.dart';

/// Base SignalR service for connection management
class SignalRService {
  final SecureStorageService _storage = SecureStorageService();
  HubConnection? _connection;
  String? _hubName;

  SignalRService({String? hubName}) : _hubName = hubName;

  /// Get or create connection
  Future<HubConnection> getConnection() async {
    if (_connection != null && _connection!.state == HubConnectionState.connected) {
      return _connection!;
    }

    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No access token available');
    }

    final hubUrl = '${AppConfig.signalRUrl}/${_hubName ?? 'chat'}';
    
    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    return _connection!;
  }

  /// Start connection
  Future<void> start() async {
    final connection = await getConnection();
    if (connection.state == HubConnectionState.disconnected) {
      await connection.start();
    }
  }

  /// Stop connection
  Future<void> stop() async {
    if (_connection != null) {
      await _connection!.stop();
      _connection = null;
    }
  }

  /// Check if connected
  bool get isConnected => _connection?.state == HubConnectionState.connected;

  /// Get connection state
  HubConnectionState? get state => _connection?.state;

  /// Get connection instance
  HubConnection? get connection => _connection;
}

