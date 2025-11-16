import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../shared/widgets/protected_route.dart';
import '../../providers/auth_provider.dart';

/// Application router configuration
class AppRouter {
  static GoRouter createRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isLoggedIn = authState.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login' || 
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
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
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
          builder: (context, state) => const ProtectedRoute(
            child: Scaffold(
              body: Center(
                child: Text('Home - Coming soon'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

