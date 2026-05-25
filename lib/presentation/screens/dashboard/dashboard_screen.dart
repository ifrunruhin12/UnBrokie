import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/transaction_filter.dart';
import '../../providers/metadata_provider.dart';
import '../../providers/transaction_stream_provider.dart';
import '../../providers/transaction_view_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/transaction_list_item.dart';

/// Dashboard screen — home tab.
///
/// Shows:
/// - [BalanceCard] with total balance and current-month income/expenses
/// - Category Spending 2-column grid (aggregated from current-month transactions)
/// - Recent Transactions list (top 10, sorted by date desc)
///
/// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Builds a [TransactionFilter] for the current calendar month.
  static TransactionFilter _currentMonthFilter() {
    final range = DateFormatter.currentMonthRange();
    return TransactionFilter(from: range.from, to: range.to);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = _currentMonthFilter();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: AppTextStyles.headlineMedium,
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardPrimary,
        onRefresh: () async {
          ref.invalidate(transactionStreamProvider(filter));
          ref.invalidate(metadataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance card
              BalanceCard(filter: filter),
              const SizedBox(height: 24),

              // Category spending grid
              _CategorySpendingSection(filter: filter),
              const SizedBox(height: 24),

              // Recent transactions
              _RecentTransactionsSection(filter: filter),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Spending Section
// ---------------------------------------------------------------------------

class _CategorySpendingSection extends ConsumerWidget {
  const _CategorySpendingSection({required this.filter});

  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAsync = ref.watch(transactionStreamProvider(filter));
    final metaAsync = ref.watch(metadataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category Spending', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        viewAsync.when(
          loading: () => _CategorySpendingLoading(),
          error: (error, _) => ErrorStateWidget(
            message: 'Failed to load spending data.',
            onRetry: () => ref.invalidate(transactionStreamProvider(filter)),
          ),
          data: (page) {
            final categories = metaAsync.value?.categories ?? [];
            final spendMap = _aggregateByCategory(page.items);

            if (spendMap.isEmpty) {
              return _EmptyState(message: 'No spending data for this month.');
            }

            // Build entries sorted by absolute spend descending
            final entries = spendMap.entries.toList()
              ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                // Resolve display name from metadata if available
                final categoryName = categories
                    .where((c) => c.id == entry.key)
                    .map((c) => c.name)
                    .firstOrNull ?? entry.key;
                return _CategorySpendCard(
                  categoryName: categoryName,
                  amount: entry.value,
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Aggregates transaction amounts by [Transaction.categoryId].
  ///
  /// Excludes pending transactions (id prefixed `"pending-"`).
  Map<String, int> _aggregateByCategory(List<Transaction> transactions) {
    final map = <String, int>{};
    for (final tx in transactions) {
      if (tx.id.startsWith('pending-')) continue;
      map[tx.categoryId] = (map[tx.categoryId] ?? 0) + tx.amount;
    }
    return map;
  }
}

class _CategorySpendCard extends StatelessWidget {
  const _CategorySpendCard({
    required this.categoryName,
    required this.amount,
  });

  final String categoryName;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final isIncome = amount > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoryName,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            CurrencyFormatter.format(amount.abs()),
            style: AppTextStyles.titleMedium.copyWith(
              color: isIncome ? AppColors.primary : AppColors.textPrimary,
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

class _CategorySpendingLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const LoadingSkeleton(
        width: double.infinity,
        height: double.infinity,
        borderRadius: AppRadius.cardBorderRadius,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Transactions Section
// ---------------------------------------------------------------------------

class _RecentTransactionsSection extends ConsumerWidget {
  const _RecentTransactionsSection({required this.filter});

  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(transactionStreamProvider(filter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Transactions', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        streamAsync.when(
          loading: () => _RecentTransactionsLoading(),
          error: (error, _) => ErrorStateWidget(
            message: 'Failed to load transactions.',
            onRetry: () => ref.invalidate(transactionStreamProvider(filter)),
          ),
          data: (page) {
            // Top 10, sorted by date descending, excluding pending
            final sorted = page.items
                .where((t) => !t.id.startsWith('pending-'))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final recent = sorted.take(10).toList();

            if (recent.isEmpty) {
              return _EmptyState(message: 'No transactions this month.');
            }

            return Container(
              decoration: BoxDecoration(
                color: AppColors.cardPrimary,
                borderRadius: AppRadius.cardBorderRadius,
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.border,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  return TransactionListItem(transaction: recent[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecentTransactionsLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const LoadingSkeleton(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    LoadingSkeleton(
                      width: 120,
                      height: 14,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(height: 6),
                    LoadingSkeleton(
                      width: 80,
                      height: 11,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const LoadingSkeleton(
                width: 60,
                height: 14,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.mutedText),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
