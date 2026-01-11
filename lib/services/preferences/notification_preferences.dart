import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing notification preferences
class NotificationPreferences {
  static const String _keyChannelNotificationsEnabled = 'channel_notifications_enabled';
  static const String _keyDMNotificationsEnabled = 'dm_notifications_enabled';

  /// Get channel notifications enabled state (default: true)
  Future<bool> getChannelNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyChannelNotificationsEnabled) ?? true;
  }

  /// Set channel notifications enabled state
  Future<void> setChannelNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChannelNotificationsEnabled, enabled);
  }

  /// Get DM notifications enabled state (default: true)
  Future<bool> getDMNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDMNotificationsEnabled) ?? true;
  }

  /// Set DM notifications enabled state
  Future<void> setDMNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDMNotificationsEnabled, enabled);
  }
}
