import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/signalr/signalr_service.dart';
import 'package:signalr_core/signalr_core.dart';

/// PresenceHub connection state
class PresenceHubState {
  final HubConnectionState? connectionState;
  final bool isConnected;
  final String? error;

  PresenceHubState({
    this.connectionState,
    this.isConnected = false,
    this.error,
  });

  PresenceHubState copyWith({
    HubConnectionState? connectionState,
    bool? isConnected,
    String? error,
  }) {
    return PresenceHubState(
      connectionState: connectionState ?? this.connectionState,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

/// PresenceHub service provider
final presenceHubServiceProvider = Provider<SignalRService>((ref) {
  return SignalRService(hubName: 'presence');
});

/// PresenceHub state provider
class PresenceHubNotifier extends StateNotifier<PresenceHubState> {
  final SignalRService _service;

  PresenceHubNotifier(this._service) : super(PresenceHubState()) {
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
      
      state = state.copyWith(
        connectionState: connection.state,
        isConnected: connection.state == HubConnectionState.connected,
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
      final connection = _service.connection;
      if (connection != null) {
        state = state.copyWith(
          connectionState: connection.state,
          isConnected: connection.state == HubConnectionState.connected,
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
      final connection = _service.connection;
      if (connection == null || !_service.isConnected) {
        await start();
      }
      
      final result = await connection?.invoke(methodName, args: args);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Listen to hub event
  void on(String methodName, Function(List<Object?>?) callback) {
    _service.connection?.on(methodName, callback);
  }

  /// Remove event listener
  void off(String methodName) {
    _service.connection?.off(methodName);
  }
}

/// PresenceHub provider
final presenceHubProvider = StateNotifierProvider<PresenceHubNotifier, PresenceHubState>((ref) {
  final service = ref.watch(presenceHubServiceProvider);
  return PresenceHubNotifier(service);
});

