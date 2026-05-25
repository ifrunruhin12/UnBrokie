import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/transaction.dart';

/// A single row in a transaction list.
///
/// Displays:
/// - A category icon placeholder on the left
/// - Transaction name (category name) and category label
/// - Time of the transaction
/// - Amount — teal if positive (income), default text color if negative (expense)
/// - Skipped transactions are rendered with muted/strikethrough styling
///
/// Requirements: 3.4, 11.5, 11.6
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;

  /// Optional tap handler — opens the transaction detail sheet.
  final VoidCallback? onTap;

  bool get _isIncome => transaction.amount > 0;
  bool get _isSkipped => transaction.status == TransactionStatus.skipped;

  @override
  Widget build(BuildContext context) {
    final amountText = CurrencyFormatter.format(transaction.amount.abs());
    final timeLabel = DateFormatter.transactionDateLabel(transaction.date);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Category icon
            _CategoryIcon(categoryName: transaction.categoryName),
            const SizedBox(width: 12),

            // Name + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.categoryName,
                    style: _isSkipped
                        ? AppTextStyles.titleMedium.copyWith(
                            color: AppColors.mutedText,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.mutedText,
                          )
                        : AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.note?.isNotEmpty == true
                        ? transaction.note!
                        : transaction.categoryName,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Time + amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _isIncome ? '+$amountText' : '-$amountText',
                  style: _isSkipped
                      ? AppTextStyles.amountExpense.copyWith(
                          color: AppColors.mutedText,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.mutedText,
                        )
                      : (_isIncome
                          ? AppTextStyles.amountIncome
                          : AppTextStyles.amountExpense),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular icon placeholder for a transaction category.
class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.categoryName});

  final String categoryName;

  /// Returns a simple icon based on common category names.
  IconData _iconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('eat')) {
      return Icons.restaurant_outlined;
    }
    if (lower.contains('transport') || lower.contains('travel')) {
      return Icons.directions_car_outlined;
    }
    if (lower.contains('health') || lower.contains('medical')) {
      return Icons.favorite_outline;
    }
    if (lower.contains('saving')) return Icons.savings_outlined;
    if (lower.contains('hobby') || lower.contains('entertainment')) {
      return Icons.sports_esports_outlined;
    }
    if (lower.contains('big buy') || lower.contains('shopping')) {
      return Icons.shopping_bag_outlined;
    }
    return Icons.receipt_long_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cardSecondary,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Icon(
        _iconForCategory(categoryName),
        color: AppColors.mutedText,
        size: 20,
      ),
    );
  }
}
