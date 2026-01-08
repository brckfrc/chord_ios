import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '../models/voice/voice_participant_dto.dart';
import '../services/voice/voice_service.dart';
import '../services/network/connectivity_service.dart';
import '../services/logging/log_service.dart';
import 'signalr/chat_hub_provider.dart';
import 'auth_provider.dart';
import 'channel_provider.dart';
import 'guild_provider.dart';
import '../models/guild/channel_type.dart';

/// Connection quality levels
enum ConnectionQuality {
  excellent,
  good,
  poor,
  disconnected,
}

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
  final ConnectionQuality connectionQuality; // Network connection quality
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
    this.connectionQuality = ConnectionQuality.disconnected,
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
    ConnectionQuality? connectionQuality,
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
      connectionQuality: connectionQuality ?? this.connectionQuality,
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
  StreamSubscription? _connectionStateSub;
  Timer? _connectionStateCheckTimer;
  bool _signalRListenersSetup = false;
  bool _isLeavingChannel = false; // Flag to prevent state updates during leave

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

  /// Parse connection quality string to enum
  ConnectionQuality _parseConnectionQuality(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return ConnectionQuality.excellent;
      case 'good':
        return ConnectionQuality.good;
      case 'poor':
        return ConnectionQuality.poor;
      default:
        return ConnectionQuality.disconnected;
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

  /// Join voice channel with improved retry logic
  Future<void> joinVoiceChannel(String channelId) async {
    const maxRetries = 5;
    const baseDelayMs = 2000; // 2 seconds base delay
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _logger.info('Joining voice channel: $channelId (attempt $attempt/$maxRetries)');

        // Check network first
        if (!await _networkService.isConnected()) {
          if (attempt < maxRetries) {
            // Exponential backoff: baseDelay * (2 ^ (attempt - 1))
            final delayMs = (baseDelayMs * pow(2, attempt - 1)).toInt();
            final delay = Duration(milliseconds: delayMs);
            _logger.warn('No network connection, retrying in ${delay.inSeconds}s... (reason: network)');
            await Future.delayed(delay);
            continue;
          }
          _logger.error('Cannot join voice: No network connection after $maxRetries attempts');
          state = state.copyWith(
            isConnecting: false,
            error: 'No network connection',
          );
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
        String? retryReason;
        try {
          final response = await _ref.read(chatHubProvider.notifier).invoke(
                'JoinVoiceChannel',
                args: [channelId],
              );

          if (response == null) {
            retryReason = 'token';
            throw Exception('Failed to get voice token: No response');
          }

          final liveKitToken = response['liveKitToken'] as String?;
          final liveKitUrl = response['liveKitUrl'] as String?;
          final roomName = response['roomName'] as String?;

          if (liveKitToken == null || liveKitUrl == null || roomName == null) {
            retryReason = 'token';
            throw Exception('Invalid voice token response');
          }

          _logger.debug('LiveKit token received, connecting to room');

          // Connect to LiveKit
          retryReason = 'livekit';
          await _voiceService.connect(
            url: liveKitUrl,
            token: liveKitToken,
            roomName: roomName,
          );
        } catch (e) {
          // Re-throw token errors
          if (retryReason == 'token') {
            rethrow;
          }
          // Continue to LiveKit connection error handling
          throw e;
        }

        // Update connection quality
        final qualityString = _voiceService.getConnectionQuality();
        final quality = _parseConnectionQuality(qualityString);
        
        state = state.copyWith(
          isConnected: true,
          isConnecting: false,
          isMuted: false,
          isDeafened: false,
          connectionQuality: quality,
        );

        // Ensure SignalR listeners are setup
        if (!_signalRListenersSetup) {
          _setupSignalRVoiceListeners();
        }

        // Start periodic connection state check
        _startConnectionStateCheck();

        // Fetch initial participant list
        await _fetchInitialParticipants(channelId);

        // Add current user to participant list if not already added
        await _addCurrentUserToParticipants(channelId);

        _logger.info('Successfully joined voice channel: $channelId');
        return; // Success, exit retry loop
      } catch (e) {
        // Determine retry reason from error type
        String errorReason = 'unknown';
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('network') || errorString.contains('connection')) {
          errorReason = 'network';
        } else if (errorString.contains('token') || errorString.contains('auth')) {
          errorReason = 'token';
        } else if (errorString.contains('livekit') || errorString.contains('room')) {
          errorReason = 'livekit';
        }
        
        _logger.error('Failed to join voice channel (attempt $attempt/$maxRetries, reason: $errorReason): $e');
        
        if (attempt < maxRetries) {
          // Exponential backoff: baseDelay * (2 ^ (attempt - 1))
          // Results in: 2s, 4s, 8s, 16s, 32s
          final delayMs = (baseDelayMs * pow(2, attempt - 1)).toInt();
          final delay = Duration(milliseconds: delayMs);
          _logger.info('Retrying in ${delay.inSeconds}s... (reason: $errorReason)');
          
          // Update state to show reconnecting
          state = state.copyWith(
            isConnecting: true,
            error: 'Reconnecting... (attempt $attempt/$maxRetries)',
          );
          
          await Future.delayed(delay);
        } else {
          // Final attempt failed
          _logger.error('Failed to join voice channel after $maxRetries attempts');
          state = state.copyWith(
            isConnecting: false,
            error: 'Failed to connect: ${e.toString()}',
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

      // Set flag to prevent connection state listener from interfering
      _isLeavingChannel = true;

      final channelId = state.activeChannelId!;
      final authState = _ref.read(authProvider);
      final currentUserId = authState.user?.id;

      // Remove current user from participant list (if exists)
      if (currentUserId != null) {
        final updatedMap = Map<String, List<VoiceParticipantDto>>.from(state.participantsByChannel);
        final channelParticipants = List<VoiceParticipantDto>.from(updatedMap[channelId] ?? []);
        channelParticipants.removeWhere((p) => p.userId == currentUserId);
        updatedMap[channelId] = channelParticipants;
        
        // Update state with cleaned participant list (keep other channels' participants)
        state = state.copyWith(
          participantsByChannel: updatedMap,
          participants: [], // Clear active channel participants
        );
        
        _logger.info('Removed current user from participant list (channel: $channelId, remaining: ${channelParticipants.length})');
      }

      // Notify SignalR
      await _ref.read(chatHubProvider.notifier).invoke(
            'LeaveVoiceChannel',
            args: [channelId],
          );

      // Disconnect from LiveKit
      await _voiceService.disconnect();

      // Reset only user's own connection state, keep participantsByChannel for other channels
      state = state.copyWith(
        activeChannelId: null,
        activeChannelName: null,
        isConnected: false,
        isConnecting: false,
        isMuted: false,
        isDeafened: false,
        isSpeaking: false,
        participants: [], // Clear active channel participants
        error: null,
        connectionQuality: ConnectionQuality.disconnected,
        // Keep participantsByChannel - don't clear it!
      );

      // Stop periodic connection state check
      _stopConnectionStateCheck();

      // Reset flag after a short delay to allow any pending events to be ignored
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLeavingChannel = false;
      });

      _logger.info('Left voice channel (participantsByChannel preserved for other channels)');
    } catch (e) {
      _logger.error('Failed to leave voice channel: $e');
      state = state.copyWith(error: e.toString());
      _isLeavingChannel = false; // Reset flag on error
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
        // Clear error if network is back and update quality
        final qualityString = _voiceService.getConnectionQuality();
        final quality = _parseConnectionQuality(qualityString);
        state = state.copyWith(
          error: null,
          connectionQuality: quality,
        );
        
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

    // Listen to connection state changes
    _connectionStateSub = _voiceService.onConnectionStateChanged.listen((stateString) {
      _logger.debug('LiveKit connection state changed: $stateString');
      
      // Ignore connection state changes if we're in the process of leaving
      if (_isLeavingChannel) {
        _logger.debug('Ignoring connection state change during leave: $stateString');
        return;
      }
      
      if (stateString == 'disconnected') {
        // Only update if we're actually in a channel and not already disconnected
        if (state.activeChannelId != null && state.isConnected) {
          _logger.warn('⚠️ [Connection State] Unexpected disconnect while in channel');
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
            connectionQuality: ConnectionQuality.disconnected,
            error: 'Connection lost',
          );
          
          // Attempt to reconnect if we're still in a channel
          final channelId = state.activeChannelId;
          if (channelId != null) {
            _logger.info('🔄 [Connection State] Attempting to reconnect to channel: $channelId');
            // Trigger reconnection after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (state.activeChannelId == channelId && !state.isConnected) {
                _logger.info('🔄 [Connection State] Reconnecting to voice channel...');
                joinVoiceChannel(channelId);
              }
            });
          }
        }
      } else if (stateString == 'reconnecting') {
        // Only update if we're in a channel
        if (state.activeChannelId != null) {
          state = state.copyWith(
            isConnecting: true,
            connectionQuality: ConnectionQuality.poor,
            error: 'Reconnecting...',
          );
        }
      } else if (stateString == 'reconnected' || stateString == 'connected') {
        // Only update if we're in a channel
        if (state.activeChannelId != null) {
          state = state.copyWith(
            isConnected: true,
            isConnecting: false,
            connectionQuality: ConnectionQuality.good,
            error: null,
          );
        }
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
    _connectionStateSub?.cancel();
    _stopConnectionStateCheck();
    super.dispose();
  }

  /// Start periodic connection state check (heartbeat)
  void _startConnectionStateCheck() {
    _stopConnectionStateCheck(); // Stop existing timer if any
    
    // Check every 2 seconds instead of 5 for faster detection
    _connectionStateCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state.activeChannelId == null) {
        // Not in a channel, stop checking
        _stopConnectionStateCheck();
        return;
      }

      // Check actual connection state from LiveKit
      final room = _voiceService.room;
      if (room == null) {
        // Room is null but we think we're connected - update state
        if (state.isConnected) {
          _logger.warn('⚠️ [Connection Check] Room is null but state says connected - updating state');
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
            connectionQuality: ConnectionQuality.disconnected,
            error: 'Connection lost',
          );
        }
        return;
      }

      // Check both connectionState and isConnected property
      final connectionState = room.connectionState;
      final isRoomConnected = _voiceService.isConnected;
      
      // Log detailed state for debugging
      if (state.isConnected && (connectionState != livekit.ConnectionState.connected || !isRoomConnected)) {
        _logger.warn('⚠️ [Connection Check] State mismatch detected!');
        _logger.warn('   - Our state.isConnected: ${state.isConnected}');
        _logger.warn('   - Room.connectionState: $connectionState');
        _logger.warn('   - Room.isConnected: $isRoomConnected');
      }

      // Check if we have remote participants with audio tracks (indicates WebRTC is working)
      final remoteParticipants = room.remoteParticipants.values.toList();
      final hasActiveAudioTracks = remoteParticipants.any((p) {
        return p.audioTrackPublications.any((trackPub) => 
          trackPub.track != null
        );
      });
      
      // If we think we're connected but LiveKit says disconnected, update state
      if (state.isConnected && (connectionState != livekit.ConnectionState.connected || !isRoomConnected)) {
        _logger.warn('⚠️ [Connection Check] Connection lost detected - updating state');
        
        if (connectionState == livekit.ConnectionState.disconnected || !isRoomConnected) {
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
            connectionQuality: ConnectionQuality.disconnected,
            error: 'Connection lost',
          );
          _logger.error('❌ [Connection Check] Marked as disconnected');
          
          // Attempt to reconnect
          final channelId = state.activeChannelId;
          if (channelId != null) {
            _logger.info('🔄 [Connection Check] Attempting to reconnect to channel: $channelId');
            Future.delayed(const Duration(seconds: 2), () {
              if (state.activeChannelId == channelId && !state.isConnected) {
                _logger.info('🔄 [Connection Check] Reconnecting to voice channel...');
                joinVoiceChannel(channelId);
              }
            });
          }
        } else if (connectionState == livekit.ConnectionState.reconnecting) {
          state = state.copyWith(
            isConnecting: true,
            connectionQuality: ConnectionQuality.poor,
            error: 'Reconnecting...',
          );
          _logger.warn('🔄 [Connection Check] Marked as reconnecting');
        }
      } else if (state.isConnected && connectionState == livekit.ConnectionState.connected && isRoomConnected) {
        // Check if WebRTC is actually working (we have remote participants but no audio tracks)
        if (remoteParticipants.isNotEmpty && !hasActiveAudioTracks) {
          _logger.warn('⚠️ [Connection Check] Room connected but no active audio tracks detected');
          _logger.warn('   - Remote participants: ${remoteParticipants.length}');
          _logger.warn('   - This may indicate WebRTC connection issues');
          
          // If this persists for multiple checks, trigger reconnection
          // (We'll track this with a counter in the next iteration)
        }
      }
    });
  }

  /// Stop periodic connection state check
  void _stopConnectionStateCheck() {
    _connectionStateCheckTimer?.cancel();
    _connectionStateCheckTimer = null;
  }
}

/// Voice provider
final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  final voiceService = ref.watch(voiceServiceProvider);
  final networkService = ref.watch(connectivityServiceProvider);
  return VoiceNotifier(voiceService, networkService, ref);
});
