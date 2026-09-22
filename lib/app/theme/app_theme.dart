import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1D2452);
  static const accent = Color(0xFFFE8C31);
  static const canvas = Color(0xFFF6F7FB);
  static const muted = Color(0xFF69718A);
  static const success = Color(0xFF237768);
  static const info = Color(0xFF3B6FD6);
  static const warning = Color(0xFFB3690A);
  static const warningTint = Color(0xFFFFF3E0);

  /// Brand teal re-stepped to pass the chart chroma floor on light surfaces.
  static const chart = Color(0xFF1F8A6E);
}

abstract final class AppSpacing {
  static const small = 8.0, medium = 16.0, large = 24.0, section = 32.0;
}

abstract final class AppRadius {
  static const card = 24.0, control = 16.0;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x0A1D2452), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

abstract final class AppTypography {
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.5,
  );
  static const section = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.5,
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final colors = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: AppTypography.title,
        titleLarge: AppTypography.section,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: Color(0xFFE3E6EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accent.withValues(alpha: .17),
      ),
    );
  }
}
