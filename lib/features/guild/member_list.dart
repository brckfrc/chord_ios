import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/guild/guild_member_dto.dart';
import '../../models/auth/user_status.dart';
import '../../repositories/guild_repository.dart';
import '../../providers/presence_provider.dart';
import '../../shared/widgets/user_status_indicator.dart';

/// Member list widget showing guild members with status
class MemberList extends ConsumerStatefulWidget {
  final String guildId;

  const MemberList({
    super.key,
    required this.guildId,
  });

  @override
  ConsumerState<MemberList> createState() => _MemberListState();
}

class _MemberListState extends ConsumerState<MemberList> {
  List<GuildMemberDto> _members = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = GuildRepository();
      final members = await repository.getGuildMembers(widget.guildId);

      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Group members by status
  /// Online, Idle, DND are all shown under "ONLINE" category
  Map<String, List<GuildMemberDto>> _groupMembersByStatus() {
    final presenceState = ref.watch(presenceProvider);
    final onlineMembers = <GuildMemberDto>[]; // Online, Idle, DND hepsi burada
    final offlineMembers = <GuildMemberDto>[];

    for (final member in _members) {
      final userId = member.userId;
      final status = presenceState.getStatus(userId);
      
      // Invisible users should appear as offline
      final displayStatus = status == UserStatus.invisible 
          ? UserStatus.offline 
          : status;
      
      // Online, Idle, DND hepsi "online" kategorisinde
      if (displayStatus == UserStatus.online || 
          displayStatus == UserStatus.idle || 
          displayStatus == UserStatus.dnd) {
        onlineMembers.add(member);
      } else {
        offlineMembers.add(member);
      }
    }

    return {
      'online': onlineMembers,
      'offline': offlineMembers,
    };
  }


  Widget _buildMemberItem(GuildMemberDto member, UserStatus status) {
    final displayName = member.displayName;
    final username = member.username;
    final avatarUrl = member.user?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          AvatarWithStatus(
            avatarUrl: avatarUrl,
            displayName: displayName,
            status: status,
            avatarRadius: 20,
            statusSize: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.nickname != null && member.nickname!.isNotEmpty)
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(
    String title,
    List<GuildMemberDto> members,
  ) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '$title — ${members.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...members.map((member) {
          final userId = member.userId;
          final status = ref.read(presenceProvider).getStatus(userId);
          final displayStatus = status == UserStatus.invisible 
              ? UserStatus.offline 
              : status;
          return _buildMemberItem(member, displayStatus);
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load members',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMembers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No members',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final groupedMembers = _groupMembersByStatus();

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        children: [
          // Online section (includes Online, Idle, DND)
          if (groupedMembers['online']!.isNotEmpty)
            _buildStatusSection('ONLINE', groupedMembers['online']!),
          // Offline section
          if (groupedMembers['offline']!.isNotEmpty)
            _buildStatusSection('OFFLINE', groupedMembers['offline']!),
        ],
      ),
    );
  }
}

