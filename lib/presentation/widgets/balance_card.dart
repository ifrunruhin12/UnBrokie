import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/analytics_summary.dart';
import '../../domain/models/transaction_filter.dart';
import '../providers/analytics_provider.dart';
import '../providers/balance_provider.dart';
import 'loading_skeleton.dart';

/// Teal gradient card showing the user's total balance, income, and expenses.
///
/// - Total balance is read from [balanceProvider].
/// - Income and expense sub-cards are derived from [analyticsProvider] using
///   the provided [filter] (typically the current month range).
///
/// The [filter] parameter is forwarded to [analyticsProvider] so the card
/// always reflects the correct time period.
///
/// Requirements: 3.1, 3.2, 11.5, 11.6
class BalanceCard extends ConsumerWidget {
  const BalanceCard({
    super.key,
    required this.filter,
  });

  /// The [TransactionFilter] used to scope the analytics (income/expense) data.
  /// Typically the current month range.
  final TransactionFilter filter;

  /// Builds a [TransactionFilter] for the current calendar month.
  static TransactionFilter currentMonthFilter() {
    final range = DateFormatter.currentMonthRange();
    return TransactionFilter(from: range.from, to: range.to);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    final analyticsAsync = ref.watch(analyticsProvider(filter));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF16B99A), // AppColors.primary
            Color(0xFF0D8A74), // darker teal
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Total Balance',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 8),

          // Balance amount
          balanceAsync.when(
            data: (state) => Text(
              CurrencyFormatter.format(state.balance.amount),
              style: AppTextStyles.displayLarge.copyWith(
                color: Colors.white,
                fontSize: 36,
              ),
            ),
            loading: () => const LoadingSkeleton(
              width: 180,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            error: (_, __) => Text(
              '--',
              style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

          // Income / Expense sub-cards
          Row(
            children: [
              Expanded(
                child: _SubCard(
                  label: 'Income',
                  icon: Icons.arrow_downward_rounded,
                  analyticsAsync: analyticsAsync,
                  getValue: (s) => s.totalIncome,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SubCard(
                  label: 'Expenses',
                  icon: Icons.arrow_upward_rounded,
                  analyticsAsync: analyticsAsync,
                  getValue: (s) => s.totalExpenses,
                ),
              ),
            ],
          ),

          // Reconciling banner
          if (balanceAsync.asData?.value.isReconciling == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Balance may be updating...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SubCard — income or expense sub-card inside BalanceCard
// ---------------------------------------------------------------------------

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.label,
    required this.icon,
    required this.analyticsAsync,
    required this.getValue,
  });

  final String label;
  final IconData icon;
  final AsyncValue<AnalyticsSummary> analyticsAsync;
  final int Function(AnalyticsSummary summary) getValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          analyticsAsync.when(
            data: (summary) => Text(
              CurrencyFormatter.format(getValue(summary)),
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            loading: () => const LoadingSkeleton(
              width: 80,
              height: 18,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            error: (_, __) => Text(
              '--',
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
