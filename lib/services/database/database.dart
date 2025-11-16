import 'package:hive_flutter/hive_flutter.dart';

/// Database service using Hive
class DatabaseService {
  static bool _initialized = false;

  /// Initialize Hive database
  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    // Initialize Hive for Flutter
    await Hive.initFlutter();

    // Optional: Set a custom directory
    // final dir = await getApplicationDocumentsDirectory();
    // Hive.init(dir.path);

    _initialized = true;
  }

  /// Open a Hive box (creates if doesn't exist)
  static Future<Box> openBox(String name) async {
    if (!_initialized) {
      await init();
    }
    return await Hive.openBox(name);
  }

  /// Get an existing box (throws if doesn't exist)
  static Box getBox(String name) {
    if (!_initialized) {
      throw Exception('Database not initialized. Call DatabaseService.init() first.');
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

