import 'package:flutter/material.dart';

/// Toast notification helper
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        duration: duration,
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

