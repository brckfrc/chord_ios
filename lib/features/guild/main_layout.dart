import 'package:flutter/material.dart';
import '../guild/guild_sidebar.dart';
import '../guild/channel_sidebar.dart';
import '../voice/voice_bar.dart';

/// Main layout showing GuildSidebar and ChannelSidebar together (full screen)
/// Used when no channel is selected
class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
            
            // Voice Bar (bottom bar when in voice channel)
            const VoiceBar(),
          ],
        ),
      ),
    );
  }
}

