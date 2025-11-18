import 'package:flutter/material.dart';

/// Friends home screen (shows friends list, online friends, etc.)
/// For now, this is a placeholder - will be implemented later
class FriendsHome extends StatelessWidget {
  const FriendsHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Friends',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Friends list will be implemented soon',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

