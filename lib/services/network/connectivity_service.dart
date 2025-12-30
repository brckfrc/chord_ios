import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network connectivity state
enum NetworkStatus { connected, disconnected }

/// Connectivity service for monitoring network status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Check current connectivity status
  Future<NetworkStatus> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return _getNetworkStatus(result);
  }

  /// Get network status from connectivity result
  NetworkStatus _getNetworkStatus(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      return NetworkStatus.disconnected;
    }
    return NetworkStatus.connected;
  }

  /// Stream of connectivity changes
  Stream<NetworkStatus> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_getNetworkStatus);
  }
  
  /// Check if device is connected to internet
  Future<bool> isConnected() async {
    final status = await checkConnectivity();
    return status == NetworkStatus.connected;
  }
  
  /// Get raw connectivity result stream
  Stream<List<ConnectivityResult>> get networkStream {
    return _connectivity.onConnectivityChanged;
  }
  
  /// Get connection type as string
  Future<String> getConnectionType() async {
    final result = await _connectivity.checkConnectivity();
    
    if (result.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (result.contains(ConnectivityResult.mobile)) {
      return 'Cellular';
    } else if (result.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    } else {
      return 'None';
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }
}

/// Connectivity service provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Network status provider
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Current network status provider (synchronous)
final currentNetworkStatusProvider = FutureProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.checkConnectivity();
});
