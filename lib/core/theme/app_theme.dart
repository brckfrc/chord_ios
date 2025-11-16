import 'package:flutter/material.dart';

/// Discord-like dark theme
class AppTheme {
  // Discord color palette
  static const Color discordDark = Color(0xFF36393F);
  static const Color discordDarker = Color(0xFF2F3136);
  static const Color discordDarkest = Color(0xFF202225);
  static const Color discordBlurple = Color(0xFF5865F2);
  static const Color discordGreen = Color(0xFF57F287);
  static const Color discordRed = Color(0xFFED4245);
  static const Color discordYellow = Color(0xFFFEE75C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB9BBBE);
  static const Color textMuted = Color(0xFF72767D);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: discordBlurple,
        secondary: discordGreen,
        error: discordRed,
        surface: discordDark,
        onPrimary: textPrimary,
        onSecondary: discordDarkest,
        onError: textPrimary,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: discordDarkest,
      appBarTheme: const AppBarTheme(
        backgroundColor: discordDarker,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: discordDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: discordDarker,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: discordBlurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: discordRed, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: discordBlurple,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: discordBlurple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall: TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary),
        headlineMedium: TextStyle(color: textPrimary),
        headlineSmall: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textMuted),
      ),
    );
  }
}

