import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';

/// A compact card displaying a labelled monetary amount.
///
/// Used on the Analytics screen for Total Income, Total Expenses, and
/// Net Savings. The optional [color] overrides the default amount text color.
///
/// Requirements: 3.2, 11.5
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.amount,
    this.color,
  });

  /// Short label shown above the amount (e.g. "Total Income").
  final String label;

  /// Amount in smallest currency unit (cents). Formatted via [CurrencyFormatter].
  final int amount;

  /// Optional override for the amount text color.
  /// Defaults to [AppColors.textPrimary] when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTextStyles.titleMedium.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
