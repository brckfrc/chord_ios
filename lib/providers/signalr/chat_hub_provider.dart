import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/signalr/signalr_service.dart';
import 'package:signalr_core/signalr_core.dart';

/// ChatHub connection state
class ChatHubState {
  final HubConnectionState? connectionState;
  final bool isConnected;
  final String? error;

  ChatHubState({
    this.connectionState,
    this.isConnected = false,
    this.error,
  });

  ChatHubState copyWith({
    HubConnectionState? connectionState,
    bool? isConnected,
    String? error,
  }) {
    return ChatHubState(
      connectionState: connectionState ?? this.connectionState,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

/// ChatHub service provider
final chatHubServiceProvider = Provider<SignalRService>((ref) {
  return SignalRService(hubName: 'chat');
});

/// ChatHub state provider
class ChatHubNotifier extends StateNotifier<ChatHubState> {
  final SignalRService _service;

  ChatHubNotifier(this._service) : super(ChatHubState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final connection = await _service.getConnection();
      
      // Listen to connection state changes
      connection.onclose((error) {
        state = state.copyWith(
          connectionState: HubConnectionState.disconnected,
          isConnected: false,
          error: error?.toString(),
        );
      });

      connection.onreconnecting((error) {
        state = state.copyWith(
          connectionState: HubConnectionState.reconnecting,
          isConnected: false,
          error: error?.toString(),
        );
      });

      connection.onreconnected((connectionId) {
        state = state.copyWith(
          connectionState: HubConnectionState.connected,
          isConnected: true,
          error: null,
        );
      });

      // Start connection
      await _service.start();
      
      // Connection kurulduktan sonra state'i güncelle
      // start() async olduğu için biraz bekle ve tekrar kontrol et
      await Future.delayed(const Duration(milliseconds: 500));
      
      final currentState = connection.state;
      final isConnected = currentState == HubConnectionState.connected;
      
      state = state.copyWith(
        connectionState: currentState,
        isConnected: isConnected,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isConnected: false,
      );
    }
  }

  /// Start connection
  Future<void> start() async {
    try {
      await _service.start();
      
      // Connection kurulduktan sonra state'i güncelle
      await Future.delayed(const Duration(milliseconds: 500));
      
      final connection = _service.connection;
      if (connection != null) {
        final currentState = connection.state;
        final isConnected = currentState == HubConnectionState.connected;
        
        state = state.copyWith(
          connectionState: currentState,
          isConnected: isConnected,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isConnected: false,
      );
    }
  }

  /// Stop connection
  Future<void> stop() async {
    try {
      await _service.stop();
      state = state.copyWith(
        connectionState: HubConnectionState.disconnected,
        isConnected: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
  }

  /// Invoke hub method
  Future<dynamic> invoke(String methodName, {List<Object?>? args}) async {
    try {
      var connection = _service.connection;
      
      // Connection yoksa veya bağlı değilse başlat
      if (connection == null || !_service.isConnected) {
        await start();
        // start() sonrası connection'ı tekrar al
        connection = _service.connection;
        
        // Tekrar kontrol et
        if (connection == null || !_service.isConnected) {
          throw Exception('SignalR connection failed to start');
        }
      }
      
      final result = await connection.invoke(methodName, args: args);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Listen to hub event
  void on(String methodName, Function(List<Object?>?) callback) {
    final connection = _service.connection;
    if (connection != null) {
      connection.on(methodName, callback);
    }
  }

  /// Remove event listener
  void off(String methodName) {
    _service.connection?.off(methodName);
  }
}

/// ChatHub provider
final chatHubProvider = StateNotifierProvider<ChatHubNotifier, ChatHubState>((ref) {
  final service = ref.watch(chatHubServiceProvider);
  return ChatHubNotifier(service);
});

