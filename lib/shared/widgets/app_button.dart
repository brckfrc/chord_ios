import 'package:flutter/material.dart';

/// Custom button widget with Discord-like styling
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final bool isDanger;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.isDanger = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width ?? double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDanger
              ? theme.colorScheme.error
              : isSecondary
                  ? Colors.transparent
                  : theme.colorScheme.primary,
          foregroundColor: isSecondary
              ? theme.colorScheme.primary
              : theme.colorScheme.onPrimary,
          side: isSecondary
              ? BorderSide(color: theme.colorScheme.primary, width: 1)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSecondary
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

