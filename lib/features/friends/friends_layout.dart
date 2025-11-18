import 'package:flutter/material.dart';
import '../guild/guild_sidebar.dart';
import 'friends_sidebar.dart';

/// Friends layout showing GuildSidebar + FriendsSidebar (full screen)
/// Used for /me route
class FriendsLayout extends StatelessWidget {
  const FriendsLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Guild Sidebar
            const GuildSidebar(),

            // Friends Sidebar (expanded to fill remaining space)
            const Expanded(
              child: FriendsSidebar(),
            ),
          ],
        ),
      ),
    );
  }
}

