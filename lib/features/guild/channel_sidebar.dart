import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/guild_provider.dart';
import '../../providers/channel_provider.dart';
import '../../models/guild/channel_dto.dart';
import '../../models/guild/channel_type.dart';
import '../../features/modals/create_channel_modal.dart';
import '../../features/modals/invite_modal.dart';
import '../../shared/widgets/app_loading.dart';

/// Channel sidebar widget
class ChannelSidebar extends ConsumerStatefulWidget {
  const ChannelSidebar({super.key});

  @override
  ConsumerState<ChannelSidebar> createState() => _ChannelSidebarState();
}

class _ChannelSidebarState extends ConsumerState<ChannelSidebar> {
  // Section expanded states
  final Map<String, bool> _sectionExpanded = {
    'TEXT CHANNELS': true,
    'ANNOUNCEMENTS': true,
    'VOICE CHANNELS': true,
  };

  void _toggleSection(String sectionTitle) {
    setState(() {
      _sectionExpanded[sectionTitle] =
          !(_sectionExpanded[sectionTitle] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final guildState = ref.watch(guildProvider);
    final channelState = ref.watch(channelProvider);
    final selectedGuildId = guildState.selectedGuildId;
    final selectedChannelId = channelState.selectedChannelId;

    final activeGuild = selectedGuildId != null
        ? guildState.guilds.firstWhere(
            (g) => g.id == selectedGuildId,
            orElse: () => guildState.guilds.first,
          )
        : null;

    if (selectedGuildId == null) {
      return Container(
        width: 240,
        color: Theme.of(context).colorScheme.surface,
        child: const Center(
          child: Text('Select a guild', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Fetch channels if not already loaded
    final channels = channelState.getChannelsForGuild(selectedGuildId);
    // Only fetch if not already fetched and not currently loading
    if (!channelState.isGuildFetched(selectedGuildId) &&
        !channelState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(channelProvider.notifier).fetchChannels(selectedGuildId);
      });
    }

    final textChannels = channels
        .where((c) => c.type == ChannelType.text)
        .toList();
    final announcementChannels = channels
        .where((c) => c.type == ChannelType.announcement)
        .toList();
    final voiceChannels = channels
        .where((c) => c.type == ChannelType.voice)
        .toList();

    return Stack(
      children: [
        Container(
          // width removed - Expanded will handle the width
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Guild Header
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF1F2023), // Darker gray separator
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeGuild?.name ?? 'Guild',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.7),
                          builder: (context) => InviteModal(
                            open: true,
                            onOpenChange: (open) {
                              if (!open) {
                                Navigator.of(context).pop();
                              }
                            },
                            guildId: selectedGuildId,
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      tooltip: 'Invite Friends',
                    ),
                  ],
                ),
              ),
              // Channels List
              Expanded(
                child: channelState.isLoading
                    ? const Center(child: AppLoading())
                    : channels.isEmpty
                    ? _EmptyChannelsView(
                        onCreateChannel: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.7),
                            builder: (context) => CreateChannelModal(
                              open: true,
                              onOpenChange: (open) {
                                if (!open) {
                                  Navigator.of(context).pop();
                                }
                              },
                              guildId: selectedGuildId,
                              defaultChannelType: ChannelType.text,
                            ),
                          );
                        },
                      )
                    : ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          // Announcement Channels Section
                          _ChannelSection(
                            title: 'ANNOUNCEMENTS',
                            channels: announcementChannels,
                            selectedChannelId: selectedChannelId,
                            onChannelTap: (channel) {
                              ref
                                  .read(channelProvider.notifier)
                                  .setSelectedChannel(channel.id);
                              context.go(
                                '/guilds/$selectedGuildId/channels/${channel.id}',
                              );
                            },
                            onCreateChannel: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.7),
                                builder: (context) => CreateChannelModal(
                                  open: true,
                                  onOpenChange: (open) {
                                    if (!open) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  guildId: selectedGuildId,
                                  defaultChannelType: ChannelType.announcement,
                                ),
                              );
                            },
                            icon: Icons.campaign,
                            isExpanded:
                                _sectionExpanded['ANNOUNCEMENTS'] ?? true,
                            onToggle: () => _toggleSection('ANNOUNCEMENTS'),
                          ),
                          const SizedBox(height: 16),
                          // Text Channels Section
                          _ChannelSection(
                            title: 'TEXT CHANNELS',
                            channels: textChannels,
                            selectedChannelId: selectedChannelId,
                            onChannelTap: (channel) {
                              ref
                                  .read(channelProvider.notifier)
                                  .setSelectedChannel(channel.id);
                              context.go(
                                '/guilds/$selectedGuildId/channels/${channel.id}',
                              );
                            },
                            onCreateChannel: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.7),
                                builder: (context) => CreateChannelModal(
                                  open: true,
                                  onOpenChange: (open) {
                                    if (!open) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  guildId: selectedGuildId,
                                  defaultChannelType: ChannelType.text,
                                ),
                              );
                            },
                            icon: Icons.tag,
                            isExpanded:
                                _sectionExpanded['TEXT CHANNELS'] ?? true,
                            onToggle: () => _toggleSection('TEXT CHANNELS'),
                          ),
                          const SizedBox(height: 16),
                          // Voice Channels Section
                          _ChannelSection(
                            title: 'VOICE CHANNELS',
                            channels: voiceChannels,
                            selectedChannelId: selectedChannelId,
                            onChannelTap: (channel) {
                              // Voice channel handling (for future implementation)
                              ref
                                  .read(channelProvider.notifier)
                                  .setSelectedChannel(channel.id);
                            },
                            onCreateChannel: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.7),
                                builder: (context) => CreateChannelModal(
                                  open: true,
                                  onOpenChange: (open) {
                                    if (!open) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  guildId: selectedGuildId,
                                  defaultChannelType: ChannelType.voice,
                                ),
                              );
                            },
                            icon: Icons.mic,
                            isExpanded:
                                _sectionExpanded['VOICE CHANNELS'] ?? true,
                            onToggle: () => _toggleSection('VOICE CHANNELS'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelSection extends StatelessWidget {
  final String title;
  final List<ChannelDto> channels;
  final String? selectedChannelId;
  final void Function(ChannelDto) onChannelTap;
  final VoidCallback onCreateChannel;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ChannelSection({
    required this.title,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelTap,
    required this.onCreateChannel,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const SizedBox.shrink();
    }

    // If collapsed, only show selected channel (if any)
    final channelsToShow = isExpanded
        ? channels
        : channels.where((c) => c.id == selectedChannelId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        InkWell(
          onTap: onToggle,
          child: Container(
            height: 32, // Explicit height for header
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: onCreateChannel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  splashRadius: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
        // Channel List
        ...channelsToShow.map(
          (channel) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: _ChannelItem(
              channel: channel,
              isSelected: selectedChannelId == channel.id,
              icon: icon,
              onTap: () => onChannelTap(channel),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelItem extends StatelessWidget {
  final ChannelDto channel;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _ChannelItem({
    required this.channel,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 34, // Explicit height for channel item
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChannelsView extends StatelessWidget {
  final VoidCallback onCreateChannel;

  const _EmptyChannelsView({required this.onCreateChannel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No channels yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCreateChannel,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Channel'),
            ),
          ],
        ),
      ),
    );
  }
}
