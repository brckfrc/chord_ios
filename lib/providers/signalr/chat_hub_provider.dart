import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/signalr/signalr_service.dart';
import 'package:signalr_core/signalr_core.dart';

/// ChatHub connection state
class ChatHubState {
  final HubConnectionState? connectionState;
  final bool isConnected;
  final String? error;

  ChatHubState({this.connectionState, this.isConnected = false, this.error});

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
  final Ref _ref;

  ChatHubNotifier(this._service, this._ref) : super(ChatHubState()) {
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

      // Update state after connection is established
      // Wait a bit and check again since start() is async
      await Future.delayed(const Duration(milliseconds: 500));

      final currentState = connection.state;
      final isConnected = currentState == HubConnectionState.connected;

      state = state.copyWith(
        connectionState: currentState,
        isConnected: isConnected,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnected: false);
    }
  }

  /// Start connection
  Future<void> start() async {
    try {
      final connection = await _service.getConnection();
      
      // If already connected, just update state and return
      if (connection.state == HubConnectionState.connected) {
        state = state.copyWith(
          connectionState: HubConnectionState.connected,
          isConnected: true,
          error: null,
        );
        return;
      }

      // Start connection - SignalRService.start() already handles state checking
      await _service.start();
      
      // Update state based on current connection state
      // State will be updated via event listeners if connection succeeds
      final currentState = connection.state;
      state = state.copyWith(
        connectionState: currentState,
        isConnected: currentState == HubConnectionState.connected,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isConnected: false,
      );
      rethrow;
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
      state = state.copyWith(error: e.toString());
    }
  }

  /// Invoke hub method
  Future<dynamic> invoke(String methodName, {List<Object?>? args}) async {
    try {
      var connection = await _service.getConnection();

      // Only start if not connected
      if (connection.state != HubConnectionState.connected) {
        await start();
        // Re-fetch connection after start to ensure latest state
        connection = await _service.getConnection();

        // Final verification
        if (connection.state != HubConnectionState.connected) {
          throw Exception(
            'SignalR connection failed: Connection is not in connected state',
          );
        }
      }

      return await connection.invoke(methodName, args: args);
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

  // ========== DM Methods ==========

  /// Join a DM channel
  Future<void> joinDM(String dmId) async {
    await invoke('JoinDM', args: [dmId]);
  }

  /// Leave a DM channel
  Future<void> leaveDM(String dmId) async {
    await invoke('LeaveDM', args: [dmId]);
  }

  /// Send a DM message
  Future<void> sendDMMessage(String dmId, String content) async {
    await invoke(
      'SendDMMessage',
      args: [
        dmId,
        {'content': content},
      ],
    );
  }

  /// Trigger typing indicator in DM
  Future<void> typingInDM(String dmId) async {
    await invoke('TypingInDM', args: [dmId]);
  }

  /// Stop typing indicator in DM
  Future<void> stopTypingInDM(String dmId) async {
    await invoke('StopTypingInDM', args: [dmId]);
  }

  /// Mark DM as read
  Future<void> markDMAsRead(String dmId, {String? lastReadMessageId}) async {
    if (lastReadMessageId != null) {
      await invoke('MarkDMAsRead', args: [dmId, lastReadMessageId]);
    } else {
      await invoke('MarkDMAsRead', args: [dmId]);
    }
  }
}

/// ChatHub provider
final chatHubProvider = StateNotifierProvider<ChatHubNotifier, ChatHubState>((
  ref,
) {
  final service = ref.watch(chatHubServiceProvider);
  return ChatHubNotifier(service, ref);
});
