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

    // Get participants for this channel (works for all channels, not just active)
    final participants = voiceState.getParticipantsForChannel(channelId);
    final currentUserId = authState.user?.id;

    // Compact Discord-like display - no header, just participants list
    if (participants.isEmpty) {
      return const SizedBox.shrink(); // Don't show empty state - keep it clean
    }

    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: participants.map((participant) {
          final isCurrentUser = participant.userId == currentUserId;
          return _buildParticipantItem(
            participant: participant,
            isCurrentUser: isCurrentUser,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildParticipantItem({
    required VoiceParticipantDto participant,
    required bool isCurrentUser,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          // Speaking indicator - green background when speaking
          color: participant.isSpeaking
              ? const Color(0xFF23A559).withOpacity(0.2)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar (smaller, Discord-like)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 26,
              height: 26,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            color: participant.isSpeaking
                                ? const Color(0xFF23A559)
                                : Colors.white.withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: participant.isSpeaking
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          child: Text(
                            participant.displayName ?? participant.username,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  const Icon(Icons.mic_off, size: 19, color: Colors.red),
                if (participant.isDeafened) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.headset_off, size: 19, color: Colors.red),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
