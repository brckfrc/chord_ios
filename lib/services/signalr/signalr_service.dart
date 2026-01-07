import 'package:signalr_core/signalr_core.dart';
import '../../core/config/app_config.dart';
import '../storage/secure_storage.dart';
import '../logging/log_service.dart';

/// Base SignalR service for connection management
class SignalRService {
  final SecureStorageService _storage = SecureStorageService();
  final LogService _logger = LogService('SignalRService');
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
      _logger.error('No access token available');
      throw Exception('No access token available');
    }

    // Backend hub path: /hubs/{hubName}
    // Default (production): use /api/hubs because Nginx strips /api prefix
    // Development: use /hubs directly (no Nginx proxy)
    final hubPath = AppConfig.isDevelopment 
        ? '/hubs/${_hubName ?? 'chat'}'
        : '/api/hubs/${_hubName ?? 'chat'}';
    final hubUrl = '${AppConfig.signalRUrl}$hubPath';
    _logger.debug('Creating SignalR connection to: $hubUrl (development: ${AppConfig.isDevelopment})');
    
    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Setup connection event listeners for debugging
    _connection!.onclose((error) {
      _logger.warn('SignalR connection closed: ${error?.toString() ?? 'No error'}');
    });

    _connection!.onreconnecting((error) {
      _logger.info('SignalR reconnecting: ${error?.toString() ?? 'No error'}');
    });

    _connection!.onreconnected((connectionId) {
      _logger.info('SignalR reconnected: $connectionId');
    });

    return _connection!;
  }

  /// Start connection
  Future<void> start() async {
    try {
      final connection = await getConnection();
      final currentState = connection.state;
      _logger.debug('Starting SignalR connection. Current state: $currentState');
      
      if (currentState == HubConnectionState.disconnected) {
        _logger.info('Attempting to start SignalR connection...');
        await connection.start();
        _logger.info('SignalR connection started successfully. New state: ${connection.state}');
      } else {
        _logger.debug('Connection already in state: $currentState, skipping start');
      }
    } catch (e) {
      final hubPath = AppConfig.isDevelopment 
          ? '/hubs/${_hubName ?? 'chat'}'
          : '/api/hubs/${_hubName ?? 'chat'}';
      final hubUrl = '${AppConfig.signalRUrl}$hubPath';
      _logger.error('Failed to start SignalR connection to $hubUrl: $e');
      
      // Provide more helpful error messages
      if (e.toString().contains('405')) {
        throw Exception(
          'SignalR connection failed: Backend returned 405 (Method Not Allowed). '
          'Please check:\n'
          '1. Backend is running and accessible at $hubUrl\n'
          '2. SignalR hub is properly configured in backend\n'
          '3. Backend allows POST requests to /hubs/${_hubName ?? 'chat'}/negotiate'
        );
      } else if (e.toString().contains('404')) {
        throw Exception(
          'SignalR connection failed: Backend returned 404 (Not Found). '
          'Please check if SignalR hub endpoint exists at $hubUrl'
        );
      } else {
        rethrow;
      }
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

