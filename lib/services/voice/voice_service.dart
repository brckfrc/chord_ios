import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import '../logging/log_service.dart';
import '../permissions/permission_service.dart';

/// LiveKit Room wrapper service
class VoiceService {
  Room? _room;
  final LogService _logger = LogService('VoiceService');
  final PermissionService _permissionService = PermissionService();
  bool _isDeafened = false;
  Timer? _periodicMicrophoneCheckTimer;
  int _consecutiveNoAudioChecks = 0; // Track consecutive checks with no audio data detected
  static const int _maxConsecutiveNoAudioChecks = 3; // After 3 checks, try aggressive recovery
  DateTime? _lastLocalUserSpeakingTime; // Track when local user was last detected as speaking
  DateTime? _audioTrackPublishedTime; // Track when audio track was first published
  static const Duration _maxTimeWithoutSpeaking = Duration(seconds: 15); // Threshold for recovery
  EventsListener? _localParticipantListener; // Listener for local participant events
  bool _isMicrophoneManuallyDisabled = false; // Track if user manually disabled microphone (prevents auto-recovery)

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

      // Reset manual disable flag on new connection
      _isMicrophoneManuallyDisabled = false;

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
          // Note: LiveKit SDK auto-subscribes to remote audio tracks by default
          // We handle enabling tracks in TrackSubscribedEvent listener
          // Enable automatic reconnection
          // Note: LiveKit SDK handles reconnection automatically, but we can configure it
          // The SDK will attempt to reconnect on connection loss
        ),
      );

      _logger.info('Connected to room: $roomName');

      // Reset consecutive failure counter on new connection
      _consecutiveNoAudioChecks = 0;
      _lastLocalUserSpeakingTime = null; // Reset speaking detection time
      _audioTrackPublishedTime = null; // Reset track publish time

      // Setup local participant listener for SpeakingChangedEvent
      _setupLocalParticipantListener();

      // Configure audio output routing for Android
      // This ensures audio is routed to speaker instead of earpiece
      try {
        await _room!.setSpeakerOn(true);
        _logger.info('✅ [Audio Routing] Speaker enabled for audio output');
      } catch (e) {
        _logger.warn('⚠️ [Audio Routing] Failed to set speaker on: $e (continuing...)');
      }

      // Enable microphone by default with aggressive approach
      await _ensureLocalMicrophoneEnabled();
      _logger.info('Microphone enabled');

      // Wait for track to be published before checking
      await Future.delayed(const Duration(milliseconds: 1000));

      // Then ensure microphone is enabled (will check track status)
      if (_room?.localParticipant != null) {
        await ensureMicrophoneEnabled(isPeriodicCheck: false);
      }

      // Start periodic microphone monitoring
      _startPeriodicMicrophoneCheck();
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

      // Stop periodic microphone check
      _stopPeriodicMicrophoneCheck();

      // Dispose local participant listener
      _localParticipantListener?.dispose();
      _localParticipantListener = null;

      // Reset consecutive failure counter on disconnect
      _consecutiveNoAudioChecks = 0;
      _lastLocalUserSpeakingTime = null; // Reset speaking detection time
      _audioTrackPublishedTime = null; // Reset track publish time
      _isMicrophoneManuallyDisabled = false; // Reset manual disable flag

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

      if (newState) {
        // User is enabling microphone - clear manual disable flag
        _isMicrophoneManuallyDisabled = false;
        // Use aggressive enable approach when enabling microphone
        await _ensureLocalMicrophoneEnabled();
      } else {
        // User is disabling microphone - set manual disable flag to prevent auto-recovery
        _isMicrophoneManuallyDisabled = true;
        // Simple disable when turning off
        await _room!.localParticipant!.setMicrophoneEnabled(false);
      }
      
      _logger.info('Microphone ${newState ? "enabled" : "disabled"} (manually disabled: ${!newState})');

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

  /// Check if local audio track is published and active
  bool get isLocalAudioTrackActive {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) return false;

    // Use trackPublications and check kind
    final allTracks = localParticipant.trackPublications.values;
    return allTracks.any((trackPub) {
      final kindString = trackPub.kind.toString().toLowerCase();
      return kindString.contains('audio') &&
          trackPub.track != null &&
          !trackPub.muted;
      // Note: For local tracks, enabled state is managed by setMicrophoneEnabled()
      // We verify track is published, exists, and is not muted
    });
  }

  /// Ensure microphone is enabled and track is published
  /// This method checks and re-enables microphone if it's disabled or track is unpublished
  /// [isPeriodicCheck] indicates if this is a periodic check (true) or initial check (false)
  Future<void> ensureMicrophoneEnabled({bool isPeriodicCheck = false}) async {
    final timestamp = DateTime.now().toIso8601String();
    final checkType = isPeriodicCheck ? 'Periodic' : 'Initial';
    _logger.debug('🔍 [Microphone Recovery] [$checkType] Starting ensureMicrophoneEnabled check at $timestamp');
    
    if (_room?.localParticipant == null) {
      _logger.warn('⚠️ [Microphone Recovery] [$checkType] Room or local participant is null');
      return;
    }

    final localParticipant = _room!.localParticipant!;
    _logger.debug('🔍 [Microphone Recovery] [$checkType] Local participant found');

    // Check if user manually disabled microphone - if so, don't auto-recover
    if (_isMicrophoneManuallyDisabled) {
      _logger.debug(
        '🔍 [Microphone Recovery] [$checkType] Microphone was manually disabled by user - skipping auto-recovery',
      );
      return;
    }

    // Check microphone permission first
    final hasPermission = await _permissionService.isMicrophoneGranted();
    if (!hasPermission) {
      _logger.warn(
        '⚠️ [Microphone Recovery] [$checkType] Microphone permission not granted. Requesting permission...',
      );
      final granted = await _permissionService.requestMicrophonePermission();
      if (!granted) {
        _logger.error(
          '❌ [Microphone Recovery] [$checkType] Microphone permission denied. Cannot enable microphone.',
        );
        return;
      }
      _logger.info('✅ [Microphone Recovery] [$checkType] Microphone permission granted');
    }

    // Check WebRTC connection state
    final connectionState = _room!.connectionState;
    _logger.debug('🔍 [Microphone Recovery] [$checkType] WebRTC connection state: $connectionState');
    
    if (connectionState != ConnectionState.connected) {
      if (connectionState == ConnectionState.disconnected) {
        _logger.error(
          '❌ [Microphone Recovery] [$checkType] WebRTC connection is down (state: $connectionState). '
          'Cannot recover microphone - connection-level issue. VoiceProvider will handle reconnection.',
        );
      } else if (connectionState == ConnectionState.reconnecting || 
                 connectionState == ConnectionState.connecting) {
        _logger.warn(
          '⚠️ [Microphone Recovery] [$checkType] WebRTC connection is not ready (state: $connectionState). '
          'Waiting for connection to establish before checking microphone.',
        );
      } else {
        _logger.warn(
          '⚠️ [Microphone Recovery] [$checkType] WebRTC connection state is unexpected: $connectionState',
        );
      }
      return;
    }

    // Check if microphone is enabled
    final isMicEnabled = localParticipant.isMicrophoneEnabled();
    _logger.debug('🔍 [Microphone Recovery] [$checkType] Microphone enabled state: $isMicEnabled');
    
    if (!isMicEnabled) {
      _logger.warn(
        '⚠️ [Microphone Recovery] [$checkType] Microphone is disabled, re-enabling...',
      );
      try {
        await localParticipant.setMicrophoneEnabled(true);
        _logger.info(
          '✅ [Microphone Recovery] Microphone re-enabled successfully',
        );
        // Wait for track to be published
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        _logger.error(
          '❌ [Microphone Recovery] Failed to re-enable microphone: $e',
        );
        return;
      }
    }

    // Check if audio track is published (use trackPublications with kind check)
    final allTracks = localParticipant.trackPublications.values;
    _logger.debug('🔍 [Microphone Recovery] [$checkType] Checking ${allTracks.length} track publications');
    
    for (final trackPub in allTracks) {
      final kindString = trackPub.kind.toString().toLowerCase();
      final isAudio = kindString.contains('audio');
      final hasTrack = trackPub.track != null;
      _logger.debug(
        '🔍 [Microphone Recovery] [$checkType] Track: name=${trackPub.name}, kind=$kindString, isAudio=$isAudio, hasTrack=$hasTrack, muted=${trackPub.muted}',
      );
    }
    
    final hasPublishedAudioTrack = allTracks.any((trackPub) {
      final kindString = trackPub.kind.toString().toLowerCase();
      return kindString.contains('audio') && trackPub.track != null;
    });

    _logger.debug('🔍 [Microphone Recovery] [$checkType] Has published audio track: $hasPublishedAudioTrack');

    if (!hasPublishedAudioTrack) {
      _logger.warn(
        '⚠️ [Microphone Recovery] [$checkType] No published audio track found, re-enabling microphone...',
      );
      try {
        await localParticipant.setMicrophoneEnabled(true);
        _logger.info(
          '✅ [Microphone Recovery] Microphone re-enabled after track unpublish',
        );
        // Wait for track to be published
        await Future.delayed(const Duration(milliseconds: 300));
        // Re-check after delay
        final recheckTracks = localParticipant.trackPublications.values;
        _logger.debug('🔍 [Microphone Recovery] [$checkType] Re-checking ${recheckTracks.length} tracks after delay');
        
        final recheckHasTrack = recheckTracks.any((trackPub) {
          final kindString = trackPub.kind.toString().toLowerCase();
          return kindString.contains('audio') && trackPub.track != null;
        });
        
        _logger.debug('🔍 [Microphone Recovery] [$checkType] Re-check result: hasTrack=$recheckHasTrack');
        
        if (!recheckHasTrack) {
          _logger.warn(
            '⚠️ [Microphone Recovery] Track still not published after re-enable',
          );
        }
      } catch (e) {
        _logger.error(
          '❌ [Microphone Recovery] Failed to re-enable microphone: $e',
        );
      }
      return;
    }

    // Check if audio track is actually enabled and sending data
    // Find the audio track publication and verify it's properly enabled
    TrackPublication? audioTrackPublication;
    for (final trackPub in allTracks) {
      final kindString = trackPub.kind.toString().toLowerCase();
      if (kindString.contains('audio') && trackPub.track != null) {
        audioTrackPublication = trackPub;
        break;
      }
    }
    
    if (audioTrackPublication != null) {
      final audioTrack = audioTrackPublication.track;
      if (audioTrack != null) {
        _logger.debug('🔍 [Microphone Recovery] [$checkType] Audio track found: name=${audioTrackPublication.name}, muted=${audioTrackPublication.muted}');
        
        // Verify audio track is properly configured
        // For local audio tracks, enabled state is controlled by microphone enabled state
        // Log track details for debugging
        _logger.debug('🔍 [Microphone Recovery] [$checkType] Audio track state verified: published=true, muted=${audioTrackPublication.muted}');
        
        // Check MediaStreamTrack readyState if available (LocalAudioTrack)
        bool trackStateValid = true;
        if (audioTrack is LocalAudioTrack) {
          try {
            // Try to access MediaStreamTrack properties
            // Note: LiveKit SDK may not expose readyState directly, but we can check other properties
            final localAudioTrack = audioTrack;
            _logger.debug('🔍 [Microphone Recovery] [$checkType] LocalAudioTrack detected, checking track state...');
            
            // Check if track has source (indicates it's properly initialized)
            // Some SDKs expose source or mediaStreamTrack property
            _logger.debug('🔍 [Microphone Recovery] [$checkType] LocalAudioTrack type: ${localAudioTrack.runtimeType}');
            
            // Try to access mediaStreamTrack.enabled property directly (similar to remote tracks)
            try {
              final trackDynamic = localAudioTrack as dynamic;
              if (trackDynamic.mediaStreamTrack != null) {
                final mediaStreamTrack = trackDynamic.mediaStreamTrack as dynamic;
                if (mediaStreamTrack.enabled != null) {
                  final isEnabled = mediaStreamTrack.enabled as bool;
                  _logger.debug(
                    '🔍 [Microphone Recovery] [$checkType] Found mediaStreamTrack.enabled property: $isEnabled',
                  );
                  if (!isEnabled) {
                    _logger.warn(
                      '⚠️ [Microphone Recovery] [$checkType] LocalAudioTrack mediaStreamTrack.enabled is false! '
                      'Setting to true...',
                    );
                    mediaStreamTrack.enabled = true;
                    _logger.info(
                      '✅ [Microphone Recovery] [$checkType] Set LocalAudioTrack mediaStreamTrack.enabled = true',
                    );
                    trackStateValid = true;
                  } else {
                    trackStateValid = true;
                    _logger.debug(
                      '✅ [Microphone Recovery] [$checkType] LocalAudioTrack mediaStreamTrack.enabled is true',
                    );
                  }
                } else {
                  trackStateValid = true; // Assume valid if property not accessible
                }
              } else {
                trackStateValid = true; // Assume valid if mediaStreamTrack not accessible
              }
            } catch (e) {
              _logger.debug(
                '🔍 [Microphone Recovery] [$checkType] Cannot access mediaStreamTrack directly: $e (assuming valid)',
              );
              trackStateValid = true; // Assume valid unless we detect issues
            }
            
            _logger.debug('🔍 [Microphone Recovery] [$checkType] Track state check: valid=$trackStateValid');
          } catch (e) {
            _logger.warn('⚠️ [Microphone Recovery] [$checkType] Error checking LocalAudioTrack state: $e');
            trackStateValid = false;
          }
        }
        
        // Check WebRTC stats for audio data transmission (if available)
        bool hasAudioData = false;
        try {
          // Try to get stats from room engine
          // Note: LiveKit SDK may not expose engine directly, so we wrap in try-catch
          if (_room != null) {
            _logger.debug('🔍 [Microphone Recovery] [$checkType] WebRTC stats check: attempting to verify audio transmission...');
            
            // Try to access room engine stats if available
            // LiveKit SDK structure varies, so we try multiple approaches
            try {
              // Attempt 1: Try room.engine.getStats() if available
              // This might not be directly accessible in Flutter SDK
              _logger.debug('🔍 [Microphone Recovery] [$checkType] Attempting to access room engine stats...');
              
              // For now, we use heuristics since direct stats access may not be available:
              // 1. Track is published and not muted (already checked)
              // 2. Connection is established (already checked)
              // 3. Track state is valid (checked above)
              // 4. Track has been published for a reasonable time (heuristic)
              
              // If track is valid and not muted, assume audio data is present
              // We'll track consecutive failures to detect persistent issues
              hasAudioData = trackStateValid && !audioTrackPublication.muted;
              
              _logger.debug(
                '🔍 [Microphone Recovery] [$checkType] Audio data transmission check: hasAudioData=$hasAudioData '
                '(heuristic: trackStateValid=$trackStateValid, muted=${audioTrackPublication.muted})',
              );
              
              // Log that we're using heuristic method
              if (!hasAudioData) {
                _logger.warn(
                  '⚠️ [Microphone Recovery] [$checkType] Heuristic check indicates no audio data: '
                  'trackStateValid=$trackStateValid, muted=${audioTrackPublication.muted}',
                );
              }
            } catch (statsError) {
              _logger.debug(
                '🔍 [Microphone Recovery] [$checkType] Direct stats access not available: $statsError '
                '(this is expected if SDK doesn\'t expose engine.stats)',
              );
              // Fallback to heuristic
              hasAudioData = trackStateValid && !audioTrackPublication.muted;
            }
          }
        } catch (e) {
          _logger.debug('🔍 [Microphone Recovery] [$checkType] WebRTC stats check error: $e');
          // If stats check fails, use heuristic
          hasAudioData = trackStateValid && !audioTrackPublication.muted;
        }
        
        // Track consecutive checks with no audio data
        if (!hasAudioData) {
          _consecutiveNoAudioChecks++;
          _logger.warn(
            '⚠️ [Microphone Recovery] [$checkType] No audio data detected (check #$_consecutiveNoAudioChecks/$_maxConsecutiveNoAudioChecks)',
          );
        } else {
          // Reset counter if audio data is detected
          if (_consecutiveNoAudioChecks > 0) {
            _logger.info(
              '✅ [Microphone Recovery] [$checkType] Audio data detected again, resetting failure counter '
              '(was at $_consecutiveNoAudioChecks)',
            );
            _consecutiveNoAudioChecks = 0;
          }
        }
        
        // Additional check: If track is published but local user hasn't been detected as speaking for a long time
        // This indicates the track might be published but not actually sending audio
        bool noSpeakingDetected = false;
        if (_lastLocalUserSpeakingTime == null) {
          // Never detected as speaking - check how long track has been published
          if (_audioTrackPublishedTime != null) {
            final timeSincePublish = DateTime.now().difference(_audioTrackPublishedTime!);
            _logger.debug(
              '🔍 [Microphone Recovery] [$checkType] Local user never detected as speaking since track published '
              '(track published ${timeSincePublish.inSeconds}s ago)',
            );
            // If track has been published for more than threshold, trigger recovery
            if (timeSincePublish > _maxTimeWithoutSpeaking) {
              noSpeakingDetected = true;
              _logger.warn(
                '⚠️ [Microphone Recovery] [$checkType] Track published for ${timeSincePublish.inSeconds}s but no speaking detected '
                '(threshold: ${_maxTimeWithoutSpeaking.inSeconds}s). Track is published but may not be sending audio.',
              );
            }
          } else {
            // Track publish time not tracked yet (just published or reset)
            _logger.debug(
              '🔍 [Microphone Recovery] [$checkType] Local user never detected as speaking since track published '
              '(track publish time not available yet)',
            );
            noSpeakingDetected = false;
          }
        } else {
          final timeSinceLastSpeaking = DateTime.now().difference(_lastLocalUserSpeakingTime!);
          if (timeSinceLastSpeaking > _maxTimeWithoutSpeaking) {
            noSpeakingDetected = true;
            _logger.warn(
              '⚠️ [Microphone Recovery] [$checkType] Local user not detected as speaking for ${timeSinceLastSpeaking.inSeconds}s '
              '(threshold: ${_maxTimeWithoutSpeaking.inSeconds}s). Track is published but may not be sending audio.',
            );
          } else {
            _logger.debug(
              '🔍 [Microphone Recovery] [$checkType] Local user last detected as speaking ${timeSinceLastSpeaking.inSeconds}s ago',
            );
          }
        }
        
        // If track state is invalid or we suspect no audio data, try recovery
        // Only trigger aggressive recovery if we've had consecutive failures
        bool shouldRecover = false;
        String recoveryReason = '';
        
        if (!trackStateValid) {
          shouldRecover = true;
          recoveryReason = 'track state invalid';
        } else if (!hasAudioData && _consecutiveNoAudioChecks >= _maxConsecutiveNoAudioChecks) {
          shouldRecover = true;
          recoveryReason = 'no audio data detected for $_consecutiveNoAudioChecks consecutive checks';
        } else if (noSpeakingDetected && hasPublishedAudioTrack) {
          // Track is published but user hasn't been detected as speaking for a long time
          // This is a strong indicator that track is not actually sending audio
          shouldRecover = true;
          recoveryReason = 'track published but no speaking detected for ${_maxTimeWithoutSpeaking.inSeconds}s';
        }
        
        if (shouldRecover) {
          _logger.warn(
            '⚠️ [Microphone Recovery] [$checkType] Recovery triggered: $recoveryReason '
            '(trackStateValid=$trackStateValid, hasAudioData=$hasAudioData, consecutiveFailures=$_consecutiveNoAudioChecks). '
            'Attempting aggressive recovery...',
          );
          
          // Check permission before recovery
          final hasPermission = await _permissionService.isMicrophoneGranted();
          if (!hasPermission) {
            _logger.warn(
              '⚠️ [Microphone Recovery] [$checkType] Recovery needed but microphone permission not granted. Requesting...',
            );
            final granted = await _permissionService.requestMicrophonePermission();
            if (!granted) {
              _logger.error(
                '❌ [Microphone Recovery] [$checkType] Cannot recover: Microphone permission denied',
              );
              return;
            }
            _logger.info('✅ [Microphone Recovery] [$checkType] Microphone permission granted, proceeding with recovery');
          }
          
          // Aggressive recovery: disable and re-enable microphone
          try {
            _logger.debug('🔍 [Microphone Recovery] [$checkType] Step 1: Disabling microphone...');
            await localParticipant.setMicrophoneEnabled(false);
            await Future.delayed(const Duration(milliseconds: 200));
            
            _logger.debug('🔍 [Microphone Recovery] [$checkType] Step 2: Re-enabling microphone...');
            await localParticipant.setMicrophoneEnabled(true);
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Step 3: Verify and fix mediaStreamTrack.enabled property
            await Future.delayed(const Duration(milliseconds: 300), () async {
              try {
                final allTracks = localParticipant.trackPublications.values;
                for (final trackPub in allTracks) {
                  final kindString = trackPub.kind.toString().toLowerCase();
                  if (kindString.contains('audio') && trackPub.track != null) {
                    final audioTrack = trackPub.track;
                    if (audioTrack is LocalAudioTrack) {
                      try {
                        final trackDynamic = audioTrack as dynamic;
                        if (trackDynamic.mediaStreamTrack != null) {
                          final mediaStreamTrack = trackDynamic.mediaStreamTrack as dynamic;
                          if (mediaStreamTrack.enabled != null) {
                            final isEnabled = mediaStreamTrack.enabled as bool;
                            if (!isEnabled) {
                              _logger.warn(
                                '⚠️ [Microphone Recovery] [$checkType] mediaStreamTrack.enabled is false after recovery! Setting to true...',
                              );
                              mediaStreamTrack.enabled = true;
                              _logger.info(
                                '✅ [Microphone Recovery] [$checkType] Set mediaStreamTrack.enabled = true after recovery',
                              );
                            }
                          }
                        }
                      } catch (e) {
                        _logger.debug(
                          '🔍 [Microphone Recovery] [$checkType] Cannot access mediaStreamTrack: $e',
                        );
                      }
                    }
                  }
                }
              } catch (e) {
                _logger.debug('🔍 [Microphone Recovery] [$checkType] Error checking mediaStreamTrack: $e');
              }
            });
            
            _logger.info('✅ [Microphone Recovery] [$checkType] Aggressive recovery completed (disable/enable cycle)');
            
            // Reset failure counter after recovery attempt
            _consecutiveNoAudioChecks = 0;
            _lastLocalUserSpeakingTime = null; // Reset speaking detection time to allow fresh detection
            _audioTrackPublishedTime = null; // Reset track publish time (new track will be published)
            
            // Re-check track after recovery
            final recheckTracks = localParticipant.trackPublications.values;
            final recheckHasTrack = recheckTracks.any((trackPub) {
              final kindString = trackPub.kind.toString().toLowerCase();
              return kindString.contains('audio') && trackPub.track != null;
            });
            
            if (recheckHasTrack) {
              final recheckMuted = recheckTracks.any((trackPub) {
                final kindString = trackPub.kind.toString().toLowerCase();
                return kindString.contains('audio') && trackPub.track != null && trackPub.muted;
              });
              _logger.debug(
                '✅ [Microphone Recovery] [$checkType] Track re-published after recovery: '
                'hasTrack=$recheckHasTrack, muted=$recheckMuted',
              );
            } else {
              _logger.warn('⚠️ [Microphone Recovery] [$checkType] Track not re-published after recovery');
            }
          } catch (e) {
            _logger.error('❌ [Microphone Recovery] [$checkType] Aggressive recovery failed: $e');
            // Don't reset counter on error, so we can try again
          }
        } else if (hasAudioData && trackStateValid) {
          _logger.debug(
            '✅ [Microphone Recovery] [$checkType] Track state and audio data checks passed '
            '(trackStateValid=$trackStateValid, hasAudioData=$hasAudioData, consecutiveFailures=$_consecutiveNoAudioChecks)',
          );
        } else {
          _logger.debug(
            '🔍 [Microphone Recovery] [$checkType] Monitoring: trackStateValid=$trackStateValid, '
            'hasAudioData=$hasAudioData, consecutiveFailures=$_consecutiveNoAudioChecks/$_maxConsecutiveNoAudioChecks '
            '(will recover after $_maxConsecutiveNoAudioChecks consecutive failures)',
          );
        }
      } else {
        _logger.warn('⚠️ [Microphone Recovery] [$checkType] Audio track publication exists but track is null');
      }
    }

    // Check if track is muted (unexpectedly)
    final mutedAudioTracks = allTracks.where((trackPub) {
      final kindString = trackPub.kind.toString().toLowerCase();
      return kindString.contains('audio') &&
          trackPub.track != null &&
          trackPub.muted;
    });

    _logger.debug('🔍 [Microphone Recovery] [$checkType] Muted audio tracks count: ${mutedAudioTracks.length}');

    if (mutedAudioTracks.isNotEmpty) {
      _logger.warn(
        '⚠️ [Microphone Recovery] [$checkType] Local audio track is muted, re-enabling microphone...',
      );
      try {
        await localParticipant.setMicrophoneEnabled(true);
        _logger.info(
          '✅ [Microphone Recovery] Microphone re-enabled after track mute',
        );
      } catch (e) {
        _logger.error(
          '❌ [Microphone Recovery] Failed to re-enable microphone: $e',
        );
      }
    } else {
      _logger.debug('✅ [Microphone Recovery] [$checkType] All checks passed - microphone is enabled and track is active');
    }
  }

  /// Start periodic microphone state monitoring
  void _startPeriodicMicrophoneCheck() {
    // Stop any existing timer first
    _stopPeriodicMicrophoneCheck();

    _logger.debug('🔄 [Microphone Recovery] Starting periodic microphone check (every 2 seconds)');

    _periodicMicrophoneCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        // Only check if we're still connected
        if (isConnected && _room?.localParticipant != null) {
          ensureMicrophoneEnabled(isPeriodicCheck: true).catchError((e) {
            _logger.error('❌ [Microphone Recovery] Periodic check error: $e');
          });
        } else {
          // Stop timer if we're no longer connected
          _logger.debug('🔄 [Microphone Recovery] Stopping periodic check - not connected');
          _stopPeriodicMicrophoneCheck();
        }
      },
    );
  }

  /// Stop periodic microphone state monitoring
  void _stopPeriodicMicrophoneCheck() {
    if (_periodicMicrophoneCheckTimer != null) {
      _periodicMicrophoneCheckTimer!.cancel();
      _periodicMicrophoneCheckTimer = null;
      _logger.debug('🔄 [Microphone Recovery] Stopped periodic microphone check');
    }
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

  /// Ensure local microphone is enabled and actively capturing audio
  /// Uses aggressive approach: disable -> enable cycle + mediaStreamTrack.enabled check
  Future<void> _ensureLocalMicrophoneEnabled() async {
    try {
      if (_room?.localParticipant == null) {
        _logger.warn('⚠️ [Local Microphone] Cannot ensure microphone enabled: local participant is null');
        return;
      }

      final localParticipant = _room!.localParticipant!;
      
      _logger.debug('🔍 [Local Microphone] Starting aggressive microphone enable process...');
      
      // Step 1: Disable microphone first
      try {
        await localParticipant.setMicrophoneEnabled(false);
        _logger.debug('🔍 [Local Microphone] Step 1: Microphone disabled');
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        _logger.debug('🔍 [Local Microphone] Step 1 disable result: $e (continuing...)');
      }
      
      // Step 2: Enable microphone
      await localParticipant.setMicrophoneEnabled(true);
      _logger.debug('🔍 [Local Microphone] Step 2: Microphone enabled');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 3: Verify track is published and check mediaStreamTrack.enabled
      await Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          final allTracks = localParticipant.trackPublications.values;
          for (final trackPub in allTracks) {
            final kindString = trackPub.kind.toString().toLowerCase();
            if (kindString.contains('audio') && trackPub.track != null) {
              final audioTrack = trackPub.track;
              if (audioTrack is LocalAudioTrack) {
                _logger.debug(
                  '🔍 [Local Microphone] Found LocalAudioTrack: name=${trackPub.name}, muted=${trackPub.muted}',
                );
                
                // Try to access mediaStreamTrack.enabled property
                try {
                  final trackDynamic = audioTrack as dynamic;
                  if (trackDynamic.mediaStreamTrack != null) {
                    final mediaStreamTrack = trackDynamic.mediaStreamTrack as dynamic;
                    if (mediaStreamTrack.enabled != null) {
                      final isEnabled = mediaStreamTrack.enabled as bool;
                      _logger.debug(
                        '🔍 [Local Microphone] mediaStreamTrack.enabled: $isEnabled',
                      );
                      if (!isEnabled) {
                        _logger.warn(
                          '⚠️ [Local Microphone] mediaStreamTrack.enabled is false! Setting to true...',
                        );
                        mediaStreamTrack.enabled = true;
                        _logger.info(
                          '✅ [Local Microphone] Set mediaStreamTrack.enabled = true',
                        );
                      } else {
                        _logger.info(
                          '✅ [Local Microphone] mediaStreamTrack.enabled is already true',
                        );
                      }
                    }
                  }
                } catch (e) {
                  _logger.debug(
                    '🔍 [Local Microphone] Cannot access mediaStreamTrack directly: $e',
                  );
                }
              }
            }
          }
        } catch (e) {
          _logger.warn('⚠️ [Local Microphone] Error verifying track state: $e');
        }
      });
      
      _logger.info('✅ [Local Microphone] Aggressive microphone enable completed');
    } catch (e) {
      _logger.error('❌ [Local Microphone] Failed to ensure microphone enabled: $e');
      rethrow;
    }
  }

  /// Ensure remote audio track is enabled for playback
  /// This method uses multiple approaches to ensure track is properly activated:
  /// 1. Standard enable() method
  /// 2. Force re-enable (disable -> enable) for Android audio routing issues
  /// 3. Multiple enable attempts with delays to handle Android 11+ audio mode reset
  Future<void> _ensureRemoteAudioTrackEnabled(RemoteAudioTrack track) async {
    try {
      _logger.debug(
        '🔍 [Remote Audio] Checking remote audio track state: '
        'track=${track.runtimeType}',
      );

      // Method 1: Try to access mediaStreamTrack.enabled property directly (if available)
      // This is a more reliable way to control track state on Android
      try {
        // Try to access mediaStreamTrack property via dynamic access
        // LiveKit SDK may expose this property internally
        final trackDynamic = track as dynamic;
        if (trackDynamic.mediaStreamTrack != null) {
          final mediaStreamTrack = trackDynamic.mediaStreamTrack as dynamic;
          if (mediaStreamTrack.enabled != null) {
            _logger.debug(
              '🔍 [Remote Audio] Found mediaStreamTrack.enabled property: ${mediaStreamTrack.enabled}',
            );
            // Ensure it's enabled
            if (mediaStreamTrack.enabled == false) {
              mediaStreamTrack.enabled = true;
              _logger.debug('🔍 [Remote Audio] Set mediaStreamTrack.enabled = true');
            }
          }
        }
      } catch (e) {
        _logger.debug(
          '🔍 [Remote Audio] Cannot access mediaStreamTrack directly (expected): $e',
        );
      }

      // Method 2: Aggressive enable approach - multiple enable/disable cycles
      // This helps with Android 11+ audio mode reset issues
      _logger.debug('🔍 [Remote Audio] Method 2: Aggressive enable (multiple cycles)');
      
      // First cycle: disable -> enable
      try {
        await track.disable();
        _logger.debug('🔍 [Remote Audio] Cycle 1: Track disabled');
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (disableError) {
        _logger.debug('🔍 [Remote Audio] Cycle 1 disable result: $disableError (continuing...)');
      }
      
      await track.enable();
      _logger.debug('🔍 [Remote Audio] Cycle 1: Track enabled');
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Second cycle: Another disable -> enable for Android audio routing
      try {
        await track.disable();
        _logger.debug('🔍 [Remote Audio] Cycle 2: Track disabled');
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (disableError) {
        _logger.debug('🔍 [Remote Audio] Cycle 2 disable result: $disableError (continuing...)');
      }
      
      await track.enable();
      _logger.debug('🔍 [Remote Audio] Cycle 2: Track enabled');
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Final enable to ensure track is active
      await track.enable();
      _logger.debug('🔍 [Remote Audio] Final enable call completed');
      await Future.delayed(const Duration(milliseconds: 200));
      
      _logger.info(
        '✅ [Remote Audio] Remote audio track enabled for playback (aggressive enable completed)',
      );
    } catch (e) {
      _logger.error(
        '❌ [Remote Audio] Failed to enable remote audio track: $e',
      );
      rethrow;
    }
  }

  /// Setup local participant listener for SpeakingChangedEvent
  void _setupLocalParticipantListener() {
    // Dispose existing listener if any
    _localParticipantListener?.dispose();
    _localParticipantListener = null;
    
    if (_room?.localParticipant == null) {
      _logger.debug('🔍 [Microphone Recovery] Cannot setup local participant listener: local participant is null');
      return;
    }
    
    try {
      _localParticipantListener = _room!.localParticipant!.createListener();
      _localParticipantListener!.on<SpeakingChangedEvent>((event) {
        if (event.speaking) {
          _lastLocalUserSpeakingTime = DateTime.now();
          _logger.debug('🔍 [Microphone Recovery] [LocalParticipant] Local user detected as speaking via SpeakingChangedEvent');
        }
      });
      _logger.debug('🔍 [Microphone Recovery] Local participant listener setup successfully');
    } catch (e) {
      _logger.warn('⚠️ [Microphone Recovery] Failed to setup local participant listener: $e');
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
        _logger.error(
          '❌ [VoiceService] Room disconnected: ${event.reason} - emitting to stream',
        );
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
        // Setup local participant listener after reconnection
        _setupLocalParticipantListener();
        // Re-configure audio routing after reconnection
        Future.delayed(const Duration(milliseconds: 300), () async {
          try {
            await _room?.setSpeakerOn(true);
            _logger.info('✅ [Audio Routing] Speaker re-enabled after reconnection');
          } catch (e) {
            _logger.warn('⚠️ [Audio Routing] Failed to set speaker on after reconnection: $e');
          }
        });
        // Re-ensure microphone after reconnection
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (_room?.localParticipant != null) {
            await ensureMicrophoneEnabled(isPeriodicCheck: false);
          }
        });
        // Re-enable all remote audio tracks after reconnection
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (_room != null && !_isDeafened) {
            _logger.debug('🔍 [Remote Audio] Re-enabling remote audio tracks after reconnection');
            final remoteParticipants = _room!.remoteParticipants.values;
            for (final participant in remoteParticipants) {
              for (final trackPub in participant.audioTrackPublications) {
                final kindString = trackPub.kind.toString().toLowerCase();
                if (kindString.contains('audio') && 
                    trackPub.subscribed && 
                    trackPub.track != null) {
                  final audioTrack = trackPub.track;
                  if (audioTrack is RemoteAudioTrack) {
                    try {
                      await _ensureRemoteAudioTrackEnabled(audioTrack);
                    } catch (e) {
                      _logger.error(
                        '❌ [Remote Audio] Failed to re-enable audio track for '
                        '${participant.name} after reconnection: $e',
                      );
                    }
                  }
                }
              }
            }
          }
        });
        // Restart periodic check after reconnection
        _startPeriodicMicrophoneCheck();
      })
      // Participant events
      ..on<ParticipantConnectedEvent>((event) {
        _logger.debug('Participant connected: ${event.participant.name}');
        _participantConnectedController.add(event.participant);
        
        // Check and enable existing remote audio tracks for this participant
        // Only process remote participants (skip local participant)
        if (event.participant is! LocalParticipant) {
          final participant = event.participant;
          _logger.debug(
            '🔍 [Remote Audio] Checking audio tracks for remote participant: '
            '${participant.name} (identity: ${participant.identity})',
          );
          
          // Check existing audio track publications
          for (final trackPub in participant.audioTrackPublications) {
            final kindString = trackPub.kind.toString().toLowerCase();
            if (kindString.contains('audio')) {
              _logger.debug(
                '🔍 [Remote Audio] Found audio track publication: '
                'name=${trackPub.name}, subscribed=${trackPub.subscribed}, '
                'track=${trackPub.track != null ? trackPub.track.runtimeType : "null"}',
              );
              
              // If track is subscribed, ensure it's enabled
              if (trackPub.subscribed && trackPub.track != null) {
                final audioTrack = trackPub.track;
                if (audioTrack is RemoteAudioTrack) {
                  // Add delay to ensure track is fully initialized
                  Future.delayed(const Duration(milliseconds: 300), () async {
                    if (!_isDeafened) {
                      try {
                        await _ensureRemoteAudioTrackEnabled(audioTrack);
                      } catch (e) {
                        _logger.error(
                          '❌ [Remote Audio] Failed to enable audio track for '
                          '${participant.name}: $e',
                        );
                      }
                    } else {
                      _logger.debug(
                        '🔍 [Remote Audio] Track not enabled (user is deafened)',
                      );
                    }
                  });
                }
              } else if (!trackPub.subscribed) {
                _logger.debug(
                  '🔍 [Remote Audio] Audio track not yet subscribed for '
                  '${participant.name}, will enable when subscribed',
                );
              }
            }
          }
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _logger.debug('Participant disconnected: ${event.participant.name}');
        _participantDisconnectedController.add(event.participant);
      })
      // Local track published event
      ..on<LocalTrackPublishedEvent>((event) {
        _logger.debug(
          'Local track published: ${event.publication.name} (kind: ${event.publication.kind})',
        );
        final kindString = event.publication.kind.toString().toLowerCase();
        if (kindString.contains('audio')) {
          _logger.info('✅ [Local Track] Audio track published successfully');
          // Track publish time for recovery checks
          _audioTrackPublishedTime = DateTime.now();
          _logger.debug('🔍 [Microphone Recovery] Audio track published at ${_audioTrackPublishedTime!.toIso8601String()}');
          // Verify track is active
          if (event.publication.track != null && !event.publication.muted) {
            _logger.info('✅ [Local Track] Audio track is active and unmuted');
          } else if (event.publication.muted) {
            _logger.warn(
              '⚠️ [Local Track] Audio track is muted, attempting to unmute...',
            );
            // Try to unmute
            Future.delayed(const Duration(milliseconds: 100), () async {
              if (_room?.localParticipant != null) {
                await _room!.localParticipant!.setMicrophoneEnabled(true);
              }
            });
          }
        }
      })
      // Local track unpublished event
      ..on<LocalTrackUnpublishedEvent>((event) {
        _logger.warn(
          '⚠️ [Local Track] Local track unpublished: ${event.publication.name} (kind: ${event.publication.kind})',
        );
        final kindString = event.publication.kind.toString().toLowerCase();
        if (kindString.contains('audio')) {
          _logger.warn(
            '⚠️ [Local Track] Audio track unpublished unexpectedly - attempting recovery...',
          );
          // Reset track publish time
          _audioTrackPublishedTime = null;
          // Immediately try to re-enable microphone
          Future.delayed(const Duration(milliseconds: 100), () async {
            if (_room?.localParticipant != null) {
              await ensureMicrophoneEnabled(isPeriodicCheck: false);
            }
          });
        }
      })
      // Active speakers
      ..on<ActiveSpeakersChangedEvent>((event) {
        final speakingMap = <String, bool>{};
        final localParticipant = _room?.localParticipant;
        
        // Debug: Log local participant info for debugging
        if (localParticipant != null) {
          _logger.debug(
            '🔍 [Microphone Recovery] [ActiveSpeakers] Local participant: '
            'identity="${localParticipant.identity}", sid="${localParticipant.sid}", name="${localParticipant.name}"',
          );
        } else {
          _logger.debug('🔍 [Microphone Recovery] [ActiveSpeakers] Local participant is null');
        }
        
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
            
            // Check if this is the local user
            if (localParticipant != null) {
              final identityMatch = speaker.identity == localParticipant.identity;
              final sidMatch = speaker.sid == localParticipant.sid;
              
              _logger.debug(
                '🔍 [Microphone Recovery] [ActiveSpeakers] Comparing speaker with local: '
                'speaker.identity="${speaker.identity}" == local.identity="${localParticipant.identity}"? $identityMatch, '
                'speaker.sid="${speaker.sid}" == local.sid="${localParticipant.sid}"? $sidMatch',
              );
              
              if (identityMatch || sidMatch) {
                _lastLocalUserSpeakingTime = DateTime.now();
                _logger.debug('🔍 [Microphone Recovery] Local user detected as speaking');
              }
            }
          }
        }
        
        _speakingChangedController.add(speakingMap);
        _logger.debug(
          'Active speakers: ${event.speakers.length} (userIds: ${speakingMap.keys.toList()})',
        );
      })
      // Track mute events (for all participants including local)
      ..on<TrackMutedEvent>((event) {
        _logger.debug('Track muted: ${event.participant.name}');

        // Check if this is a local participant track
        if (event.participant is LocalParticipant) {
          final kindString = event.publication.kind.toString().toLowerCase();
          if (kindString.contains('audio')) {
            _logger.warn(
              '⚠️ [Local Track] Local audio track muted unexpectedly - attempting recovery...',
            );
            // Immediately try to re-enable microphone
            Future.delayed(const Duration(milliseconds: 100), () async {
              if (_room?.localParticipant != null) {
                await ensureMicrophoneEnabled();
              }
            });
          }
        }

        _trackMutedController.add(
          TrackMutedEvent(event.publication, event.participant, true),
        );
      })
      ..on<TrackUnmutedEvent>((event) {
        _logger.debug('Track unmuted: ${event.participant.name}');
        _trackMutedController.add(
          TrackMutedEvent(event.publication, event.participant, false),
        );
      })
      // Remote track published event
      ..on<TrackPublishedEvent>((event) {
        // Only handle remote participant tracks (local tracks are handled separately)
        if (event.participant is! LocalParticipant) {
          final participant = event.participant;
          final kindString = event.publication.kind.toString().toLowerCase();
          
          _logger.debug(
            '🔍 [Remote Audio] Track published: participant=${participant.name}, '
            'name=${event.publication.name}, kind=$kindString',
          );
          
          if (kindString.contains('audio')) {
            _logger.info(
              '✅ [Remote Audio] Remote audio track published: '
              '${event.publication.name} by ${participant.name}',
            );
            
            // Track will be auto-subscribed by LiveKit SDK by default
            // We'll handle enabling in TrackSubscribedEvent
            _logger.debug(
              '🔍 [Remote Audio] Waiting for track subscription (auto-subscribe enabled by default)',
            );
          }
        }
      })
      // Remote track subscribed event
      ..on<TrackSubscribedEvent>((event) {
        // Only handle remote participant tracks
        if (event.participant is! LocalParticipant) {
          final participant = event.participant;
          final kindString = event.publication.kind.toString().toLowerCase();
          
          _logger.debug(
            '🔍 [Remote Audio] Track subscribed: participant=${participant.name}, '
            'name=${event.publication.name}, kind=$kindString',
          );
          
          if (kindString.contains('audio')) {
            final audioTrack = event.track;
            if (audioTrack is RemoteAudioTrack) {
              _logger.info(
                '✅ [Remote Audio] Remote audio track subscribed: '
                '${event.publication.name} by ${participant.name}',
              );
              
              // Log track publication details
              _logger.debug(
                '🔍 [Remote Audio] Track publication details: '
                'muted=${event.publication.muted}, subscribed=${event.publication.subscribed}, '
                'track=${event.publication.track != null ? event.publication.track.runtimeType : "null"}',
              );
              
              // Log track state before enable
              _logger.debug(
                '🔍 [Remote Audio] Track state before enable: '
                'trackType=${audioTrack.runtimeType}, '
                'participant=${participant.name}, '
                'isDeafened=$_isDeafened',
              );
              
              // Ensure track is enabled for playback (unless deafened)
              if (!_isDeafened) {
                // Add a small delay to ensure track is fully initialized
                // Increased delay to 500ms for Android audio routing
                Future.delayed(const Duration(milliseconds: 500), () async {
                  try {
                    _logger.debug(
                      '🔍 [Remote Audio] Starting enable process for track from ${participant.name}',
                    );
                    
                    // Ensure audio routing is set to speaker before enabling track
                    try {
                      await _room?.setSpeakerOn(true);
                      _logger.debug('🔍 [Remote Audio] Audio routing set to speaker');
                    } catch (e) {
                      _logger.debug('🔍 [Remote Audio] Could not set speaker on: $e (continuing...)');
                    }
                    
                    await _ensureRemoteAudioTrackEnabled(audioTrack);
                    
                    // Verify track is still available after enable
                    if (event.publication.track != null) {
                      _logger.debug(
                        '✅ [Remote Audio] Track verified after enable: '
                        'track=${event.publication.track.runtimeType}, '
                        'muted=${event.publication.muted}, '
                        'subscribed=${event.publication.subscribed}',
                      );
                    } else {
                      _logger.warn(
                        '⚠️ [Remote Audio] Track is null after enable - may need retry',
                      );
                    }
                    
                    // Additional verification: check if track is still subscribed
                    if (event.publication.subscribed) {
                      _logger.debug(
                        '✅ [Remote Audio] Track subscription verified: still subscribed',
                      );
                    } else {
                      _logger.warn(
                        '⚠️ [Remote Audio] Track subscription lost after enable',
                      );
                    }
                  } catch (e) {
                    _logger.error(
                      '❌ [Remote Audio] Failed to enable audio track for '
                      '${participant.name}: $e',
                    );
                    // Retry once after a longer delay
                    Future.delayed(const Duration(milliseconds: 1000), () async {
                      try {
                        _logger.debug(
                          '🔍 [Remote Audio] Retrying enable for ${participant.name}...',
                        );
                        await _ensureRemoteAudioTrackEnabled(audioTrack);
                        _logger.info(
                          '✅ [Remote Audio] Track enabled successfully on retry for ${participant.name}',
                        );
                      } catch (retryError) {
                        _logger.error(
                          '❌ [Remote Audio] Retry failed for ${participant.name}: $retryError',
                        );
                      }
                    });
                  }
                });
              } else {
                _logger.debug(
                  '🔍 [Remote Audio] Track not enabled (user is deafened)',
                );
              }
            } else {
              _logger.warn(
                '⚠️ [Remote Audio] Subscribed track is not RemoteAudioTrack: '
                '${audioTrack.runtimeType}',
              );
            }
          }
        }
      })
      // Remote track unsubscribed event (for logging)
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.participant is! LocalParticipant) {
          final participant = event.participant;
          final kindString = event.publication.kind.toString().toLowerCase();
          
          if (kindString.contains('audio')) {
            _logger.debug(
              '🔍 [Remote Audio] Remote audio track unsubscribed: '
              '${event.publication.name} by ${participant.name}',
            );
          }
        }
      });
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Stop periodic check timer
    _stopPeriodicMicrophoneCheck();
    // Dispose local participant listener
    _localParticipantListener?.dispose();
    _localParticipantListener = null;
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
