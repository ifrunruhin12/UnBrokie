import 'package:flutter/material.dart';

/// Design tokens — single source of truth for all colors, radii, and typography.
/// All widgets MUST reference these constants rather than hardcoded values.
/// Requirements: 11.1, 11.2, 11.3

abstract final class AppColors {
  /// Background color for all screens.
  static const Color background = Color(0xFF0A0A0A);

  /// Primary card surface color.
  static const Color cardPrimary = Color(0xFF1E1E2E);

  /// Secondary card / elevated surface color.
  static const Color cardSecondary = Color(0xFF2F2F42);

  /// Primary teal accent — buttons, active icons, income amounts.
  static const Color primary = Color(0xFF16B99A);

  /// Muted text — secondary labels, inactive nav icons.
  static const Color mutedText = Color(0xFF9CA3AF);

  /// Border / divider color.
  static const Color border = Color(0xFF454557);

  /// Default (white) text color.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Error / destructive color.
  static const Color error = Color(0xFFEF4444);

  /// Success color (alias for primary teal).
  static const Color success = primary;
}

abstract final class AppRadius {
  /// Minimum corner radius for cards, buttons, and input fields (Req 11.2).
  static const double card = 20.0;
  static const double button = 20.0;
  static const double input = 20.0;

  /// Pill-shaped radius for chips and tags.
  static const double pill = 100.0;

  /// Small radius for minor UI elements.
  static const double small = 8.0;

  /// Medium radius for dialogs and sheets.
  static const double medium = 16.0;

  // BorderRadius helpers
  static const BorderRadius cardBorderRadius =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonBorderRadius =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputBorderRadius =
      BorderRadius.all(Radius.circular(input));
  static const BorderRadius pillBorderRadius =
      BorderRadius.all(Radius.circular(pill));
}

abstract final class AppTextStyles {
  /// Display / hero number (e.g. balance amount).
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Section heading.
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Card title / list item primary text.
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Body text.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Secondary / muted body text.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
  );

  /// Label for chips, badges, and captions.
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedText,
    letterSpacing: 0.5,
  );

  /// Amount text — income (teal).
  static const TextStyle amountIncome = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  /// Amount text — expense (default white).
  static const TextStyle amountExpense = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
