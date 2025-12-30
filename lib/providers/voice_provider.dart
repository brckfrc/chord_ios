import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/voice/voice_participant_dto.dart';
import '../services/voice/voice_service.dart';
import '../services/network/connectivity_service.dart';
import '../services/logging/log_service.dart';
import 'signalr/chat_hub_provider.dart';

/// Voice channel state
class VoiceState {
  final String? activeChannelId;
  final bool isConnected;
  final bool isConnecting;
  final bool isMuted;
  final bool isDeafened;
  final bool isSpeaking;
  final List<VoiceParticipantDto> participants;
  final String? error;

  VoiceState({
    this.activeChannelId,
    this.isConnected = false,
    this.isConnecting = false,
    this.isMuted = false,
    this.isDeafened = false,
    this.isSpeaking = false,
    this.participants = const [],
    this.error,
  });

  VoiceState copyWith({
    String? activeChannelId,
    bool? isConnected,
    bool? isConnecting,
    bool? isMuted,
    bool? isDeafened,
    bool? isSpeaking,
    List<VoiceParticipantDto>? participants,
    String? error,
  }) {
    return VoiceState(
      activeChannelId: activeChannelId ?? this.activeChannelId,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      participants: participants ?? this.participants,
      error: error,
    );
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

  VoiceNotifier(this._voiceService, this._networkService, this._ref)
      : super(VoiceState()) {
    _setupNetworkListener();
    _setupVoiceEventListeners();
    _setupSignalRVoiceListeners();
  }
  
  /// Setup SignalR voice event listeners
  void _setupSignalRVoiceListeners() {
    try {
      final chatHub = _ref.read(chatHubProvider.notifier);
      
      // User joined voice channel
      chatHub.on('UserJoinedVoiceChannel', (args) {
        if (args == null || args.isEmpty) return;
        final data = args[0] as Map<String, dynamic>;
        onUserJoinedVoice(data);
      });
      
      // User left voice channel
      chatHub.on('UserLeftVoiceChannel', (args) {
        if (args == null || args.isEmpty) return;
        final data = args[0] as Map<String, dynamic>;
        onUserLeftVoice(data);
      });
      
      // Voice state changed
      chatHub.on('UserVoiceStateChanged', (args) {
        if (args == null || args.isEmpty) return;
        final data = args[0] as Map<String, dynamic>;
        onVoiceStateChanged(data);
      });
      
      _logger.debug('SignalR voice event listeners setup complete');
    } catch (e) {
      _logger.error('Failed to setup SignalR voice listeners: $e');
    }
  }

  /// Join voice channel
  Future<void> joinVoiceChannel(String channelId) async {
    try {
      _logger.info('Joining voice channel: $channelId');

      // Check network first
      if (!await _networkService.isConnected()) {
        _logger.error('Cannot join voice: No network connection');
        state = state.copyWith(error: 'No network connection');
        return;
      }

      state = state.copyWith(isConnecting: true, error: null);

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
        activeChannelId: channelId,
        isConnected: true,
        isConnecting: false,
        isMuted: false,
        isDeafened: false,
      );

      _logger.info('Successfully joined voice channel');
    } catch (e) {
      _logger.error('Failed to join voice channel: $e');
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
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

      state = VoiceState(); // Reset to default state

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
      final participant = VoiceParticipantDto.fromJson(data);
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      
      // Don't add if already exists
      if (currentParticipants.any((p) => p.userId == participant.userId)) {
        return;
      }
      
      currentParticipants.add(participant);
      state = state.copyWith(participants: currentParticipants);
      
      _logger.debug('User joined voice: ${participant.username}');
    } catch (e) {
      _logger.error('Failed to handle user joined voice: $e');
    }
  }

  /// Handle user left voice channel (from SignalR)
  void onUserLeftVoice(Map<String, dynamic> data) {
    try {
      final userId = data['userId'] as String;
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      
      currentParticipants.removeWhere((p) => p.userId == userId);
      state = state.copyWith(participants: currentParticipants);
      
      _logger.debug('User left voice: $userId');
    } catch (e) {
      _logger.error('Failed to handle user left voice: $e');
    }
  }

  /// Handle voice state changed (from SignalR)
  void onVoiceStateChanged(Map<String, dynamic> data) {
    try {
      final userId = data['userId'] as String;
      final isMuted = data['isMuted'] as bool? ?? false;
      final isDeafened = data['isDeafened'] as bool? ?? false;
      
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      final index = currentParticipants.indexWhere((p) => p.userId == userId);
      
      if (index >= 0) {
        currentParticipants[index] = currentParticipants[index].copyWith(
          isMuted: isMuted,
          isDeafened: isDeafened,
        );
        state = state.copyWith(participants: currentParticipants);
      }
      
      _logger.debug('Voice state changed for user: $userId (muted: $isMuted, deafened: $isDeafened)');
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
      }
    });
  }

  /// Setup voice event listeners (LiveKit events)
  void _setupVoiceEventListeners() {
    _participantConnectedSub = _voiceService.onParticipantConnected.listen((participant) {
      _logger.debug('LiveKit participant connected: ${participant.name}');
      // Participant info will be synced via SignalR events
    });

    _participantDisconnectedSub = _voiceService.onParticipantDisconnected.listen((participant) {
      _logger.debug('LiveKit participant disconnected: ${participant.name}');
      // Participant info will be synced via SignalR events
    });

    _speakingChangedSub = _voiceService.onSpeakingChanged.listen((speakingMap) {
      // Update speaking state for participants
      final currentParticipants = List<VoiceParticipantDto>.from(state.participants);
      for (var i = 0; i < currentParticipants.length; i++) {
        final isSpeaking = speakingMap[currentParticipants[i].userId] ?? false;
        currentParticipants[i] = currentParticipants[i].copyWith(isSpeaking: isSpeaking);
      }
      state = state.copyWith(participants: currentParticipants);
    });
    
    // Listen to room lifecycle events
    final room = _voiceService.room;
    if (room != null) {
      // Note: Room listener is already set in VoiceService
      // We can add additional handling here if needed
      _logger.debug('Voice event listeners setup complete');
    }
  }

  @override
  void dispose() {
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
