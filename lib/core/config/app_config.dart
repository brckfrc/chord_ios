import 'dart:io';

/// Application configuration
class AppConfig {
  // Backend API base URL
  // Android Emulator: Use 10.0.2.2 instead of localhost
  // iOS Simulator/Web: Use localhost
  // Production: Update with your production URL
  static String get apiBaseUrl {
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

    if (baseUrl.isNotEmpty) {
      return baseUrl;
    }

    // Use 10.0.2.2 for Android emulator, localhost for others
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5049/api';
    }
    return 'http://localhost:5049/api';
  }

  // SignalR Hub URL
  static String get signalRUrl => apiBaseUrl.replaceAll('/api', '/hubs');

  // App version
  static const String appVersion = '1.0.0';

  // Environment
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;
}
