import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/database/database.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize database
  await DatabaseService.init();

  // Initialize Sentry (only in production or if DSN is provided)
  if (AppConfig.isProduction) {
    await SentryFlutter.init((options) {
      options.dsn = ''; // TODO: Add your Sentry DSN
      options.tracesSampleRate = 1.0;
    }, appRunner: () => runApp(const ProviderScope(child: MyApp())));
  } else {
    runApp(const ProviderScope(child: MyApp()));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CHORD iOS',
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.createRouter(ref),
      debugShowCheckedModeBanner: false,
    );
  }
}
