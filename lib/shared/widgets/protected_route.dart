import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_loading.dart';
import '../../features/voice/voice_bar.dart';

/// Protected route wrapper - redirects to login if not authenticated
class ProtectedRoute extends ConsumerWidget {
  final Widget child;

  const ProtectedRoute({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show loading while checking auth
    if (authState.isLoading && !authState.isAuthenticated) {
      return const Scaffold(
        body: AppLoading(message: 'Loading...'),
      );
    }

    // Redirect to login if not authenticated
    if (!authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Use Navigator instead of go_router to avoid circular dependency
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(
        body: AppLoading(message: 'Redirecting to login...'),
      );
    }

    // Wrap child with Column to add VoiceBar at bottom
    // VoiceBar will automatically show/hide based on voice state
    return Column(
      children: [
        Expanded(child: child),
        const VoiceBar(),
      ],
    );
  }
}

