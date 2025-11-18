import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Splash/Welcome screen with auto-login
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // Wait a bit for UI to show
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Wait for initial auth check to complete
      // During hot restart, AuthNotifier._checkAuthStatus() is running
      AuthState authState;
      int attempts = 0;
      const maxAttempts = 30; // Max 3 seconds wait (30 * 100ms)
      
      do {
        authState = ref.read(authProvider);
        if (!authState.isLoading) break;
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      } while (attempts < maxAttempts && mounted);
      
      // If already authenticated, go to home
      if (authState.isAuthenticated && authState.user != null) {
        if (mounted) {
          context.go('/me');
        }
        return;
      }

      // If still loading after max attempts, try to get current user manually
      // This handles edge cases where _checkAuthStatus() is stuck
      if (authState.isLoading) {
        try {
          await ref.read(authProvider.notifier).getCurrentUser();
          final newAuthState = ref.read(authProvider);
          if (newAuthState.isAuthenticated && mounted) {
            context.go('/me');
            return;
          }
        } catch (_) {
          // Ignore errors
        }
      }
    } catch (_) {
      // Ignore errors, will redirect to login
    }

    // Redirect to login if not authenticated
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.discordDarkest,
              AppTheme.discordDarker,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo placeholder
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.discordBlurple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'CHORD',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'iOS Version',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Discord-like chat application',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 64),
                  // Status indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.discordGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ready',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

