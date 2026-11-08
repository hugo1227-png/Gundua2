import 'package:flutter/material.dart';

/// GUNDUA's single source of truth for colour, type, spacing and corner radii.
/// Keep display and interaction styles here instead of duplicating per screen.
abstract final class GunduaTheme {
  static const ink = Color(0xFF182332);
  static const muted = Color(0xFF576370);
  static const accent = Color(0xFFB83248);
  static const canvas = Color(0xFFF7F8F7);
  static const surface = Colors.white;
  static const line = Color(0xFFE5E8E9);
  static const image = Color(0xFFE9EDF0);

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double pageInset = 22;
  static const double cardRadius = 18;
  // For cards padded by 12 px: inner radius = 18 - 12 = 6 px.
  static const double innerRadius = 6;
  static const double sectionGap = 28;

  static const tabularNumbers = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static ThemeData light() {
    final colors = ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: ink,
      brightness: Brightness.light,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      iconTheme: const IconThemeData(color: ink, size: 22),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, height: 1.13, fontWeight: FontWeight.w700, letterSpacing: -.8, color: ink),
        headlineMedium: TextStyle(fontSize: 28, height: 1.18, fontWeight: FontWeight.w700, letterSpacing: -.5, color: ink),
        titleLarge: TextStyle(fontSize: 21, height: 1.2, fontWeight: FontWeight.w700, color: ink),
        titleMedium: TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: accent, width: 1.5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: .10),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(100, 48),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          minimumSize: const Size(100, 48),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
    );
  }
}
