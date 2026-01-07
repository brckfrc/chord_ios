import 'dart:io';

/// Environment enum
enum Environment { development, production }

/// Application configuration
class AppConfig {
  static Environment _currentEnvironment = Environment.production;
  
  /// Configure environment based on --dart-define
  /// Default is production. Use --dart-define ENV=development for development mode
  static void configure() {
    const env = String.fromEnvironment('ENV', defaultValue: 'production');
    _currentEnvironment = env == 'development' 
      ? Environment.development 
      : Environment.production;
  }
  
  /// Current environment
  static Environment get currentEnvironment => _currentEnvironment;
  
  /// Backend API base URL
  static String get apiBaseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        // Use 10.0.2.2 for Android emulator, localhost for others
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:5049/api';
        }
        return 'http://localhost:5049/api';
      case Environment.production:
        return 'https://chord.borak.dev/api';
    }
  }

  /// SignalR Hub base URL
  static String get signalRUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        // Use 10.0.2.2 for Android emulator, localhost for others
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:5049';
        }
        return 'http://localhost:5049';
      case Environment.production:
        return 'https://chord.borak.dev';
    }
  }
  
  /// LiveKit WebRTC server URL
  static String get liveKitUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        // Use 10.0.2.2 for Android emulator, localhost for others
        if (Platform.isAndroid) {
          return 'ws://10.0.2.2:7880';
        }
        return 'ws://localhost:7880';
      case Environment.production:
        return 'wss://chord.borak.dev:7880';
    }
  }

  // App version
  static const String appVersion = '1.0.0';

  // Environment flags
  static bool get isProduction => _currentEnvironment == Environment.production;
  static bool get isDevelopment => _currentEnvironment == Environment.development;
}
