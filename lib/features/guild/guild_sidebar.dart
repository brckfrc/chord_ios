import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/guild_provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/guild/guild_dto.dart';
import '../../models/auth/user_status.dart';
import '../../features/modals/create_guild_modal.dart';
import '../../features/settings/user_settings_modal.dart';
import '../../shared/widgets/user_status_indicator.dart';

/// Guild sidebar widget
class GuildSidebar extends ConsumerStatefulWidget {
  const GuildSidebar({super.key});

  @override
  ConsumerState<GuildSidebar> createState() => _GuildSidebarState();
}

class _GuildSidebarState extends ConsumerState<GuildSidebar> {
  @override
  Widget build(BuildContext context) {
    final guildState = ref.watch(guildProvider);
    final selectedGuildId = guildState.selectedGuildId;
    final location = GoRouterState.of(context).uri.path;

    final isHomeActive = location == '/me' || location.startsWith('/me/dm/');

    return Stack(
      children: [
        Container(
          width: 64,
          color: const Color(0xFF1E1F22),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Home Button
              _GuildButton(
                icon: Icons.home,
                isActive: isHomeActive,
                onTap: () {
                  ref.read(guildProvider.notifier).setSelectedGuild(null);
                  ref.read(channelProvider.notifier).clearChannels(null);
                  context.go('/me');
                },
              ),
              const SizedBox(height: 8),
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFF2B2D31),
                indent: 16,
                endIndent: 16,
              ),
              const SizedBox(height: 8),
              // Guild List
              Expanded(
                child: ListView.builder(
                  itemCount: guildState.guilds.length,
                  itemBuilder: (context, index) {
                    final guild = guildState.guilds[index];
                    // Only check selectedGuildId - location check causes bugs when navigating to home
                    final isSelected = selectedGuildId == guild.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GuildButton(
                        guild: guild,
                        isActive: isSelected,
                        onTap: () {
                          ref
                              .read(guildProvider.notifier)
                              .setSelectedGuild(guild.id);
                          context.go('/guilds/${guild.id}');
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFF2B2D31),
                indent: 16,
                endIndent: 16,
              ),
              const SizedBox(height: 8),
              // Create Guild Button
              _GuildButton(
                icon: Icons.add,
                isActive: false,
                onTap: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withOpacity(0.7),
                    builder: (context) => CreateGuildModal(
                      open: true,
                      onOpenChange: (open) {
                        if (!open) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // User Profile Button (status değiştirme için)
              const _UserProfileButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuildButton extends StatelessWidget {
  final GuildDto? guild;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;

  const _GuildButton({
    this.guild,
    this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF313338),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimary
                      : Colors.white,
                  size: 24,
                )
              : guild != null
              ? guild!.iconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          guild!.iconUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _GuildInitial(name: guild!.name),
                        ),
                      )
                    : _GuildInitial(name: guild!.name)
              : const SizedBox(),
        ),
      ),
    );
  }
}

class _GuildInitial extends StatelessWidget {
  final String name;

  const _GuildInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _UserProfileButton extends ConsumerStatefulWidget {
  const _UserProfileButton();

  @override
  ConsumerState<_UserProfileButton> createState() => _UserProfileButtonState();
}

class _UserProfileButtonState extends ConsumerState<_UserProfileButton> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final currentStatus = currentUser?.status ?? UserStatus.offline;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.7),
          builder: (context) => UserSettingsModal(
            open: true,
            onOpenChange: (open) {
              if (!open) {
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
      child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF313338),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar
                Center(
                  child: currentUser?.avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            currentUser!.avatarUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              final displayName = currentUser.displayName;
                              final username = currentUser.username;
                              return CircleAvatar(
                                radius: 24,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  displayName != null && displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : username.isNotEmpty
                                          ? username[0].toUpperCase()
                                          : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            currentUser != null
                                ? (currentUser.displayName?.isNotEmpty == true
                                    ? currentUser.displayName![0].toUpperCase()
                                    : currentUser.username.isNotEmpty
                                        ? currentUser.username[0].toUpperCase()
                                        : '?')
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                // Status indicator (bottom right)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: UserStatusIndicator(
                    status: currentStatus,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
