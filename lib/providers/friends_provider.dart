import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friends/friendship_dto.dart';
import '../repositories/friends_repository.dart';
import 'signalr/chat_hub_provider.dart';

/// Friends state
class FriendsState {
  final List<FriendshipDto> friends;
  final List<FriendshipDto> pendingRequests;
  final List<FriendshipDto> blockedUsers;
  final bool isLoading;
  final String? error;

  FriendsState({
    this.friends = const [],
    this.pendingRequests = const [],
    this.blockedUsers = const [],
    this.isLoading = false,
    this.error,
  });

  FriendsState copyWith({
    List<FriendshipDto>? friends,
    List<FriendshipDto>? pendingRequests,
    List<FriendshipDto>? blockedUsers,
    bool? isLoading,
    String? error,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get pending requests count
  int get pendingCount => pendingRequests.length;
}

/// Friends provider
class FriendsNotifier extends StateNotifier<FriendsState> {
  final FriendsRepository _repository;
  final Ref _ref;

  FriendsNotifier(this._repository, this._ref) : super(FriendsState()) {
    _setupSignalRListeners();
  }

  /// Setup SignalR event listeners for friends
  void _setupSignalRListeners() {
    // Note: Backend may not have these events yet, but we'll set them up for future use
    try {
      final chatHub = _ref.read(chatHubProvider.notifier);
      final chatHubState = _ref.read(chatHubProvider);
      
      if (chatHubState.isConnected) {
        _registerSignalRListeners(chatHub);
      }
      
      // Watch for connection state changes and setup listeners when connected
      _ref.listen<ChatHubState>(chatHubProvider, (previous, next) {
        if (next.isConnected && (previous == null || !previous.isConnected)) {
          _registerSignalRListeners(chatHub);
        }
      });
    } catch (e) {
      // SignalR not available or not connected yet - will retry when connected
    }
  }

  /// Register SignalR event listeners
  void _registerSignalRListeners(chatHub) {
    // FriendRequestReceived - New friend request received
    chatHub.on('FriendRequestReceived', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final data = args[0] as Map<String, dynamic>;
          final friendship = FriendshipDto.fromJson(data);
          onFriendRequestReceived(friendship);
        } catch (e) {
          // Handle error
        }
      }
    });

    // FriendRequestAccepted - Friend request was accepted
    chatHub.on('FriendRequestAccepted', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final data = args[0] as Map<String, dynamic>;
          final friendship = FriendshipDto.fromJson(data);
          onFriendRequestAccepted(friendship);
        } catch (e) {
          // Handle error
        }
      }
    });

    // FriendRequestDeclined - Friend request was declined
    chatHub.on('FriendRequestDeclined', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final friendshipId = args[0]?.toString() ?? '';
          if (friendshipId.isNotEmpty) {
            onFriendRequestDeclined(friendshipId);
          }
        } catch (e) {
          // Handle error
        }
      }
    });

    // FriendRemoved - Friend was removed
    chatHub.on('FriendRemoved', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final friendshipId = args[0]?.toString() ?? '';
          if (friendshipId.isNotEmpty) {
            onFriendRemoved(friendshipId);
          }
        } catch (e) {
          // Handle error
        }
      }
    });

    // UserBlocked - User was blocked
    chatHub.on('UserBlocked', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final data = args[0] as Map<String, dynamic>;
          final friendship = FriendshipDto.fromJson(data);
          onUserBlocked(friendship);
        } catch (e) {
          // Handle error
        }
      }
    });

    // UserUnblocked - User was unblocked
    chatHub.on('UserUnblocked', (args) {
      if (args != null && args.isNotEmpty) {
        try {
          final userId = args[0]?.toString() ?? '';
          if (userId.isNotEmpty) {
            onUserUnblocked(userId);
          }
        } catch (e) {
          // Handle error
        }
      }
    });
  }

  /// Fetch all friends
  Future<void> fetchFriends() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final friends = await _repository.getFriends();
      state = state.copyWith(friends: friends, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Fetch pending requests
  Future<void> fetchPendingRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pending = await _repository.getPendingRequests();
      state = state.copyWith(pendingRequests: pending, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Fetch blocked users
  Future<void> fetchBlockedUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final blocked = await _repository.getBlockedUsers();
      state = state.copyWith(blockedUsers: blocked, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Fetch all (friends, pending, blocked)
  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final friends = await _repository.getFriends();
      final pending = await _repository.getPendingRequests();
      final blocked = await _repository.getBlockedUsers();
      
      state = state.copyWith(
        friends: friends,
        pendingRequests: pending,
        blockedUsers: blocked,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Send friend request
  /// Accepts username - backend will convert it to userId
  Future<bool> sendFriendRequest(String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final friendship = await _repository.sendFriendRequest(username);
      
      // Add to pending requests if not already there
      final updatedPending = List<FriendshipDto>.from(state.pendingRequests);
      if (!updatedPending.any((f) => f.id == friendship.id)) {
        updatedPending.add(friendship);
      }
      
      state = state.copyWith(
        pendingRequests: updatedPending,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptRequest(String friendshipId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.acceptRequest(friendshipId);
      
      // Move from pending to friends
      final pending = List<FriendshipDto>.from(state.pendingRequests);
      final friendship = pending.firstWhere(
        (f) => f.id == friendshipId,
        orElse: () => throw Exception('Friendship not found in pending'),
      );
      
      pending.removeWhere((f) => f.id == friendshipId);
      final updatedFriendship = friendship.copyWith(
        status: FriendshipStatus.accepted,
        acceptedAt: DateTime.now(),
      );
      
      final friends = List<FriendshipDto>.from(state.friends);
      friends.add(updatedFriendship);
      
      state = state.copyWith(
        friends: friends,
        pendingRequests: pending,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Decline friend request
  Future<bool> declineRequest(String friendshipId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.declineRequest(friendshipId);
      
      // Remove from pending
      final pending = List<FriendshipDto>.from(state.pendingRequests);
      pending.removeWhere((f) => f.id == friendshipId);
      
      state = state.copyWith(
        pendingRequests: pending,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Unfriend
  Future<bool> unfriend(String friendshipId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.unfriend(friendshipId);
      
      // Remove from friends
      final friends = List<FriendshipDto>.from(state.friends);
      friends.removeWhere((f) => f.id == friendshipId);
      
      state = state.copyWith(
        friends: friends,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Block user
  Future<bool> blockUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.blockUser(userId);
      
      // Remove from friends if exists
      final friends = List<FriendshipDto>.from(state.friends);
      friends.removeWhere((f) => 
        f.requesterId == userId || f.addresseeId == userId
      );
      
      // Remove from pending if exists
      final pending = List<FriendshipDto>.from(state.pendingRequests);
      pending.removeWhere((f) => 
        f.requesterId == userId || f.addresseeId == userId
      );
      
      // Fetch blocked users to update list
      final blocked = await _repository.getBlockedUsers();
      
      state = state.copyWith(
        friends: friends,
        pendingRequests: pending,
        blockedUsers: blocked,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Unblock user
  Future<bool> unblockUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.unblockUser(userId);
      
      // Remove from blocked
      final blocked = List<FriendshipDto>.from(state.blockedUsers);
      blocked.removeWhere((f) => 
        f.requesterId == userId || f.addresseeId == userId
      );
      
      state = state.copyWith(
        blockedUsers: blocked,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Handle friend request received (from SignalR)
  void onFriendRequestReceived(FriendshipDto friendship) {
    final pending = List<FriendshipDto>.from(state.pendingRequests);
    if (!pending.any((f) => f.id == friendship.id)) {
      pending.add(friendship);
      state = state.copyWith(pendingRequests: pending);
    }
  }

  /// Handle friend request accepted (from SignalR)
  void onFriendRequestAccepted(FriendshipDto friendship) {
    // Remove from pending
    final pending = List<FriendshipDto>.from(state.pendingRequests);
    pending.removeWhere((f) => f.id == friendship.id);
    
    // Add to friends
    final friends = List<FriendshipDto>.from(state.friends);
    if (!friends.any((f) => f.id == friendship.id)) {
      friends.add(friendship);
    }
    
    state = state.copyWith(
      friends: friends,
      pendingRequests: pending,
    );
  }

  /// Handle friend request declined (from SignalR)
  void onFriendRequestDeclined(String friendshipId) {
    final pending = List<FriendshipDto>.from(state.pendingRequests);
    pending.removeWhere((f) => f.id == friendshipId);
    state = state.copyWith(pendingRequests: pending);
  }

  /// Handle friend removed (from SignalR)
  void onFriendRemoved(String friendshipId) {
    final friends = List<FriendshipDto>.from(state.friends);
    friends.removeWhere((f) => f.id == friendshipId);
    state = state.copyWith(friends: friends);
  }

  /// Handle user blocked (from SignalR)
  void onUserBlocked(FriendshipDto friendship) {
    // Remove from friends and pending
    final friends = List<FriendshipDto>.from(state.friends);
    friends.removeWhere((f) => 
      f.requesterId == friendship.requesterId || 
      f.addresseeId == friendship.addresseeId
    );
    
    final pending = List<FriendshipDto>.from(state.pendingRequests);
    pending.removeWhere((f) => 
      f.requesterId == friendship.requesterId || 
      f.addresseeId == friendship.addresseeId
    );
    
    // Add to blocked
    final blocked = List<FriendshipDto>.from(state.blockedUsers);
    if (!blocked.any((f) => f.id == friendship.id)) {
      blocked.add(friendship);
    }
    
    state = state.copyWith(
      friends: friends,
      pendingRequests: pending,
      blockedUsers: blocked,
    );
  }

  /// Handle user unblocked (from SignalR)
  void onUserUnblocked(String userId) {
    final blocked = List<FriendshipDto>.from(state.blockedUsers);
    blocked.removeWhere((f) => 
      f.requesterId == userId || f.addresseeId == userId
    );
    state = state.copyWith(blockedUsers: blocked);
  }
}

/// Friends repository provider
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository();
});

/// Friends state provider
final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  final repository = ref.watch(friendsRepositoryProvider);
  return FriendsNotifier(repository, ref);
});
