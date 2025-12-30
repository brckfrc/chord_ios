import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/guild_provider.dart';
import '../../models/guild/channel_dto.dart';

/// Voice connection status bar (bottom bar when in voice channel)
class VoiceBar extends ConsumerWidget {
  const VoiceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceProvider);
    final channelState = ref.watch(channelProvider);
    final guildState = ref.watch(guildProvider);

    // Don't show if not in a voice channel
    if (voiceState.activeChannelId == null) {
      return const SizedBox.shrink();
    }

    // Get channel name from current guild's channels
    ChannelDto? channel;
    if (guildState.selectedGuildId != null) {
      final guildChannels = channelState.getChannelsForGuild(guildState.selectedGuildId!);
      channel = guildChannels
          .where((c) => c.id == voiceState.activeChannelId)
          .firstOrNull;
    }

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF232428), // Darker gray
        border: Border(
          top: BorderSide(
            color: const Color(0xFF1F2023),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Voice icon + channel name
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: voiceState.isSpeaking
                        ? const Color(0xFF23A559) // Green when speaking
                        : const Color(0xFF35373C),
                    shape: BoxShape.circle,
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
                        channel?.name ?? 'Voice Channel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        voiceState.isConnecting
                            ? 'Connecting...'
                            : voiceState.isConnected
                                ? 'Connected'
                                : 'Disconnected',
                        style: TextStyle(
                          color: voiceState.isConnected
                              ? const Color(0xFF23A559)
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute button
              _buildControlButton(
                icon: voiceState.isMuted
                    ? Icons.mic_off
                    : Icons.mic,
                isActive: !voiceState.isMuted,
                onPressed: () {
                  ref.read(voiceProvider.notifier).toggleMute();
                },
                tooltip: voiceState.isMuted ? 'Unmute' : 'Mute',
              ),
              const SizedBox(width: 8),
              
              // Deafen button
              _buildControlButton(
                icon: voiceState.isDeafened
                    ? Icons.headset_off
                    : Icons.headset,
                isActive: !voiceState.isDeafened,
                onPressed: () {
                  ref.read(voiceProvider.notifier).toggleDeafen();
                },
                tooltip: voiceState.isDeafened ? 'Undeafen' : 'Deafen',
              ),
              const SizedBox(width: 8),
              
              // Disconnect button
              _buildControlButton(
                icon: Icons.call_end,
                isActive: false,
                onPressed: () async {
                  await ref.read(voiceProvider.notifier).leaveVoiceChannel();
                },
                tooltip: 'Disconnect',
                isDanger: true,
              ),
            ],
          ),
        ],
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
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDanger
                  ? const Color(0xFFED4245).withOpacity(0.1)
                  : isActive
                      ? const Color(0xFF23A559).withOpacity(0.1)
                      : const Color(0xFF35373C),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDanger
                  ? const Color(0xFFED4245)
                  : isActive
                      ? const Color(0xFF23A559)
                      : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
