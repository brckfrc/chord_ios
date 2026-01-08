import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import '../logging/log_service.dart';

/// LiveKit Room wrapper service
class VoiceService {
  Room? _room;
  final LogService _logger = LogService('VoiceService');
  bool _isDeafened = false;

  // Event stream controllers
  final _participantConnectedController =
      StreamController<Participant>.broadcast();
  final _participantDisconnectedController =
      StreamController<Participant>.broadcast();
  final _speakingChangedController =
      StreamController<Map<String, bool>>.broadcast();
  final _trackMutedController = StreamController<TrackMutedEvent>.broadcast();
  final _connectionStateController = StreamController<String>.broadcast();

  /// Current room instance
  Room? get room => _room;

  /// Is connected to a room
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  /// Local participant
  LocalParticipant? get localParticipant => _room?.localParticipant;

  /// Remote participants
  List<RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];

  /// All participants (local + remote)
  List<Participant> get allParticipants {
    final participants = <Participant>[];
    if (_room?.localParticipant != null) {
      participants.add(_room!.localParticipant!);
    }
    participants.addAll(remoteParticipants);
    return participants;
  }

  // Event streams
  Stream<Participant> get onParticipantConnected =>
      _participantConnectedController.stream;
  Stream<Participant> get onParticipantDisconnected =>
      _participantDisconnectedController.stream;
  Stream<Map<String, bool>> get onSpeakingChanged =>
      _speakingChangedController.stream;
  Stream<TrackMutedEvent> get onTrackMuted => _trackMutedController.stream;
  Stream<String> get onConnectionStateChanged =>
      _connectionStateController.stream;

  /// Connect to LiveKit room
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
  }) async {
    try {
      _logger.info('Connecting to LiveKit: $url, room: $roomName');

      // Disconnect existing room if any
      if (_room != null) {
        await disconnect();
      }

      _room = Room();

      // Setup room event listeners
      _setupRoomListeners();

      // Connect with options
      await _room!.connect(
        url,
        token,
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: const AudioPublishOptions(
            name: 'microphone',
            audioBitrate: 64000, // 64 kbps - good quality for voice
            // Opus codec is default, no need to specify
          ),
        ),
      );

      _logger.info('Connected to room: $roomName');

      // Enable microphone by default
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _logger.info('Microphone enabled');
    } catch (e) {
      _logger.error('LiveKit connection failed: $e');
      rethrow;
    }
  }

  /// Disconnect from room
  Future<void> disconnect() async {
    try {
      if (_room == null) return;

      _logger.info('Disconnecting from voice channel');

      await _room!.disconnect();
      await _room!.dispose();
      _room = null;

      _logger.info('Disconnected from voice channel');
    } catch (e) {
      _logger.error('Failed to disconnect: $e');
    }
  }

  /// Toggle microphone on/off
  Future<bool> toggleMicrophone() async {
    try {
      if (_room?.localParticipant == null) {
        _logger.warn('Cannot toggle microphone: Not in a room');
        return false;
      }

      final currentState = _room!.localParticipant!.isMicrophoneEnabled();
      final newState = !currentState;

      await _room!.localParticipant!.setMicrophoneEnabled(newState);
      _logger.info('Microphone ${newState ? "enabled" : "disabled"}');

      return newState;
    } catch (e) {
      _logger.error('Failed to toggle microphone: $e');
      return false;
    }
  }

  /// Toggle speaker (deafen) on/off
  /// Returns true if deafened, false if not deafened
  Future<bool> toggleSpeaker() async {
    try {
      if (_room == null) {
        _logger.warn('Cannot toggle speaker: Not in a room');
        return false;
      }

      // Get current deafen state
      final currentState = _isDeafened;
      final newState = !currentState;
      _isDeafened = newState;

      // Disable/enable all remote audio tracks
      final remoteParticipants = _room!.remoteParticipants.values;
      for (final participant in remoteParticipants) {
        for (final trackPub in participant.audioTrackPublications) {
          final audioTrack = trackPub.track as AudioTrack?;
          if (audioTrack != null) {
            // Disable track to stop audio playback
            await audioTrack.disable();
            if (!newState) {
              // Re-enable if undeafening
              await audioTrack.enable();
            }
          }
        }
      }

      _logger.info('Speaker ${newState ? "disabled (deafened)" : "enabled"}');
      return newState;
    } catch (e) {
      _logger.error('Failed to toggle speaker: $e');
      return _isDeafened;
    }
  }

  /// Get current microphone state
  bool get isMicrophoneEnabled {
    return _room?.localParticipant?.isMicrophoneEnabled() ?? false;
  }

  /// Get current speaker state (deafen)
  bool get isSpeakerEnabled {
    return !_isDeafened;
  }

  /// Get connection quality based on room state
  /// Returns quality level based on connection state and room status
  String getConnectionQuality() {
    if (_room == null) {
      return 'disconnected';
    }

    final connectionState = _room!.connectionState;

    if (connectionState == ConnectionState.connected) {
      // If connected, assume good quality (LiveKit handles quality internally)
      // In future, can use Room.engine.stats for more accurate quality
      return 'good';
    } else if (connectionState == ConnectionState.connecting ||
        connectionState == ConnectionState.reconnecting) {
      return 'poor';
    } else {
      return 'disconnected';
    }
  }

  /// Setup room event listeners
  void _setupRoomListeners() {
    if (_room == null) return;

    // Create listener - it will be automatically disposed when room is disposed
    final listener = _room!.createListener();

    // Connection state events
    listener
      ..on<RoomConnectedEvent>((event) {
        _logger.info('Room connected - emitting to stream');
        _connectionStateController.add('connected');
      })
      ..on<RoomDisconnectedEvent>((event) {
        _logger.error('❌ [VoiceService] Room disconnected: ${event.reason} - emitting to stream');
        _logger.error('   - Reason: ${event.reason}');
        _logger.error('   - Room name: ${_room?.name ?? "null"}');
        _connectionStateController.add('disconnected');
      })
      ..on<RoomReconnectingEvent>((event) {
        _logger.warn('Room reconnecting... - emitting to stream');
        _connectionStateController.add('reconnecting');
      })
      ..on<RoomReconnectedEvent>((event) {
        _logger.info('Room reconnected - emitting to stream');
        _connectionStateController.add('reconnected');
      })
      // Participant events
      ..on<ParticipantConnectedEvent>((event) {
        _logger.debug('Participant connected: ${event.participant.name}');
        _participantConnectedController.add(event.participant);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _logger.debug('Participant disconnected: ${event.participant.name}');
        _participantDisconnectedController.add(event.participant);
      })
      // Active speakers
      ..on<ActiveSpeakersChangedEvent>((event) {
        final speakingMap = <String, bool>{};
        for (final speaker in event.speakers) {
          // Use identity (userId) instead of sid for mapping
          // Backend sets participant identity as userId in LiveKit token
          final userId = speaker.identity.isNotEmpty
              ? speaker.identity
              : (speaker.name.isNotEmpty ? speaker.name : speaker.sid);
          if (userId.isNotEmpty) {
            speakingMap[userId] = true;
            _logger.debug(
              'Active speaker: ${speaker.name} (identity: ${speaker.identity}, sid: ${speaker.sid}, userId: $userId)',
            );
          }
        }
        _speakingChangedController.add(speakingMap);
        _logger.debug(
          'Active speakers: ${event.speakers.length} (userIds: ${speakingMap.keys.toList()})',
        );
      })
      // Track mute events
      ..on<TrackMutedEvent>((event) {
        _logger.debug('Track muted: ${event.participant.name}');
        _trackMutedController.add(
          TrackMutedEvent(event.publication, event.participant, true),
        );
      })
      ..on<TrackUnmutedEvent>((event) {
        _logger.debug('Track unmuted: ${event.participant.name}');
        _trackMutedController.add(
          TrackMutedEvent(event.publication, event.participant, false),
        );
      });
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    // Room listener is automatically disposed when room is disposed
    await _participantConnectedController.close();
    await _participantDisconnectedController.close();
    await _speakingChangedController.close();
    await _trackMutedController.close();
    await _connectionStateController.close();
  }
}

/// Track muted event
class TrackMutedEvent {
  final TrackPublication publication;
  final Participant participant;
  final bool isMuted;

  TrackMutedEvent(this.publication, this.participant, this.isMuted);
}
