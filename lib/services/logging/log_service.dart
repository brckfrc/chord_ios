import 'package:flutter/foundation.dart';

/// Log levels
enum LogLevel { debug, info, warning, error }

/// Debug/Production aware logging service
class LogService {
  final String tag;
  
  LogService(this.tag);
  
  /// Log debug message (development only)
  void debug(String message) => _log(message, LogLevel.debug);
  
  /// Log info message (development only)
  void info(String message) => _log(message, LogLevel.info);
  
  /// Log warning message (development only)
  void warn(String message) => _log(message, LogLevel.warning);
  
  /// Log error message (always logged, sent to Crashlytics in production)
  void error(String message) => _log(message, LogLevel.error);
  
  void _log(String message, LogLevel level) {
    // Development: Show all logs
    if (kDebugMode) {
      final emoji = _getEmoji(level);
      debugPrint('$emoji [$tag] $message');
      return;
    }
    
    // Production: Only show errors (and send to Crashlytics/Sentry)
    if (level == LogLevel.error) {
      debugPrint('❌ [$tag] $message');
      // TODO: Send to Crashlytics/Sentry
    }
  }
  
  String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}
