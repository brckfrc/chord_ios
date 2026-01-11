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

  ChatHubNotifier(this._service) : super(ChatHubState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    print('🔄 [ChatHubNotifier] Starting initialization...');
    try {
      final connection = await _service.getConnection();
      print('✅ [ChatHubNotifier] Connection obtained: ${connection.state}');

      // Listen to connection state changes
      connection.onclose((error) {
        state = state.copyWith(
          connectionState: HubConnectionState.disconnected,
          isConnected: false,
          error: error?.toString(),
        );
        print('📊 [ChatHubNotifier] State updated: isConnected=false, state=disconnected');
      });

      connection.onreconnecting((error) {
        state = state.copyWith(
          connectionState: HubConnectionState.reconnecting,
          isConnected: false,
          error: error?.toString(),
        );
        print('📊 [ChatHubNotifier] State updated: isConnected=false, state=reconnecting');
      });

      connection.onreconnected((connectionId) {
        state = state.copyWith(
          connectionState: HubConnectionState.connected,
          isConnected: true,
          error: null,
        );
        print('📊 [ChatHubNotifier] State updated: isConnected=true, state=connected (reconnected)');
      });

      print('🔄 [ChatHubNotifier] Starting SignalR connection...');
      await _service.start();
      print('✅ [ChatHubNotifier] SignalR start() completed');

      // Wait for connection to actually become connected
      // connection.start() returns immediately, but connection might not be ready yet
      final updatedConnection = await _service.getConnection();
      int attempts = 0;
      const maxAttempts = 10; // Max 1 second wait (10 * 100ms)
      
      while (attempts < maxAttempts && updatedConnection.state != HubConnectionState.connected) {
        await Future.delayed(const Duration(milliseconds: 100));
        final currentState = updatedConnection.state;
        if (currentState == HubConnectionState.connected) {
          break;
        }
        attempts++;
      }

      final currentState = updatedConnection.state;
      final isConnected = currentState == HubConnectionState.connected;

      state = state.copyWith(
        connectionState: currentState,
        isConnected: isConnected,
        error: null,
      );
      print('📊 [ChatHubNotifier] State updated: isConnected=$isConnected, state=$currentState');
      print('✅ [ChatHubNotifier] Initialization complete');
    } catch (e) {
      print('❌ [ChatHubNotifier] Initialization failed: $e');
      state = state.copyWith(error: e.toString(), isConnected: false);
    }
  }

  /// Start connection
  Future<void> start() async {
    try {
      final connection = await _service.getConnection();
      
      if (connection.state == HubConnectionState.connected) {
        state = state.copyWith(
          connectionState: HubConnectionState.connected,
          isConnected: true,
          error: null,
        );
        print('📊 [ChatHubNotifier] State updated: isConnected=true, state=connected (already connected)');
        return;
      }

      await _service.start();
      
      // Wait for connection to actually become connected
      // connection.start() returns immediately, but connection might not be ready yet
      final updatedConnection = await _service.getConnection();
      int attempts = 0;
      const maxAttempts = 10; // Max 1 second wait (10 * 100ms)
      
      while (attempts < maxAttempts && updatedConnection.state != HubConnectionState.connected) {
        await Future.delayed(const Duration(milliseconds: 100));
        final currentState = updatedConnection.state;
        if (currentState == HubConnectionState.connected) {
          break;
        }
        attempts++;
      }
      
      final currentState = updatedConnection.state;
      state = state.copyWith(
        connectionState: currentState,
        isConnected: currentState == HubConnectionState.connected,
        error: null,
      );
      print('📊 [ChatHubNotifier] State updated: isConnected=${currentState == HubConnectionState.connected}, state=$currentState');
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
    print('🔍 [ChatHub] on() called for event: $methodName, connection: ${connection != null ? 'exists (state: ${connection.state})' : 'null'}');
    
    if (connection != null) {
      connection.on(methodName, callback);
      print('✅ [ChatHub] Registered listener for event: $methodName (connection state: ${connection.state})');
    } else {
      print('❌ [ChatHub] Cannot register listener for $methodName: connection is null');
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

  // ========== Channel Methods ==========

  /// Join a text channel
  Future<void> joinChannel(String channelId) async {
    await invoke('JoinChannel', args: [channelId]);
  }

  /// Leave a text channel
  Future<void> leaveChannel(String channelId) async {
    await invoke('LeaveChannel', args: [channelId]);
  }
}

/// ChatHub provider
final chatHubProvider = StateNotifierProvider<ChatHubNotifier, ChatHubState>((
  ref,
) {
  final service = ref.watch(chatHubServiceProvider);
  return ChatHubNotifier(service);
});
