import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/database/database.dart';
import 'services/notifications/notification_service.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure environment (development/production)
  AppConfig.configure();

  // Error handling for Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ Flutter Error: ${details.exception}');
    if (details.stack != null) {
      print('Stack trace: ${details.stack}');
    }
  };

  // Make status bar transparent so app content can extend behind it
  // SafeArea will handle the padding automatically
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarIconBrightness:
          Brightness.light, // Light icons for dark background
      statusBarBrightness: Brightness.dark, // Android
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize database in background (non-blocking)
  // App will start immediately, database will initialize in parallel
  _initializeDatabase();

  // Initialize notification service
  await NotificationService.initialize();

  // Initialize Sentry (only in production or if DSN is provided)
  if (AppConfig.isProduction) {
    await SentryFlutter.init(
      (options) {
        options.dsn = ''; // TODO: Add your Sentry DSN
        options.tracesSampleRate = 1.0;
      },
      appRunner: () {
        runApp(const ProviderScope(child: MyApp()));
      },
    );
  } else {
    runApp(const ProviderScope(child: MyApp()));
  }
}

/// Initialize database in background with timeout
/// App continues even if database initialization fails
Future<void> _initializeDatabase() async {
  try {
    await DatabaseService.init().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        return;
      },
    );
  } catch (e) {
    // Continue anyway - app works without cache
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.createRouter(ref);
    
    // Set navigation callback for notification deep linking
    NotificationService.setNavigationCallback((route) {
      router.go(route);
    });
    
    return MaterialApp.router(
      title: 'CHORD iOS',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
