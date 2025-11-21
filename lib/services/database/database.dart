import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Database service using Hive
class DatabaseService {
  static bool _initialized = false;

  /// Initialize Hive database with timeout
  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      // Add timeout to prevent hanging
      await Hive.initFlutter().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Hive.initFlutter() timed out');
        },
      );

      // Open box directly (avoid recursive call)
      await Hive.openBox('messages_cache').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Hive.openBox() timed out');
        },
      );

      _initialized = true;
    } catch (e) {
      _initialized = false;
      rethrow;
    }
  }

  /// Open a Hive box (creates if doesn't exist)
  static Future<Box> openBox(String name) async {
    if (!_initialized) {
      await init();
    }
    try {
      final box = await Hive.openBox(name).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('openBox($name) timed out');
        },
      );
      return box;
    } catch (e) {
      rethrow;
    }
  }

  /// Get an existing box (throws if doesn't exist)
  static Box getBox(String name) {
    if (!_initialized) {
      throw Exception(
        'Database not initialized. Call DatabaseService.init() first.',
      );
    }
    return Hive.box(name);
  }

  /// Check if box exists
  static bool boxExists(String name) {
    return Hive.isBoxOpen(name);
  }

  /// Close a box
  static Future<void> closeBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box(name).close();
    }
  }

  /// Close all boxes
  static Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }
}
