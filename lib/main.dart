import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/database/database.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  await DatabaseService.init();

  // Initialize Sentry (only in production or if DSN is provided)
  if (AppConfig.isProduction) {
    await SentryFlutter.init(
      (options) {
        options.dsn = ''; // TODO: Add your Sentry DSN
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        const ProviderScope(
          child: MyApp(),
        ),
      ),
    );
  } else {
    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CHORD iOS',
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
