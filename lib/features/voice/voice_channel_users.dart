import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/voice/voice_participant_dto.dart';

/// Voice channel participants list widget
class VoiceChannelUsers extends ConsumerWidget {
  final String channelId;
  final String channelName;

  const VoiceChannelUsers({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceProvider);
    final authState = ref.watch(authProvider);

    // Only show if this is the active voice channel
    if (voiceState.activeChannelId != channelId) {
      return const SizedBox.shrink();
    }

    final participants = voiceState.participants;
    final currentUserId = authState.user?.id;

    if (participants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '🔊 $channelName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No one in voice channel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.volume_up,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '$channelName (${participants.length})',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1F2023)),
          
          // Participants list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final participant = participants[index];
              final isCurrentUser = participant.userId == currentUserId;
              
              return _buildParticipantItem(
                participant: participant,
                isCurrentUser: isCurrentUser,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItem({
    required VoiceParticipantDto participant,
    required bool isCurrentUser,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // Speaking indicator - animated green border
        border: participant.isSpeaking
            ? Border.all(
                color: const Color(0xFF23A559),
                width: 2,
              )
            : null,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: participant.isSpeaking
                  ? const Color(0xFF23A559)
                  : const Color(0xFF5865F2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              participant.username.isNotEmpty
                  ? participant.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.displayName ?? participant.username,
                        style: TextStyle(
                          color: participant.isSpeaking
                              ? const Color(0xFF23A559)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: participant.isSpeaking
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5865F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'you',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Status icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (participant.isMuted)
                const Icon(
                  Icons.mic_off,
                  size: 16,
                  color: Colors.red,
                ),
              if (participant.isDeafened) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.headset_off,
                  size: 16,
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
