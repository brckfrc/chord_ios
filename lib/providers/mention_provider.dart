import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mention/message_mention_dto.dart';
import '../repositories/mention_repository.dart';

/// Mention state
class MentionState {
  final List<MessageMentionDto> mentions;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  MentionState({
    this.mentions = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  List<MessageMentionDto> get unreadMentions {
    return mentions.where((m) => !m.isRead).toList();
  }

  List<MessageMentionDto> get readMentions {
    return mentions.where((m) => m.isRead).toList();
  }

  MentionState copyWith({
    List<MessageMentionDto>? mentions,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return MentionState(
      mentions: mentions ?? this.mentions,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Mention repository provider
final mentionRepositoryProvider = Provider<MentionRepository>((ref) {
  return MentionRepository();
});

/// Mention state provider
class MentionNotifier extends StateNotifier<MentionState> {
  final MentionRepository _repository;

  MentionNotifier(this._repository) : super(MentionState());

  /// Fetch mentions for the current user
  Future<void> fetchMentions({bool unreadOnly = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final mentions = await _repository.getUserMentions(
        unreadOnly: unreadOnly,
      );

      // Update unread count
      final unreadCount = mentions.where((m) => !m.isRead).length;

      state = state.copyWith(
        mentions: mentions,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Fetch unread mention count
  Future<void> fetchUnreadMentionCount() async {
    try {
      final count = await _repository.getUnreadMentionCount();
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      // Silently fail, don't update error state
    }
  }

  /// Mark a mention as read
  Future<void> markMentionAsRead(String mentionId) async {
    try {
      await _repository.markMentionAsRead(mentionId);

      // Update local state
      final updatedMentions = state.mentions.map((mention) {
        if (mention.id == mentionId) {
          return mention.copyWith(isRead: true);
        }
        return mention;
      }).toList();

      // Update unread count
      final unreadCount = updatedMentions.where((m) => !m.isRead).length;

      state = state.copyWith(
        mentions: updatedMentions,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Add a mention (called when SignalR UserMentioned event is received)
  void addMention(MessageMentionDto mention) {
    // Check if mention already exists
    final exists = state.mentions.any((m) => m.id == mention.id);
    if (exists) {
      return;
    }

    // Add to beginning of list
    final updatedMentions = [mention, ...state.mentions];

    // Update unread count
    final unreadCount = updatedMentions.where((m) => !m.isRead).length;

    state = state.copyWith(
      mentions: updatedMentions,
      unreadCount: unreadCount,
    );
  }

  /// Update a mention
  void updateMention(String mentionId, MessageMentionDto updatedMention) {
    final updatedMentions = state.mentions.map((mention) {
      if (mention.id == mentionId) {
        return updatedMention;
      }
      return mention;
    }).toList();

    // Update unread count
    final unreadCount = updatedMentions.where((m) => !m.isRead).length;

    state = state.copyWith(
      mentions: updatedMentions,
      unreadCount: unreadCount,
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Mention provider
final mentionProvider =
    StateNotifierProvider<MentionNotifier, MentionState>((ref) {
  final repository = ref.watch(mentionRepositoryProvider);
  return MentionNotifier(repository);
});











