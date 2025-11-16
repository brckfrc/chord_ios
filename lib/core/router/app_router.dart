import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';

/// Application router configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      // TODO: Add routes for auth, guild, channel, etc.
    ],
  );
}

