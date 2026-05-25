import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Builds the Material 3 dark theme wired to design tokens.
/// Requirements: 11.1, 11.2, 11.3
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: Colors.black,
    primaryContainer: AppColors.cardSecondary,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.primary,
    onSecondary: Colors.black,
    secondaryContainer: AppColors.cardSecondary,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.primary,
    onTertiary: Colors.black,
    tertiaryContainer: AppColors.cardSecondary,
    onTertiaryContainer: AppColors.textPrimary,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFECACA),
    surface: AppColors.cardPrimary,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.cardSecondary,
    onSurfaceVariant: AppColors.mutedText,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    shadow: Colors.black,
    scrim: Colors.black54,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.primary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTextStyles.headlineMedium,
    ),

    // Cards — minimum 20px radius (Req 11.2)
    cardTheme: const CardThemeData(
      color: AppColors.cardPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorderRadius),
      margin: EdgeInsets.zero,
    ),

    // Elevated buttons — minimum 20px radius (Req 11.2)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorderRadius,
        ),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Outlined buttons — minimum 20px radius (Req 11.2)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorderRadius,
        ),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Input fields — pill-shaped, minimum 20px radius (Req 11.2, 11.4)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardPrimary,
      hintStyle: const TextStyle(color: AppColors.mutedText),
      labelStyle: const TextStyle(color: AppColors.mutedText),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputBorderRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorderRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorderRadius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorderRadius,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorderRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),

    // Bottom navigation bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardPrimary,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.mutedText,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Navigation bar (Material 3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cardPrimary,
      indicatorColor: AppColors.primary.withAlpha(30),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary);
        }
        return const IconThemeData(color: AppColors.mutedText);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        );
      }),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // Chip — pill-shaped
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cardSecondary,
      selectedColor: AppColors.primary.withAlpha(40),
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      side: const BorderSide(color: AppColors.border),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.pillBorderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // Dialog
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.cardPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
      ),
      titleTextStyle: AppTextStyles.headlineMedium,
      contentTextStyle: AppTextStyles.bodyMedium,
    ),

    // Bottom sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.cardPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.medium),
        ),
      ),
    ),

    // Floating action button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.black,
      shape: CircleBorder(),
    ),

    // Icon
    iconTheme: const IconThemeData(
      color: AppColors.mutedText,
      size: 24,
    ),

    // Text theme
    textTheme: const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      titleMedium: AppTextStyles.titleMedium,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelSmall: AppTextStyles.labelSmall,
    ),
  );
}
