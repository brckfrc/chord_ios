import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guild/guild_dto.dart';
import '../models/guild/create_guild_dto.dart';
import '../repositories/guild_repository.dart';

/// Guild state
class GuildState {
  final List<GuildDto> guilds;
  final String? selectedGuildId;
  final bool isLoading;
  final String? error;

  GuildState({
    this.guilds = const [],
    this.selectedGuildId,
    this.isLoading = false,
    this.error,
  });

  GuildState copyWith({
    List<GuildDto>? guilds,
    String? selectedGuildId,
    bool? isLoading,
    String? error,
  }) {
    return GuildState(
      guilds: guilds ?? this.guilds,
      selectedGuildId: selectedGuildId ?? this.selectedGuildId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Guild provider
class GuildNotifier extends StateNotifier<GuildState> {
  final GuildRepository _repository;

  GuildNotifier(this._repository) : super(GuildState()) {
    fetchGuilds();
  }

  /// Fetch all guilds
  Future<void> fetchGuilds() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final guilds = await _repository.fetchGuilds();
      state = state.copyWith(guilds: guilds, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set selected guild
  void setSelectedGuild(String? guildId) {
    // Directly create new state to allow null values
    // copyWith doesn't handle null properly (uses ?? operator)
    state = GuildState(
      guilds: state.guilds,
      selectedGuildId: guildId, // Can be null
      isLoading: state.isLoading,
      error: state.error,
    );
  }

  /// Create a new guild
  Future<GuildDto?> createGuild(CreateGuildDto dto) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final guild = await _repository.createGuild(dto);
      state = state.copyWith(
        guilds: [...state.guilds, guild],
        isLoading: false,
      );
      return guild;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

/// Guild repository provider
final guildRepositoryProvider = Provider<GuildRepository>((ref) {
  return GuildRepository();
});

/// Guild state provider
final guildProvider = StateNotifierProvider<GuildNotifier, GuildState>((ref) {
  final repository = ref.watch(guildRepositoryProvider);
  return GuildNotifier(repository);
});

