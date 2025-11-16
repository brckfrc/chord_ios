import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth/user_dto.dart';
import '../models/auth/login_dto.dart';
import '../models/auth/register_dto.dart';
import '../repositories/auth_repository.dart';

/// Auth state
class AuthState {
  final UserDto? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserDto? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState()) {
    _checkAuthStatus();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    try {
      final isAuth = await _repository.isAuthenticated();
      if (isAuth) {
        await getCurrentUser();
      }
    } catch (_) {
      // Ignore errors during initial check
    }
  }

  /// Login
  Future<void> login(LoginDto dto) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tokenResponse = await _repository.login(dto);
      state = AuthState(
        user: tokenResponse.user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      rethrow;
    }
  }

  /// Register
  Future<void> register(RegisterDto dto) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tokenResponse = await _repository.register(dto);
      state = AuthState(
        user: tokenResponse.user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      rethrow;
    }
  }

  /// Get current user
  Future<void> getCurrentUser() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.getCurrentUser();
      state = AuthState(user: user, isAuthenticated: true, isLoading: false);
    } catch (e) {
      state = AuthState(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      rethrow;
    }
  }

  /// Refresh token
  Future<void> refreshToken() async {
    try {
      await _repository.refreshToken();
      // Get updated user info
      await getCurrentUser();
    } catch (e) {
      // If refresh fails, logout
      await logout();
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.logout();
      state = AuthState(isLoading: false);
    } catch (e) {
      // Clear state anyway
      state = AuthState(isLoading: false);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
