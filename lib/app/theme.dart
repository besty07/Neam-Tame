import 'package:flutter/material.dart';

/// Design tokens and shared Material 3 themes for LifeVault.
///
/// Aligned with the LifeVault Visual Design System specification:
/// - Modern premium productivity dashboard with family organizer warmth
/// - Primary: #176B8A, Accent: #15A6A0, Background: #F7F9FC, Surface: #FFFFFF
/// - Soft borders (#E3EAF0), 16px card radius, 10px button/input radius
class LifeVaultColors {
  const LifeVaultColors._();

  static const Color primary = Color(0xFF176B8A);
  static const Color primaryHover = Color(0xFF125772);
  static const Color primaryLight = Color(0xFFEAF5F9);

  static const Color accent = Color(0xFF15A6A0);
  static const Color accentLight = Color(0xFFE5F7F4);

  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF0F5F8);
  static const Color sidebarBackground = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF182637);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE3EAF0);

  static const Color success = Color(0xFF16845B);
  static const Color successBackground = Color(0xFFEAF8F0);

  static const Color warning = Color(0xFFB77B16);
  static const Color warningBackground = Color(0xFFFFF5DE);

  static const Color danger = Color(0xFFC94A51);
  static const Color dangerBackground = Color(0xFFFDEDEE);

  static const Color info = Color(0xFF287DBB);
  static const Color infoBackground = Color(0xFFEAF4FC);
}

/// Shared Material 3 theme configuration for LifeVault v0.1.
class LifeVaultTheme {
  const LifeVaultTheme._();

  static const double cardRadius = 16;
  static const double buttonRadius = 10;
  static const double inputRadius = 10;
  static const double modalRadius = 20;

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: LifeVaultColors.primary,
      onPrimary: Colors.white,
      primaryContainer: LifeVaultColors.primaryLight,
      onPrimaryContainer: LifeVaultColors.textPrimary,
      secondary: LifeVaultColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: LifeVaultColors.accentLight,
      onSecondaryContainer: LifeVaultColors.textPrimary,
      surface: LifeVaultColors.surface,
      onSurface: LifeVaultColors.textPrimary,
      onSurfaceVariant: LifeVaultColors.textSecondary,
      error: LifeVaultColors.danger,
      onError: Colors.white,
      errorContainer: LifeVaultColors.dangerBackground,
      onErrorContainer: LifeVaultColors.danger,
      outline: LifeVaultColors.border,
      outlineVariant: LifeVaultColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LifeVaultColors.background,
      dividerColor: LifeVaultColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: LifeVaultColors.surface,
        foregroundColor: LifeVaultColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: LifeVaultColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: LifeVaultColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: LifeVaultColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LifeVaultColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LifeVaultColors.textPrimary,
          side: const BorderSide(color: LifeVaultColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LifeVaultColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LifeVaultColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: LifeVaultColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: LifeVaultColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: LifeVaultColors.primary,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: LifeVaultColors.surfaceSecondary,
        selectedColor: LifeVaultColors.primaryLight,
        side: const BorderSide(color: LifeVaultColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LifeVaultColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(modalRadius),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: LifeVaultColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: LifeVaultColors.primaryLight,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LifeVaultColors.primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
