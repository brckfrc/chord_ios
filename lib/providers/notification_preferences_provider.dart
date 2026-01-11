import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences/notification_preferences.dart';

/// State class for notification preferences
class NotificationPreferencesState {
  final bool channelEnabled;
  final bool dmEnabled;

  const NotificationPreferencesState({
    required this.channelEnabled,
    required this.dmEnabled,
  });

  NotificationPreferencesState copyWith({
    bool? channelEnabled,
    bool? dmEnabled,
  }) {
    return NotificationPreferencesState(
      channelEnabled: channelEnabled ?? this.channelEnabled,
      dmEnabled: dmEnabled ?? this.dmEnabled,
    );
  }
}

/// Notifier for managing notification preferences
class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferencesState> {
  final NotificationPreferences _preferences;

  NotificationPreferencesNotifier(this._preferences)
      : super(const NotificationPreferencesState(
          channelEnabled: true,
          dmEnabled: true,
        )) {
    _loadPreferences();
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    final channelEnabled = await _preferences.getChannelNotificationsEnabled();
    final dmEnabled = await _preferences.getDMNotificationsEnabled();
    state = NotificationPreferencesState(
      channelEnabled: channelEnabled,
      dmEnabled: dmEnabled,
    );
  }

  /// Update channel notifications preference
  Future<void> setChannelNotificationsEnabled(bool enabled) async {
    await _preferences.setChannelNotificationsEnabled(enabled);
    state = state.copyWith(channelEnabled: enabled);
  }

  /// Update DM notifications preference
  Future<void> setDMNotificationsEnabled(bool enabled) async {
    await _preferences.setDMNotificationsEnabled(enabled);
    state = state.copyWith(dmEnabled: enabled);
  }
}

/// Provider for notification preferences
final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferencesState>(
  (ref) {
    final preferences = NotificationPreferences();
    return NotificationPreferencesNotifier(preferences);
  },
);
