import 'package:flutter/material.dart';
import '../guild/guild_sidebar.dart';
import '../guild/channel_sidebar.dart';

/// Main layout showing GuildSidebar and ChannelSidebar together (full screen)
/// Used when no channel is selected
class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false, // VoiceBar handles bottom padding
        child: Row(
          children: [
            // Guild Sidebar
            const GuildSidebar(),

            // Channel Sidebar (expanded to fill remaining space)
            const Expanded(
              child: ChannelSidebar(),
            ),
          ],
        ),
      ),
    );
  }
}

