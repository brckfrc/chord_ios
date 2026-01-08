import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/voice/voice_participant_dto.dart';
import '../services/voice/voice_service.dart';
import '../services/network/connectivity_service.dart';
import '../services/logging/log_service.dart';
import 'signalr/chat_hub_provider.dart';
import 'auth_provider.dart';
import 'channel_provider.dart';
import 'guild_provider.dart';
import '../models/guild/channel_type.dart';

/// Voice channel state
class VoiceState {
  final String? activeChannelId;
  final String? activeChannelName;
  final bool isConnected;
  final bool isConnecting;
  final bool isMuted;
  final bool isDeafened;
  final bool isSpeaking;
  final List<VoiceParticipantDto> participants; // Keep for backward compatibility
  final Map<String, List<VoiceParticipantDto>> participantsByChannel; // Multi-channel participants
  final String? error;

  VoiceState({
    this.activeChannelId,
    this.activeChannelName,
    this.isConnected = false,
    this.isConnecting = false,
    this.isMuted = false,
    this.isDeafened = false,
    this.isSpeaking = false,
    this.participants = const [],
    this.participantsByChannel = const {},
    this.error,
  });

  VoiceState copyWith({
    String? activeChannelId,
    String? activeChannelName,
    bool? isConnected,
    bool? isConnecting,
    bool? isMuted,
    bool? isDeafened,
    bool? isSpeaking,
    List<VoiceParticipantDto>? participants,
    Map<String, List<VoiceParticipantDto>>? participantsByChannel,
    String? error,
  }) {
    return VoiceState(
      activeChannelId: activeChannelId ?? this.activeChannelId,
      activeChannelName: activeChannelName ?? this.activeChannelName,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      participants: participants ?? this.participants,
      participantsByChannel: participantsByChannel ?? this.participantsByChannel,
      error: error,
    );
  }

  /// Get participants for a specific channel
  /// Returns a new list copy to ensure Riverpod detects changes
  List<VoiceParticipantDto> getParticipantsForChannel(String channelId) {
    final list = participantsByChannel[channelId];
    return list != null ? List<VoiceParticipantDto>.from(list) : [];
  }
}

/// Voice service provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Voice notifier
class VoiceNotifier extends StateNotifier<VoiceState> {
  final VoiceService _voiceService;
  final ConnectivityService _networkService;
  final Ref _ref;
  final LogService _logger = LogService('VoiceNotifier');

  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  StreamSubscription? _participantConnectedSub;
  StreamSubscription? _participantDisconnectedSub;
  StreamSubscription? _speakingChangedSub;
  bool _signalRListenersSetup = false;

  VoiceNotifier(this._voiceService, this._networkService, this._ref)
      : super(VoiceState()) {
    _setupNetworkListener();
    _setupVoiceEventListeners();
    // SignalR listeners will be setup when connection is ready
    _setupSignalRVoiceListenersWhenReady();
    // Watch channel list changes and fetch participants for voice channels
    _setupChannelListWatcher();
  }
  
  /// Setup SignalR voice event listeners when connection is ready
  void _setupSignalRVoiceListenersWhenReady() {
    // Watch ChatHub connection state and setup listeners when ready
    _ref.listen<ChatHubState>(chatHubProvider, (previous, next) {
      if (next.isConnected && !_signalRListenersSetup) {
        _setupSignalRVoiceListeners();
      }
    });
    
    // Also try to setup immediately if already connected
    final chatHubState = _ref.read(chatHubProvider);
    if (chatHubState.isConnected && !_signalRListenersSetup) {
      _setupSignalRVoiceListeners();
    }
  }
  
  /// Setup SignalR voice event listeners
  void _setupSignalRVoiceListeners() {
    if (_signalRListenersSetup) {
      _logger.debug('SignalR voice listeners already setup');
      return;
    }
    
    try {
      final chatHub = _ref.read(chatHubProvider.notifier);
      final chatHubState = _ref.read(chatHubProvider);
      
      if (!chatHubState.isConnected) {
        _logger.warn('Cannot setup SignalR listeners: Connection not ready');
        return;
      }
      
      // User joined voice channel
      chatHub.on('UserJoinedVoiceChannel', (args) {
        _logger.info('UserJoinedVoiceChannel event received - args: $args');
        if (args == null || args.isEmpty) {
          _logger.warn('UserJoinedVoiceChannel event has no args');
          return;
        }
        try {
          final data = args[0] as Map<String, dynamic>;
          _logger.debug('UserJoinedVoiceChannel event data: $data');
          onUserJoinedVoice(data);
        } catch (e) {
          _logger.error('Error handling UserJoinedVoiceChannel: $e');
        }
      });
      
      // User left voice channel
      chatHub.on('UserLeftVoiceChannel', (args) {
        _logger.info('UserLeftVoiceChannel event received - args: $args');
        if (args == null || args.isEmpty) {
          _logger.warn('UserLeftVoiceChannel event has no args');
          return;
        }
        try {
          final data = args[0] as Map<String, dynamic>;
          _logger.debug('UserLeftVoiceChannel event data: $data');
          onUserLeftVoice(data);
        } catch (e) {
          _logger.error('Error handling UserLeftVoiceChannel: $e');
        }
      });
      
      // Voice state changed
      chatHub.on('UserVoiceStateChanged', (args) {
        if (args == null || args.isEmpty) return;
        try {
          final data = args[0] as Map<String, dynamic>;
          _logger.debug('UserVoiceStateChanged event received: $data');
          onVoiceStateChanged(data);
        } catch (e) {
          _logger.error('Error handling UserVoiceStateChanged: $e');
        }
      });
      
      _signalRListenersSetup = true;
      _logger.debug('SignalR voice event listeners setup complete');
    } catch (e) {
      _logger.error('Failed to setup SignalR voice listeners: $e');
    }
  }

  /// Setup channel list watcher to fetch participants when voice channels change
  void _setupChannelListWatcher() {
    // Watch channel provider and fetch participants when voice channels are loaded
    _ref.listen<ChannelState>(channelProvider, (previous, next) {
      // Fetch participants when channels are loaded for a guild
      if (next.fetchedGuilds.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          fetchAllVoiceChannelParticipants();
        });
      }
    });
    
    // Also fetch immediately if channels are already loaded
    final channelState = _ref.read(channelProvider);
    if (channelState.fetchedGuilds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchAllVoiceChannelParticipants();
      });
    }
  }

  /// Join voice channel with retry logic
  Future<void> joinVoiceChannel(String channelId) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _logger.info('Joining voice channel: $channelId (attempt $attempt/$maxRetries)');

        // Check network first
        if (!await _networkService.isConnected()) {
          if (attempt < maxRetries) {
            _logger.warn('No network connection, retrying in ${retryDelay.inSeconds}s...');
            await Future.delayed(retryDelay);
            continue;
          }
          _logger.error('Cannot join voice: No network connection');
          state = state.copyWith(error: 'No network connection');
          return;
        }

        // Set activeChannelId and isConnecting immediately (before LiveKit connection)
        // This makes VoiceBar appear immediately with "Connecting..." status
        String? channelName;
        try {
          // Lookup channel name from all guilds
          final channelState = _ref.read(channelProvider);
          for (final guildChannels in channelState.channelsByGuild.values) {
            try {
              final channel = guildChannels.firstWhere(
                (c) => c.id == channelId,
              );
              channelName = channel.name;
              break;
            } catch (e) {
              // Channel not found in this guild, continue to next guild
              continue;
            }
          }
        } catch (e) {
          _logger.warn('Failed to lookup channel name: $e');
          // Continue without channel name - will show "Voice Channel" as fallback
        }

        state = state.copyWith(
          activeChannelId: channelId,
          activeChannelName: channelName,
          isConnecting: true,
          error: null,
        );

        // Get LiveKit token from SignalR
        _logger.debug('Requesting LiveKit token via SignalR');
        final response = await _ref.read(chatHubProvider.notifier).invoke(
              'JoinVoiceChannel',
              args: [channelId],
            );

        if (response == null) {
          throw Exception('Failed to get voice token: No response');
        }

        final liveKitToken = response['liveKitToken'] as String?;
        final liveKitUrl = response['liveKitUrl'] as String?;
        final roomName = response['roomName'] as String?;

        if (liveKitToken == null || liveKitUrl == null || roomName == null) {
          throw Exception('Invalid voice token response');
        }

        _logger.debug('LiveKit token received, connecting to room');

        // Connect to LiveKit
        await _voiceService.connect(
          url: liveKitUrl,
          token: liveKitToken,
          roomName: roomName,
        );

        state = state.copyWith(
          isConnected: true,
          isConnecting: false,
          isMuted: false,
          isDeafened: false,
        );

        // Ensure SignalR listeners are setup
        if (!_signalRListenersSetup) {
          _setupSignalRVoiceListeners();
        }

        // Fetch initial participant list
        await _fetchInitialParticipants(channelId);

        // Add current user to participant list if not already added
        await _addCurrentUserToParticipants(channelId);

        _logger.info('Successfully joined voice channel: $channelId');
        return; // Success, exit retry loop
      } catch (e) {
        _logger.error('Failed to join voice channel (attempt $attempt/$maxRetries): $e');
        
        if (attempt < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s
          final delay = Duration(seconds: retryDelay.inSeconds * attempt);
          _logger.info('Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          // Final attempt failed
          state = state.copyWith(
            isConnecting: false,
            error: e.toString(),
          );
        }
      }
    }
  }

  /// Leave voice channel
  Future<void> leaveVoiceChannel() async {
    try {
      _logger.info('Leaving voice channel');

      if (state.activeChannelId == null) {
        _logger.warn('Cannot leave voice: Not in a channel');
        return;
      }

      final channelId = state.activeChannelId!;

      // Notify SignalR
      await _ref.read(chatHubProvider.notifier).invoke(
            'LeaveVoiceChannel',
            args: [channelId],
          );

      // Disconnect from LiveKit
      await _voiceService.disconnect();

      state = VoiceState(); // Reset to default state (activeChannelId and activeChannelName will be null)

      _logger.info('Left voice channel');
    } catch (e) {
      _logger.error('Failed to leave voice channel: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    try {
      final newMutedState = await _voiceService.toggleMicrophone();
      final currentChannelId = state.activeChannelId;

      if (currentChannelId == null) return;

      // Update local state
      state = state.copyWith(isMuted: !newMutedState);

      // Notify SignalR about voice state change
      await _ref.read(chatHubProvider.notifier).invoke(
            'UpdateVoiceState',
            args: [currentChannelId, !newMutedState, state.isDeafened],
          );

      _logger.info('Mute toggled: ${!newMutedState}');
    } catch (e) {
      _logger.error('Failed to toggle mute: $e');
    }
  }

  /// Toggle deafen (speaker off)
  Future<void> toggleDeafen() async {
    try {
      final newDeafenedState = !await _voiceService.toggleSpeaker();
      final currentChannelId = state.activeChannelId;

      if (currentChannelId == null) return;

      // Update local state
      state = state.copyWith(isDeafened: newDeafenedState);

      // If deafened, automatically mute microphone
      if (newDeafenedState && !state.isMuted) {
        await toggleMute();
      }

      // Notify SignalR about voice state change
      await _ref.read(chatHubProvider.notifier).invoke(
            'UpdateVoiceState',
            args: [currentChannelId, state.isMuted, newDeafenedState],
          );

      _logger.info('Deafen toggled: $newDeafenedState');
    } catch (e) {
      _logger.error('Failed to toggle deafen: $e');
    }
  }

  /// Handle user joined voice channel (from SignalR)
  void onUserJoinedVoice(Map<String, dynamic> data) {
    try {
      final channelId = data['channelId'] as String?;
      if (channelId == null) {
        _logger.warn('UserJoinedVoiceChannel event missing channelId');
        return;
      }
      
      final participant = VoiceParticipantDto.fromJson(data);
      
      // Update participantsByChannel map
      final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
      final channelParticipants = List<VoiceParticipantDto>.from(updatedMap[channelId] ?? []);
      
      // Don't add if already exists
      if (channelParticipants.any((p) => p.userId == participant.userId)) {
        _logger.debug('User already in participant list: ${participant.username} (channel: $channelId)');
        return;
      }
      
      channelParticipants.add(participant);
      updatedMap[channelId] = channelParticipants;
      
      // Also update active channel's participants list for backward compatibility
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      if (channelId == state.activeChannelId) {
        if (!currentParticipants.any((p) => p.userId == participant.userId)) {
          currentParticipants.add(participant);
        }
      }
      
      state = state.copyWith(
        participantsByChannel: updatedMap,
        participants: currentParticipants,
      );
      
      _logger.info('User joined voice: ${participant.username} (channel: $channelId, total participants: ${channelParticipants.length})');
      _logger.debug('Updated participantsByChannel keys: ${updatedMap.keys.toList()}');
      _logger.debug('Channel $channelId now has ${updatedMap[channelId]?.length ?? 0} participants');
      _logger.debug('State updated - participantsByChannel size: ${state.participantsByChannel.length}');
    } catch (e) {
      _logger.error('Failed to handle user joined voice: $e');
    }
  }

  /// Handle user left voice channel (from SignalR)
  void onUserLeftVoice(Map<String, dynamic> data) {
    try {
      final channelId = data['channelId'] as String?;
      if (channelId == null) {
        _logger.warn('UserLeftVoiceChannel event missing channelId');
        return;
      }
      
      final userId = data['userId'] as String;
      
      // Update participantsByChannel map
      final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
      final channelParticipants = List<VoiceParticipantDto>.from(updatedMap[channelId] ?? []);
      final beforeCount = channelParticipants.length;
      
      channelParticipants.removeWhere((p) => p.userId == userId);
      updatedMap[channelId] = channelParticipants;
      
      // Also update active channel's participants list for backward compatibility
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      if (channelId == state.activeChannelId) {
        currentParticipants.removeWhere((p) => p.userId == userId);
      }
      
      state = state.copyWith(
        participantsByChannel: updatedMap,
        participants: currentParticipants,
      );
      
      _logger.info('User left voice: $userId (channel: $channelId, before: $beforeCount, after: ${channelParticipants.length})');
      _logger.debug('Updated participantsByChannel keys: ${updatedMap.keys.toList()}');
      _logger.debug('Channel $channelId now has ${updatedMap[channelId]?.length ?? 0} participants');
      _logger.debug('State updated - participantsByChannel size: ${state.participantsByChannel.length}');
    } catch (e) {
      _logger.error('Failed to handle user left voice: $e');
    }
  }

  /// Handle voice state changed (from SignalR)
  void onVoiceStateChanged(Map<String, dynamic> data) {
    try {
      final channelId = data['channelId'] as String?;
      if (channelId == null) {
        _logger.warn('UserVoiceStateChanged event missing channelId');
        return;
      }
      
      final userId = data['userId'] as String;
      final isMuted = data['isMuted'] as bool? ?? false;
      final isDeafened = data['isDeafened'] as bool? ?? false;
      
      // Update participantsByChannel map
      final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
      final channelParticipants = List<VoiceParticipantDto>.from(updatedMap[channelId] ?? []);
      final index = channelParticipants.indexWhere((p) => p.userId == userId);
      
      if (index >= 0) {
        channelParticipants[index] = channelParticipants[index].copyWith(
          isMuted: isMuted,
          isDeafened: isDeafened,
        );
        updatedMap[channelId] = channelParticipants;
        
        // Also update active channel's participants list for backward compatibility
        final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
        if (channelId == state.activeChannelId) {
          final activeIndex = currentParticipants.indexWhere((p) => p.userId == userId);
          if (activeIndex >= 0) {
            currentParticipants[activeIndex] = currentParticipants[activeIndex].copyWith(
              isMuted: isMuted,
              isDeafened: isDeafened,
            );
          }
        }
        
        state = state.copyWith(
          participantsByChannel: updatedMap,
          participants: currentParticipants,
        );
        _logger.debug('Voice state changed for user: $userId (muted: $isMuted, deafened: $isDeafened, channel: $channelId)');
      } else {
        _logger.warn('Voice state changed for unknown user: $userId (channel: $channelId)');
      }
    } catch (e) {
      _logger.error('Failed to handle voice state changed: $e');
    }
  }

  /// Setup network listener
  void _setupNetworkListener() {
    _networkSubscription = _networkService.networkStream.listen((result) {
      if (result.contains(ConnectivityResult.none) && state.isConnected) {
        _logger.warn('Network lost while in voice channel - LiveKit will auto-reconnect');
        // Note: Toast notifications should be shown in UI layer with context
      } else if (!result.contains(ConnectivityResult.none) && state.error != null) {
        _logger.info('Network restored');
        // Clear error if network is back
        state = state.copyWith(error: null);
        
        // Auto-reconnect if we were in a voice channel
        if (state.activeChannelId != null && !state.isConnected) {
          _logger.info('Attempting to reconnect to voice channel: ${state.activeChannelId}');
          final channelId = state.activeChannelId!;
          // Reset state and retry join
          state = state.copyWith(isConnected: false, isConnecting: false);
          joinVoiceChannel(channelId);
        }
      }
    });
  }

  /// Setup voice event listeners (LiveKit events)
  void _setupVoiceEventListeners() {
    _participantConnectedSub = _voiceService.onParticipantConnected.listen((participant) {
      _logger.debug('LiveKit participant connected: ${participant.name} (identity: ${participant.identity})');
      // Participant info will be synced via SignalR events
    });

    _participantDisconnectedSub = _voiceService.onParticipantDisconnected.listen((participant) {
      _logger.debug('LiveKit participant disconnected: ${participant.name} (identity: ${participant.identity})');
      // Participant info will be synced via SignalR events
    });

    _speakingChangedSub = _voiceService.onSpeakingChanged.listen((speakingMap) {
      // Update speaking state for participants (only for active channel - LiveKit only tracks active room)
      if (state.activeChannelId == null) return;
      
      final activeChannelId = state.activeChannelId!;
      final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
      final channelParticipants = List<VoiceParticipantDto>.from(updatedMap[activeChannelId] ?? []);
      bool hasChanges = false;
      bool localUserSpeaking = false;
      
      final currentUserId = _ref.read(authProvider).user?.id;
      
      for (var i = 0; i < channelParticipants.length; i++) {
        final participant = channelParticipants[i];
        final isSpeaking = speakingMap[participant.userId] ?? false;
        
        if (participant.isSpeaking != isSpeaking) {
          channelParticipants[i] = participant.copyWith(isSpeaking: isSpeaking);
          hasChanges = true;
          
          // Track local user speaking state
          if (participant.userId == currentUserId && isSpeaking) {
            localUserSpeaking = true;
          }
        }
      }
      
      if (hasChanges) {
        updatedMap[activeChannelId] = channelParticipants;
        
        // Also update active channel's participants list for backward compatibility
        final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
        for (var i = 0; i < currentParticipants.length; i++) {
          final participant = currentParticipants[i];
          final isSpeaking = speakingMap[participant.userId] ?? false;
          if (participant.isSpeaking != isSpeaking) {
            currentParticipants[i] = participant.copyWith(isSpeaking: isSpeaking);
          }
        }
        
        state = state.copyWith(
          participantsByChannel: updatedMap,
          participants: currentParticipants,
          isSpeaking: localUserSpeaking,
        );
        _logger.debug('Speaking state updated: ${speakingMap.keys.length} speakers, local user speaking: $localUserSpeaking');
      }
    });
    
    // Listen to room lifecycle events
    final room = _voiceService.room;
    if (room != null) {
      // Note: Room listener is already set in VoiceService
      // We can add additional handling here if needed
      _logger.debug('Voice event listeners setup complete');
    }
  }

  /// Fetch participant list for a specific voice channel
  Future<void> fetchVoiceChannelParticipants(String channelId) async {
    try {
      _logger.debug('Fetching participant list for channel: $channelId');
      
      final response = await _ref.read(chatHubProvider.notifier).invoke(
        'GetVoiceChannelUsers',
        args: [channelId],
      );
      
      if (response != null && response is List) {
        final participants = <VoiceParticipantDto>[];
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            try {
              final participant = VoiceParticipantDto.fromJson(item);
              participants.add(participant);
            } catch (e) {
              _logger.warn('Failed to parse participant: $e');
            }
          }
        }
        
        // Update participantsByChannel map
        final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
        updatedMap[channelId] = participants;
        
        // Also update active channel's participants list for backward compatibility
        final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
        if (channelId == state.activeChannelId) {
          currentParticipants.clear();
          currentParticipants.addAll(participants);
        }
        
        state = state.copyWith(
          participantsByChannel: updatedMap,
          participants: currentParticipants,
        );
        
        _logger.info('Participant list fetched for channel $channelId: ${participants.length} participants');
      } else {
        // No participants - set empty list
        final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
        updatedMap[channelId] = [];
        state = state.copyWith(participantsByChannel: updatedMap);
        _logger.debug('No participants in channel $channelId');
      }
    } catch (e) {
      _logger.warn('Failed to fetch participants for channel $channelId: $e');
      // This is not critical - participants will be synced via SignalR events
    }
  }

  /// Fetch participants for all voice channels in current guild
  Future<void> fetchAllVoiceChannelParticipants() async {
    try {
      final channelState = _ref.read(channelProvider);
      final guildState = _ref.read(guildProvider);
      
      if (guildState.selectedGuildId == null) {
        _logger.debug('No guild selected, skipping voice channel participant fetch');
        return;
      }
      
      final channels = channelState.getChannelsForGuild(guildState.selectedGuildId!);
      final voiceChannels = channels.where((c) => c.type == ChannelType.voice).toList();
      
      _logger.debug('Fetching participants for ${voiceChannels.length} voice channels');
      
      // Fetch participants for each voice channel
      for (final channel in voiceChannels) {
        await fetchVoiceChannelParticipants(channel.id);
      }
    } catch (e) {
      _logger.error('Failed to fetch all voice channel participants: $e');
    }
  }

  /// Fetch initial participant list from backend (for active channel)
  Future<void> _fetchInitialParticipants(String channelId) async {
    await fetchVoiceChannelParticipants(channelId);
  }

  /// Add current user to participant list if not already present
  Future<void> _addCurrentUserToParticipants(String channelId) async {
    try {
      final authState = _ref.read(authProvider);
      final currentUser = authState.user;
      
      if (currentUser == null) {
        _logger.warn('Cannot add current user: Not authenticated');
        return;
      }
      
      // Update participantsByChannel map
      final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
      final channelParticipants = List<VoiceParticipantDto>.from(updatedMap[channelId] ?? []);
      
      // Check if current user is already in the list
      if (channelParticipants.any((p) => p.userId == currentUser.id)) {
        _logger.debug('Current user already in participant list for channel: $channelId');
        return;
      }
      
      // Add current user to participant list
      final localParticipant = VoiceParticipantDto(
        userId: currentUser.id,
        username: currentUser.username,
        displayName: currentUser.displayName,
        isMuted: state.isMuted,
        isDeafened: state.isDeafened,
        isSpeaking: false,
        isLocal: true,
      );
      
      channelParticipants.add(localParticipant);
      updatedMap[channelId] = channelParticipants;
      
      // Also update active channel's participants list for backward compatibility
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      if (channelId == state.activeChannelId) {
        if (!currentParticipants.any((p) => p.userId == currentUser.id)) {
          currentParticipants.add(localParticipant);
        }
      }
      
      state = state.copyWith(
        participantsByChannel: updatedMap,
        participants: currentParticipants,
      );
      
      _logger.info('Current user added to participant list: ${currentUser.username} (channel: $channelId)');
    } catch (e) {
      _logger.error('Failed to add current user to participants: $e');
    }
  }

  @override
  void dispose() {
    // Cleanup SignalR listeners
    if (_signalRListenersSetup) {
      try {
        final chatHub = _ref.read(chatHubProvider.notifier);
        chatHub.off('UserJoinedVoiceChannel');
        chatHub.off('UserLeftVoiceChannel');
        chatHub.off('UserVoiceStateChanged');
        _signalRListenersSetup = false;
        _logger.debug('SignalR voice listeners cleaned up');
      } catch (e) {
        _logger.error('Failed to cleanup SignalR listeners: $e');
      }
    }
    
    // Cleanup stream subscriptions
    _networkSubscription?.cancel();
    _participantConnectedSub?.cancel();
    _participantDisconnectedSub?.cancel();
    _speakingChangedSub?.cancel();
    super.dispose();
  }
}

/// Voice provider
final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  final voiceService = ref.watch(voiceServiceProvider);
  final networkService = ref.watch(connectivityServiceProvider);
  return VoiceNotifier(voiceService, networkService, ref);
});
