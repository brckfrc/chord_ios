import 'package:flutter/material.dart';

/// Toast notification helper
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Try to get root context if available
    BuildContext? rootContext;
    try {
      rootContext = Navigator.of(context, rootNavigator: true).context;
    } catch (_) {
      rootContext = context;
    }

    final theme = Theme.of(rootContext);
    ScaffoldMessenger.of(rootContext).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: isError
            ? theme.colorScheme.error
            : theme.colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, isError: true);
  }
}

