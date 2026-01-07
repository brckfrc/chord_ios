import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import '../storage/secure_storage.dart';
import '../../models/auth/refresh_token_dto.dart';
import '../../models/auth/token_response_dto.dart';

/// API Client using Dio
class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json, // JSON response'u otomatik parse et
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized - refresh token or retry request
          if (error.response?.statusCode == 401) {
            // Skip refresh for auth endpoints to avoid infinite loop
            final requestPath = error.requestOptions.path;
            if (requestPath.contains('/auth/login') ||
                requestPath.contains('/auth/register') ||
                requestPath.contains('/auth/refresh')) {
              return handler.next(error);
            }

            // Try to refresh token and retry the request
            try {
              final refreshed = await _refreshTokenAndRetry(error.requestOptions);
              if (refreshed != null) {
                return handler.resolve(refreshed);
              }
            } catch (e) {
              // Refresh failed, clear tokens and return error
              await _storage.clearAll();
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Refresh token and retry the failed request
  Future<Response?> _refreshTokenAndRetry(RequestOptions requestOptions) async {
    // If already refreshing, wait for it to complete
    if (_isRefreshing) {
      return await _waitForRefresh(requestOptions);
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      // Create a new Dio instance without interceptors to avoid infinite loop
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          responseType: ResponseType.json,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Call refresh endpoint directly (no interceptors)
      final refreshResponse = await refreshDio.post(
        '/auth/refresh',
        data: RefreshTokenDto(refreshToken: refreshToken).toJson(),
      );

      final tokenResponse = TokenResponseDto.fromJson(refreshResponse.data);

      // Update tokens
      await _storage.setAccessToken(tokenResponse.accessToken);
      await _storage.setRefreshToken(tokenResponse.refreshToken);

      // Retry the original request with new token
      requestOptions.headers['Authorization'] = 'Bearer ${tokenResponse.accessToken}';
      final response = await _dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
        ),
      );

      // Process pending requests
      _processPendingRequests(tokenResponse.accessToken);

      return response;
    } catch (e) {
      // Refresh failed, clear tokens
      await _storage.clearAll();
      // Reject all pending requests
      _rejectPendingRequests(e);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Wait for ongoing refresh to complete
  Future<Response?> _waitForRefresh(RequestOptions requestOptions) async {
    final completer = Completer<Response?>();
    _pendingRequests.add(_PendingRequest(requestOptions, completer));
    return completer.future;
  }

  /// Process pending requests after successful refresh
  void _processPendingRequests(String newAccessToken) {
    for (final pending in _pendingRequests) {
      pending.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      _dio
          .request(
            pending.requestOptions.path,
            data: pending.requestOptions.data,
            queryParameters: pending.requestOptions.queryParameters,
            options: Options(
              method: pending.requestOptions.method,
              headers: pending.requestOptions.headers,
            ),
          )
          .then((response) => pending.completer.complete(response))
          .catchError((error) => pending.completer.completeError(error));
    }
    _pendingRequests.clear();
  }

  /// Reject all pending requests
  void _rejectPendingRequests(dynamic error) {
    for (final pending in _pendingRequests) {
      pending.completer.completeError(error);
    }
    _pendingRequests.clear();
  }
}

/// Pending request during token refresh
class _PendingRequest {
  final RequestOptions requestOptions;
  final Completer<Response?> completer;

  _PendingRequest(this.requestOptions, this.completer);
}

