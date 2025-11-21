import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth/user_status.dart';
import 'signalr/presence_hub_provider.dart';
import '../services/signalr/signalr_service.dart';

/// Presence state (user statuses)
class PresenceState {
  final Map<String, UserStatus> userStatuses; // userId -> UserStatus

  PresenceState({
    this.userStatuses = const {},
  });

  /// Get status for a user (defaults to offline if not found)
  UserStatus getStatus(String userId) {
    return userStatuses[userId] ?? UserStatus.offline;
  }

  PresenceState copyWith({
    Map<String, UserStatus>? userStatuses,
  }) {
    return PresenceState(
      userStatuses: userStatuses ?? this.userStatuses,
    );
  }
}

/// Presence provider
class PresenceNotifier extends StateNotifier<PresenceState> {
  final PresenceHubNotifier _presenceHub;
  final SignalRService _service;
  bool _listenersRegistered = false;

  PresenceNotifier(this._presenceHub, this._service) : super(PresenceState()) {
    // Try to register listeners immediately
    _registerListeners();
    
    // If connection is not ready, try again after a delay
    if (!_listenersRegistered) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _registerListeners();
      });
    }
  }

  /// Register PresenceHub event listeners
  void _registerListeners() {
    if (_listenersRegistered) {
      return;
    }

    final connection = _service.connection;

    if (connection == null) {
      return;
    }

    _listenersRegistered = true;

    // Listen to UserOnline event
    _presenceHub.on('UserOnline', (args) {
      if (args != null && args.length >= 1) {
        try {
          final userId = args[0]?.toString() ?? '';
          // Backend only sends userId, status is always Online when user comes online
          final status = UserStatus.online;

          final updatedStatuses = Map<String, UserStatus>.from(state.userStatuses);
          updatedStatuses[userId] = status;

          state = state.copyWith(userStatuses: updatedStatuses);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to UserOffline event
    _presenceHub.on('UserOffline', (args) {
      if (args != null && args.length >= 1) {
        try {
          final userId = args[0]?.toString() ?? '';

          final updatedStatuses = Map<String, UserStatus>.from(state.userStatuses);
          updatedStatuses[userId] = UserStatus.offline;

          state = state.copyWith(userStatuses: updatedStatuses);
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Listen to UserStatusChanged event
    _presenceHub.on('UserStatusChanged', (args) {
      if (args != null && args.length >= 1) {
        try {
          // Backend sends an object: { userId: string, status: int, customStatus?: string }
          if (args[0] is Map) {
            final data = args[0] as Map<String, dynamic>;
            final userId = data['userId']?.toString() ?? '';
            final statusInt = data['status'];
            
            // Status is sent as int (0=Online, 1=Idle, 2=DoNotDisturb, 3=Invisible, 4=Offline)
            final status = UserStatus.fromDynamic(statusInt);

            final updatedStatuses = Map<String, UserStatus>.from(state.userStatuses);
            updatedStatuses[userId] = status;

            state = state.copyWith(userStatuses: updatedStatuses);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });
  }

  /// Update user status (called when status changes)
  void updateUserStatus(String userId, UserStatus status) {
    final updatedStatuses = Map<String, UserStatus>.from(state.userStatuses);
    updatedStatuses[userId] = status;
    state = state.copyWith(userStatuses: updatedStatuses);
  }

  /// Get status for a user
  UserStatus getStatus(String userId) {
    return state.getStatus(userId);
  }
}

/// Presence provider
final presenceProvider = StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  final presenceHub = ref.watch(presenceHubProvider.notifier);
  final service = ref.watch(presenceHubServiceProvider);
  return PresenceNotifier(presenceHub, service);
});

