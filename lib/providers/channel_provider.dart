import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guild/channel_dto.dart';
import '../models/guild/create_channel_dto.dart';
import '../repositories/channel_repository.dart';

/// Channel state
class ChannelState {
  final Map<String, List<ChannelDto>> channelsByGuild;
  final String? selectedChannelId;
  final bool isLoading;
  final String? error;

  ChannelState({
    this.channelsByGuild = const {},
    this.selectedChannelId,
    this.isLoading = false,
    this.error,
  });

  List<ChannelDto> getChannelsForGuild(String guildId) {
    return channelsByGuild[guildId] ?? [];
  }

  ChannelState copyWith({
    Map<String, List<ChannelDto>>? channelsByGuild,
    String? selectedChannelId,
    bool? isLoading,
    String? error,
  }) {
    return ChannelState(
      channelsByGuild: channelsByGuild ?? this.channelsByGuild,
      selectedChannelId: selectedChannelId ?? this.selectedChannelId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Channel provider
class ChannelNotifier extends StateNotifier<ChannelState> {
  final ChannelRepository _repository;

  ChannelNotifier(this._repository) : super(ChannelState());

  /// Fetch channels for a guild
  Future<void> fetchChannels(String guildId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final channels = await _repository.fetchChannels(guildId);
      final updatedMap = Map<String, List<ChannelDto>>.from(state.channelsByGuild);
      updatedMap[guildId] = channels;
      state = state.copyWith(
        channelsByGuild: updatedMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set selected channel
  void setSelectedChannel(String? channelId) {
    state = state.copyWith(selectedChannelId: channelId);
  }

  /// Clear channels for a guild
  void clearChannels(String? guildId) {
    if (guildId == null) {
      state = state.copyWith(channelsByGuild: {}, selectedChannelId: null);
    } else {
      final updatedMap = Map<String, List<ChannelDto>>.from(state.channelsByGuild);
      updatedMap.remove(guildId);
      state = state.copyWith(channelsByGuild: updatedMap, selectedChannelId: null);
    }
  }

  /// Create a new channel
  Future<ChannelDto?> createChannel(String guildId, CreateChannelDto dto) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final channel = await _repository.createChannel(guildId, dto);
      final updatedMap = Map<String, List<ChannelDto>>.from(state.channelsByGuild);
      final channels = updatedMap[guildId] ?? [];
      updatedMap[guildId] = [...channels, channel];
      state = state.copyWith(
        channelsByGuild: updatedMap,
        isLoading: false,
      );
      return channel;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

/// Channel repository provider
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository();
});

/// Channel state provider
final channelProvider = StateNotifierProvider<ChannelNotifier, ChannelState>((ref) {
  final repository = ref.watch(channelRepositoryProvider);
  return ChannelNotifier(repository);
});

