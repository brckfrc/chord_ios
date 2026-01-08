import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/voice/voice_participant_dto.dart';

/// Full-screen voice room view with participants grid
class VoiceRoomView extends ConsumerWidget {
  const VoiceRoomView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    if (voiceState.activeChannelId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Voice Room'),
        ),
        body: const Center(
          child: Text('Not in a voice channel'),
        ),
      );
    }

    final participants = voiceState.participants;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        elevation: 0,
        title: Text(
          voiceState.activeChannelName ?? 'Voice Channel',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: participants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volume_up,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No participants',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                final isCurrentUser = participant.userId == currentUserId;
                return _buildParticipantCard(
                  participant: participant,
                  isCurrentUser: isCurrentUser,
                );
              },
            ),
    );
  }

  Widget _buildParticipantCard({
    required VoiceParticipantDto participant,
    required bool isCurrentUser,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        borderRadius: BorderRadius.circular(12),
        border: participant.isSpeaking
            ? Border.all(
                color: const Color(0xFF23A559),
                width: 2,
              )
            : null,
        boxShadow: participant.isSpeaking
            ? [
                BoxShadow(
                  color: const Color(0xFF23A559).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: participant.isSpeaking
                  ? const Color(0xFF23A559)
                  : const Color(0xFF5865F2),
              shape: BoxShape.circle,
              boxShadow: participant.isSpeaking
                  ? [
                      BoxShadow(
                        color: const Color(0xFF23A559).withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              participant.username.isNotEmpty
                  ? participant.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Username
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          color: participant.isSpeaking
                              ? const Color(0xFF23A559)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: participant.isSpeaking
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        child: Text(
                          participant.displayName ?? participant.username,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCurrentUser) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
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
          ),
          
          const SizedBox(height: 8),
          
          // Status icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (participant.isMuted)
                const Icon(
                  Icons.mic_off,
                  size: 16,
                  color: Colors.red,
                ),
              if (participant.isDeafened) ...[
                if (participant.isMuted) const SizedBox(width: 4),
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
