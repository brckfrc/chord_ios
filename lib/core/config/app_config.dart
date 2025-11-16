/// Application configuration
class AppConfig {
  // Backend API base URL
  // TODO: Update this with your actual backend URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  // SignalR Hub URL
  static String get signalRUrl => apiBaseUrl.replaceAll('/api', '/hubs');

  // App version
  static const String appVersion = '1.0.0';

  // Environment
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;
}

