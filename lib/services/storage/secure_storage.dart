import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data (tokens, etc.)
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';

  // Access Token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<void> setAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _keyAccessToken);
  }

  // Refresh Token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _keyRefreshToken);
  }

  // User ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  Future<void> setUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  Future<void> deleteUserId() async {
    await _storage.delete(key: _keyUserId);
  }

  // Clear all auth data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

