import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service for local notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_initialized) {
      print('ℹ️ [NotificationService] Already initialized');
      return;
    }

    print('🔄 [NotificationService] Initializing notification service...');

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      print('✅ [NotificationService] Notification plugin initialized');

      // Request permissions (iOS)
      final iosPermission = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      if (iosPermission != null) {
        print('📱 [NotificationService] iOS permissions: $iosPermission');
      }

      // Request permissions (Android 13+)
      final androidPermission = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (androidPermission != null) {
        print('📱 [NotificationService] Android permission: $androidPermission');
      }

      _initialized = true;
      print('✅ [NotificationService] Notification service initialized successfully');
    } catch (e) {
      print('❌ [NotificationService] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] as String;
      final channelId = data['channelId'] as String;
      
      // Use navigation callback if set
      if (_navigationCallback != null) {
        if (type == 'mention') {
          final guildId = data['guildId'] as String?;
          if (guildId != null) {
            _navigationCallback!('/guilds/$guildId/channels/$channelId');
          } else {
            _navigationCallback!('/mentions');
          }
        } else if (type == 'dm') {
          _navigationCallback!('/me/dm/$channelId');
        }
      }
    } catch (e) {
      print('⚠️ [NotificationService] Failed to handle notification tap: $e');
    }
  }

  static void Function(String route)? _navigationCallback;

  /// Set navigation callback for deep linking
  static void setNavigationCallback(void Function(String route) callback) {
    _navigationCallback = callback;
  }

  /// Show mention notification
  static Future<void> showMentionNotification({
    required String username,
    required String content,
    required String channelId,
    String? guildId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final payload = jsonEncode({
      'type': 'mention',
      'channelId': channelId,
      if (guildId != null) 'guildId': guildId,
    });

    const androidDetails = AndroidNotificationDetails(
      'mentions',
      'Mentions',
      channelDescription: 'Notifications for mentions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      channelId.hashCode,
      '$username mentioned you',
      _truncateContent(content),
      notificationDetails,
      payload: payload,
    );
  }

  /// Show DM notification
  static Future<void> showDMNotification({
    required String username,
    required String content,
    required String channelId,
  }) async {
    print('🔔 [NotificationService] showDMNotification called: username=$username, channelId=$channelId');
    
    if (!_initialized) {
      print('🔄 [NotificationService] Initializing notification service...');
      await initialize();
    }

    final payload = jsonEncode({
      'type': 'dm',
      'channelId': channelId,
    });

    const androidDetails = AndroidNotificationDetails(
      'dms',
      'Direct Messages',
      channelDescription: 'Notifications for direct messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        channelId.hashCode,
        username,
        _truncateContent(content),
        notificationDetails,
        payload: payload,
      );
      print('✅ [NotificationService] DM notification shown successfully');
    } catch (e) {
      print('❌ [NotificationService] Failed to show DM notification: $e');
      rethrow;
    }
  }

  /// Truncate content to max length
  static String _truncateContent(String content, {int maxLength = 50}) {
    if (content.isEmpty) return 'New message';
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// Update badge count (iOS)
  static Future<void> updateBadgeCount(int count) async {
    if (!_initialized) return;
    
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions();
    
    // Badge count is managed by the app, not the notification plugin
    // This is a placeholder for future badge count implementation
  }
}
