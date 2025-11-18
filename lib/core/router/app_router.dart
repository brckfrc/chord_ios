import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../shared/widgets/protected_route.dart';
import '../../providers/auth_provider.dart';
import '../../features/guild/main_layout.dart';
import '../../features/guild/channel_view.dart';
import '../../features/friends/friends_layout.dart';
import '../../features/friends/dm_view.dart';

/// Application router configuration
class AppRouter {
  static GoRouter createRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final authState = ref.read(authProvider);

        // Allow splash screen to handle initial auth check
        if (state.matchedLocation == '/') {
          return null;
        }

        // Wait for initial auth check to complete
        // During hot reload/restart, state might be loading
        if (authState.isLoading && !authState.isAuthenticated) {
          // Don't redirect while checking auth status
          return null;
        }

        final isLoggedIn = authState.isAuthenticated;
        final isLoggingIn =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        // If not logged in and trying to access protected route, redirect to login
        if (!isLoggedIn && !isLoggingIn && state.matchedLocation != '/') {
          return '/login';
        }

        // If logged in and on login/register, redirect to home
        if (isLoggedIn && isLoggingIn) {
          return '/me';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/me',
          builder: (context, state) =>
              const ProtectedRoute(child: FriendsLayout()),
        ),
        GoRoute(
          path: '/me/dm/:channelId',
          builder: (context, state) {
            final channelId = state.pathParameters['channelId']!;
            return ProtectedRoute(
              // DM seçildiğinde FriendsLayout kullanma, doğrudan DMView tam ekran
              child: DMView(channelId: channelId),
            );
          },
        ),
        GoRoute(
          path: '/guilds/:guildId',
          builder: (context, state) {
            return const ProtectedRoute(child: MainLayout());
          },
        ),
        GoRoute(
          path: '/guilds/:guildId/channels/:channelId',
          builder: (context, state) {
            final guildId = state.pathParameters['guildId']!;
            final channelId = state.pathParameters['channelId']!;
            return ProtectedRoute(
              // Channel seçildiğinde MainLayout kullanma, doğrudan ChannelView tam ekran
              child: ChannelView(guildId: guildId, channelId: channelId),
            );
          },
        ),
      ],
    );
  }
}
