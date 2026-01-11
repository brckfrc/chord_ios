import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dm/dm_dto.dart';
import '../repositories/dm_repository.dart';

/// DM state
class DMState {
  final List<DMDto> dms;
  final String? selectedDMId;
  final bool isLoading;
  final String? error;

  DMState({
    this.dms = const [],
    this.selectedDMId,
    this.isLoading = false,
    this.error,
  });

  DMState copyWith({
    List<DMDto>? dms,
    String? selectedDMId,
    bool? isLoading,
    String? error,
  }) {
    return DMState(
      dms: dms ?? this.dms,
      selectedDMId: selectedDMId ?? this.selectedDMId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// DM provider
class DMNotifier extends StateNotifier<DMState> {
  final DMRepository _repository;

  DMNotifier(this._repository) : super(DMState());

  /// Fetch all DMs
  Future<void> fetchDMs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dms = await _repository.fetchDMs();
      // Sort by last message time (most recent first)
      dms.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      state = state.copyWith(dms: dms, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set selected DM
  void setSelectedDM(String? dmId) {
    state = state.copyWith(selectedDMId: dmId);
  }

  /// Create a new DM
  Future<DMDto?> createDM(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dm = await _repository.createDM(userId);
      // Check if DM already exists
      final existingIndex = state.dms.indexWhere(
        (d) => d.otherUserId == dm.otherUserId,
      );
      if (existingIndex >= 0) {
        final updatedDms = List<DMDto>.from(state.dms);
        updatedDms[existingIndex] = dm;
        state = state.copyWith(dms: updatedDms, isLoading: false);
      } else {
        state = state.copyWith(
          dms: [dm, ...state.dms],
          isLoading: false,
        );
      }
      return dm;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Mark DM as read
  Future<void> markDMAsRead(String dmId) async {
    try {
      await _repository.markDMAsRead(dmId);
      
      // Update unreadCount in state
      final updatedDms = List<DMDto>.from(state.dms);
      final dmIndex = updatedDms.indexWhere((dm) => dm.id == dmId);
      if (dmIndex >= 0) {
        final updatedDM = DMDto(
          id: updatedDms[dmIndex].id,
          userId: updatedDms[dmIndex].userId,
          otherUserId: updatedDms[dmIndex].otherUserId,
          otherUser: updatedDms[dmIndex].otherUser,
          lastMessage: updatedDms[dmIndex].lastMessage,
          unreadCount: 0, // Reset unread count
          createdAt: updatedDms[dmIndex].createdAt,
        );
        updatedDms[dmIndex] = updatedDM;
        state = state.copyWith(dms: updatedDms);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update DM unread count (called from SignalR event)
  void updateDMUnreadCount(String dmId, int unreadCount) {
    final updatedDms = List<DMDto>.from(state.dms);
    final dmIndex = updatedDms.indexWhere((dm) => dm.id == dmId);
    if (dmIndex >= 0) {
      final updatedDM = DMDto(
        id: updatedDms[dmIndex].id,
        userId: updatedDms[dmIndex].userId,
        otherUserId: updatedDms[dmIndex].otherUserId,
        otherUser: updatedDms[dmIndex].otherUser,
        lastMessage: updatedDms[dmIndex].lastMessage,
        unreadCount: unreadCount,
        createdAt: updatedDms[dmIndex].createdAt,
      );
      updatedDms[dmIndex] = updatedDM;
      state = state.copyWith(dms: updatedDms);
    }
  }

  /// Increment DM unread count (called when new message arrives)
  void incrementDMUnreadCount(String dmId) {
    final updatedDms = List<DMDto>.from(state.dms);
    final dmIndex = updatedDms.indexWhere((dm) => dm.id == dmId);
    if (dmIndex >= 0) {
      final currentUnreadCount = updatedDms[dmIndex].unreadCount;
      final updatedDM = DMDto(
        id: updatedDms[dmIndex].id,
        userId: updatedDms[dmIndex].userId,
        otherUserId: updatedDms[dmIndex].otherUserId,
        otherUser: updatedDms[dmIndex].otherUser,
        lastMessage: updatedDms[dmIndex].lastMessage,
        unreadCount: currentUnreadCount + 1,
        createdAt: updatedDms[dmIndex].createdAt,
      );
      updatedDms[dmIndex] = updatedDM;
      state = state.copyWith(dms: updatedDms);
    }
  }
}

/// DM repository provider
final dmRepositoryProvider = Provider<DMRepository>((ref) {
  return DMRepository();
});

/// DM state provider
final dmProvider = StateNotifierProvider<DMNotifier, DMState>((ref) {
  final repository = ref.watch(dmRepositoryProvider);
  return DMNotifier(repository);
});

