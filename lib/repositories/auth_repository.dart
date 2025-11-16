import 'package:dio/dio.dart';
import '../models/auth/login_dto.dart';
import '../models/auth/register_dto.dart';
import '../models/auth/refresh_token_dto.dart';
import '../models/auth/token_response_dto.dart';
import '../models/auth/user_dto.dart';
import '../services/api/api_client.dart';
import '../services/storage/secure_storage.dart';

/// Auth repository for authentication operations
class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthRepository({ApiClient? apiClient, SecureStorageService? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? SecureStorageService();

  /// Login with email/username and password
  Future<TokenResponseDto> login(LoginDto dto) async {
    try {
      final response = await _apiClient.post('/auth/login', data: dto.toJson());

      final tokenResponse = TokenResponseDto.fromJson(response.data);

      // Save tokens
      await _storage.setAccessToken(tokenResponse.accessToken);
      await _storage.setRefreshToken(tokenResponse.refreshToken);
      await _storage.setUserId(tokenResponse.user.id);

      return tokenResponse;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid email/username or password');
      }
      throw Exception(e.response?.data['message'] ?? 'Login failed');
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Register a new user
  Future<TokenResponseDto> register(RegisterDto dto) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: dto.toJson(),
      );

      final tokenResponse = TokenResponseDto.fromJson(response.data);

      // Save tokens
      await _storage.setAccessToken(tokenResponse.accessToken);
      await _storage.setRefreshToken(tokenResponse.refreshToken);
      await _storage.setUserId(tokenResponse.user.id);

      return tokenResponse;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['message'] ?? 'Registration failed');
      }
      throw Exception(e.response?.data['message'] ?? 'Registration failed');
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  /// Refresh access token
  Future<TokenResponseDto> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final response = await _apiClient.post(
        '/auth/refresh',
        data: RefreshTokenDto(refreshToken: refreshToken).toJson(),
      );

      final tokenResponse = TokenResponseDto.fromJson(response.data);

      // Update tokens
      await _storage.setAccessToken(tokenResponse.accessToken);
      await _storage.setRefreshToken(tokenResponse.refreshToken);

      return tokenResponse;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Refresh token expired, clear all
        await _storage.clearAll();
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Token refresh failed');
    } catch (e) {
      throw Exception('Token refresh failed: ${e.toString()}');
    }
  }

  /// Get current authenticated user
  Future<UserDto> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      return UserDto.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Try to refresh token
        try {
          await refreshToken();
          // Retry after refresh
          final retryResponse = await _apiClient.get('/auth/me');
          return UserDto.fromJson(retryResponse.data);
        } catch (_) {
          await _storage.clearAll();
          throw Exception('Session expired. Please login again.');
        }
      }
      throw Exception('Failed to get user information');
    } catch (e) {
      throw Exception('Failed to get user information: ${e.toString()}');
    }
  }

  /// Logout (clear tokens)
  Future<void> logout() async {
    try {
      // Optional: Call backend logout endpoint
      await _apiClient.post('/auth/logout');
    } catch (_) {
      // Ignore errors, clear local storage anyway
    } finally {
      await _storage.clearAll();
    }
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    final token = await _storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
