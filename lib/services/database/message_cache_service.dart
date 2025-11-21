import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/message/message_dto.dart';
import 'database.dart';

/// Service for caching messages in Hive
class MessageCacheService {
  static const String _boxName = 'messages_cache';
  static const String _channelPrefix = 'channel_';
  static const String _lastSyncPrefix = 'last_sync_';
  static const String _pendingMessagesKey = 'pending_messages';

  /// Initialize message cache box
  static Future<void> init() async {
    await DatabaseService.openBox(_boxName);
  }

  /// Get messages box
  static Box _getBox() {
    return DatabaseService.getBox(_boxName);
  }

  /// Save messages for a channel
  static Future<void> saveMessagesForChannel(
    String channelId,
    List<MessageDto> messages,
  ) async {
    final box = _getBox();
    final key = '$_channelPrefix$channelId';
    
    // Convert messages to JSON strings
    final messagesJson = messages.map((m) => jsonEncode(m.toJson())).toList();
    
    await box.put(key, messagesJson);
    
    // Update last sync timestamp
    await box.put('$_lastSyncPrefix$channelId', DateTime.now().toIso8601String());
  }

  /// Get cached messages for a channel
  static List<MessageDto> getCachedMessages(String channelId) {
    final box = _getBox();
    final key = '$_channelPrefix$channelId';
    
    final messagesJson = box.get(key);
    if (messagesJson == null || messagesJson is! List) {
      return [];
    }

    try {
      return messagesJson
          .map((jsonStr) {
            try {
              final json = jsonDecode(jsonStr as String) as Map<String, dynamic>;
              return MessageDto.fromJson(json);
            } catch (e) {
              print('Error parsing cached message: $e');
              return null;
            }
          })
          .whereType<MessageDto>()
          .toList();
    } catch (e) {
      print('Error reading cached messages: $e');
      return [];
    }
  }

  /// Add or update a single message in cache
  static Future<void> saveMessage(MessageDto message) async {
    final channelId = message.channelId;
    final cachedMessages = getCachedMessages(channelId);
    
    // Check if message already exists
    final existingIndex = cachedMessages.indexWhere((m) => m.id == message.id);
    
    if (existingIndex >= 0) {
      // Update existing message
      cachedMessages[existingIndex] = message;
    } else {
      // Add new message
      cachedMessages.add(message);
    }
    
    // Sort by createdAt
    cachedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    await saveMessagesForChannel(channelId, cachedMessages);
  }

  /// Remove a message from cache
  static Future<void> removeMessage(String channelId, String messageId) async {
    final cachedMessages = getCachedMessages(channelId);
    cachedMessages.removeWhere((m) => m.id == messageId);
    await saveMessagesForChannel(channelId, cachedMessages);
  }

  /// Get last sync timestamp for a channel
  static DateTime? getLastSyncTime(String channelId) {
    final box = _getBox();
    final key = '$_lastSyncPrefix$channelId';
    final timestampStr = box.get(key);
    
    if (timestampStr == null || timestampStr is! String) {
      return null;
    }
    
    try {
      return DateTime.parse(timestampStr);
    } catch (e) {
      return null;
    }
  }

  /// Add a pending message (to be sent when online)
  static Future<void> addPendingMessage(
    String channelId,
    String content, {
    String? replyToMessageId,
    List<String>? attachmentIds,
  }) async {
    final box = _getBox();
    final pendingKey = '$_pendingMessagesKey$channelId';
    
    final pendingMessages = box.get(pendingKey);
    List<Map<String, dynamic>> messages;
    
    if (pendingMessages == null || pendingMessages is! List) {
      messages = [];
    } else {
      messages = pendingMessages
          .map((m) => m as Map<String, dynamic>)
          .toList();
    }
    
    messages.add({
      'channelId': channelId,
      'content': content,
      'replyToMessageId': replyToMessageId,
      'attachmentIds': attachmentIds,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await box.put(pendingKey, messages);
  }

  /// Get pending messages for a channel
  static List<Map<String, dynamic>> getPendingMessages(String channelId) {
    final box = _getBox();
    final pendingKey = '$_pendingMessagesKey$channelId';
    
    final pendingMessages = box.get(pendingKey);
    if (pendingMessages == null || pendingMessages is! List) {
      return [];
    }
    
    return pendingMessages
        .map((m) => m as Map<String, dynamic>)
        .toList();
  }

  /// Clear pending messages for a channel
  static Future<void> clearPendingMessages(String channelId) async {
    final box = _getBox();
    final pendingKey = '$_pendingMessagesKey$channelId';
    await box.delete(pendingKey);
  }

  /// Clear all cached messages for a channel
  static Future<void> clearChannelCache(String channelId) async {
    final box = _getBox();
    await box.delete('$_channelPrefix$channelId');
    await box.delete('$_lastSyncPrefix$channelId');
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    final box = _getBox();
    await box.clear();
  }
}

