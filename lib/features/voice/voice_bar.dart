import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../shared/widgets/app_toast.dart';
import 'voice_room_view.dart';

/// Voice connection status bar (bottom bar when in voice channel)
class VoiceBar extends ConsumerWidget {
  const VoiceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceProvider);

    // Don't show if not in a voice channel
    if (voiceState.activeChannelId == null) {
      return const SizedBox.shrink();
    }

    // SafeArea removed - child layouts already have SafeArea, double padding was causing extra space
    // Add minimal bottom padding for iOS app switcher bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final minimalBottomPadding = bottomPadding > 0 ? bottomPadding.clamp(0.0, 8.0) : 4.0;
    
    return Padding(
      padding: EdgeInsets.only(bottom: minimalBottomPadding),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF232428), // Darker gray
          border: Border(
            top: BorderSide(color: const Color(0xFF1F2023), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Voice icon + channel name (tappable to open room view)
          Expanded(
            child: GestureDetector(
              onTap: voiceState.isConnected
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const VoiceRoomView(),
                        ),
                      );
                    }
                  : null,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: voiceState.isSpeaking
                          ? const Color(0xFF23A559) // Green when speaking
                          : const Color(0xFF35373C),
                      shape: BoxShape.circle,
                      // Glow effect when speaking
                      boxShadow: voiceState.isSpeaking
                          ? [
                              BoxShadow(
                                color: const Color(0xFF23A559).withOpacity(0.6),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          voiceState.activeChannelName ?? 'Voice Channel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Connection quality indicator
                            if (voiceState.isConnected && voiceState.error == null)
                              _buildQualityIndicator(voiceState.connectionQuality),
                            Text(
                              voiceState.error != null
                                  ? 'Error: ${voiceState.error}'
                                  : voiceState.isConnecting
                                  ? 'Connecting...'
                                  : voiceState.isConnected
                                  ? 'Connected'
                                  : 'Disconnected',
                              style: TextStyle(
                                color: voiceState.error != null
                                    ? const Color(0xFFED4245)
                                    : voiceState.isConnected
                                    ? const Color(0xFF23A559)
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute button
              _buildControlButton(
                icon: voiceState.isMuted ? Icons.mic_off : Icons.mic,
                isActive: !voiceState.isMuted,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final wasMuted = voiceState.isMuted;
                  ref.read(voiceProvider.notifier).toggleMute();
                  // Show toast notification
                  if (wasMuted) {
                    AppToast.showSuccess(context, 'Unmuted');
                  } else {
                    AppToast.show(context, 'Muted');
                  }
                },
                tooltip: voiceState.isMuted ? 'Unmute' : 'Mute',
              ),
              const SizedBox(width: 8),

              // Deafen button
              _buildControlButton(
                icon: voiceState.isDeafened ? Icons.headset_off : Icons.headset,
                isActive: !voiceState.isDeafened,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  final wasDeafened = voiceState.isDeafened;
                  ref.read(voiceProvider.notifier).toggleDeafen();
                  // Show toast notification
                  if (wasDeafened) {
                    AppToast.showSuccess(context, 'Undeafened');
                  } else {
                    AppToast.show(context, 'Deafened');
                  }
                },
                tooltip: voiceState.isDeafened ? 'Undeafen' : 'Deafen',
              ),
              const SizedBox(width: 8),

              // Disconnect button
              _buildControlButton(
                icon: Icons.call_end,
                isActive: false,
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  await ref.read(voiceProvider.notifier).leaveVoiceChannel();
                },
                tooltip: 'Disconnect',
                isDanger: true,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
    bool isDanger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDanger
                  ? const Color(0xFFED4245).withOpacity(0.1)
                  : isActive
                  ? const Color(0xFF23A559).withOpacity(0.1)
                  : const Color(0xFF35373C),
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                color: isDanger
                    ? const Color(0xFFED4245)
                    : isActive
                    ? const Color(0xFF23A559)
                    : Colors.grey,
              ),
              child: Icon(
                icon,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build connection quality indicator widget
  Widget _buildQualityIndicator(dynamic quality) {
    Color qualityColor;
    switch (quality.toString()) {
      case 'ConnectionQuality.excellent':
        qualityColor = const Color(0xFF23A559); // Green
        break;
      case 'ConnectionQuality.good':
        qualityColor = const Color(0xFF5865F2); // Blue
        break;
      case 'ConnectionQuality.poor':
        qualityColor = const Color(0xFFFAA61A); // Orange
        break;
      default:
        qualityColor = Colors.grey;
    }
    
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: qualityColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
