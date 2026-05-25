import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/transaction_filter.dart';
import '../../providers/metadata_provider.dart';
import '../../providers/transaction_stream_provider.dart';
import '../../providers/transaction_view_provider.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/transaction_list_item.dart';
import '../../widgets/add_transaction_sheet.dart';
import 'transaction_detail_sheet.dart';

/// History screen — transaction list with search, filter, and infinite scroll.
///
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late TransactionFilter _filter;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filter = _defaultFilter();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static TransactionFilter _defaultFilter() {
    final range = DateFormatter.currentMonthRange();
    return TransactionFilter(from: range.from, to: range.to);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionStreamProvider(_filter).notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    ref.read(transactionViewProvider(_filter).notifier).setSearch(query);
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => _FilterBottomSheet(currentFilter: _filter),
    );

    if (result == null) return;

    // Date range change → new TransactionFilter key (triggers new provider instance)
    if (result.newDateRange != null) {
      setState(() {
        _filter = TransactionFilter(
          from: result.newDateRange!.from,
          to: result.newDateRange!.to,
          categoryId: _filter.categoryId,
        );
      });
    }

    // Category filter → client-side filter via transactionViewProvider
    if (result.categoryName != null || result.clearCategory) {
      ref
          .read(transactionViewProvider(_filter).notifier)
          .setCategoryFilter(result.clearCategory ? null : result.categoryName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('History', style: AppTextStyles.headlineMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search transactions…',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.mutedText,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.mutedText,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.cardSecondary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.inputBorderRadius,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.inputBorderRadius,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.inputBorderRadius,
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(onTap: _openFilterSheet),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_history',
        onPressed: _openAddTransactionSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardPrimary,
        onRefresh: () async {
          ref.invalidate(transactionStreamProvider(_filter));
        },
        child: _GroupedTransactionList(
          filter: _filter,
          scrollController: _scrollController,
        ),
      ),
    );
  }

  Future<void> _openAddTransactionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => AddTransactionSheet(filter: _filter),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter button
// ---------------------------------------------------------------------------

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSecondary,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: const Icon(
            Icons.tune_rounded,
            color: AppColors.mutedText,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped transaction list
// ---------------------------------------------------------------------------

class _GroupedTransactionList extends ConsumerWidget {
  const _GroupedTransactionList({
    required this.filter,
    required this.scrollController,
  });

  final TransactionFilter filter;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(transactionStreamProvider(filter));
    final viewState = ref.watch(transactionViewProvider(filter));

    return streamAsync.when(
      loading: () => _TransactionListLoading(),
      error: (error, _) => ErrorStateWidget(
        message: 'Failed to load transactions.',
        onRetry: () => ref.invalidate(transactionStreamProvider(filter)),
      ),
      data: (page) {
        final transactions = viewState.filtered;

        if (transactions.isEmpty) {
          return _EmptyState(
            message: viewState.searchQuery.isNotEmpty ||
                    viewState.categoryFilter != null
                ? 'No transactions match your filters.'
                : 'No transactions found.',
          );
        }

        // Group transactions by calendar date
        final groups = _groupByDate(transactions);
        final dateKeys = groups.keys.toList();

        // Build flat list: [header, item, item, ..., header, item, ...]
        // Plus a loading-more indicator at the bottom
        final hasMore =
            page.nextCursorDate != null || page.nextCursorId != null;

        return ListView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _totalItemCount(groups, dateKeys) + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Loading more indicator at the very bottom
            if (hasMore &&
                index == _totalItemCount(groups, dateKeys)) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            // Map flat index to (groupIndex, itemIndex)
            final (groupIndex, itemIndex) =
                _resolveIndex(groups, dateKeys, index);

            if (itemIndex == -1) {
              // This is a date header
              final dateKey = dateKeys[groupIndex];
              return _DateGroupHeader(label: dateKey);
            }

            final tx = groups[dateKeys[groupIndex]]![itemIndex];
            return TransactionListItem(
              transaction: tx,
              onTap: () => _openDetail(context, ref, tx, filter),
            );
          },
        );
      },
    );
  }

  /// Groups transactions by their local calendar date label.
  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final groups = <String, List<Transaction>>{};
    for (final tx in transactions) {
      final label = DateFormatter.transactionDateLabel(tx.date);
      groups.putIfAbsent(label, () => []).add(tx);
    }
    return groups;
  }

  /// Total number of list items (headers + transaction rows).
  int _totalItemCount(
    Map<String, List<Transaction>> groups,
    List<String> dateKeys,
  ) {
    var count = 0;
    for (final key in dateKeys) {
      count += 1 + (groups[key]?.length ?? 0); // 1 header + N items
    }
    return count;
  }

  /// Resolves a flat [index] to (groupIndex, itemIndex).
  ///
  /// Returns itemIndex == -1 when the index points to a group header.
  (int groupIndex, int itemIndex) _resolveIndex(
    Map<String, List<Transaction>> groups,
    List<String> dateKeys,
    int index,
  ) {
    var cursor = 0;
    for (var g = 0; g < dateKeys.length; g++) {
      if (cursor == index) return (g, -1); // header
      cursor++;
      final items = groups[dateKeys[g]]!;
      for (var i = 0; i < items.length; i++) {
        if (cursor == index) return (g, i);
        cursor++;
      }
    }
    return (0, -1);
  }

  void _openDetail(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    TransactionFilter filter,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        filter: filter,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date group header
// ---------------------------------------------------------------------------

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bottom sheet
// ---------------------------------------------------------------------------

/// Result returned by [_FilterBottomSheet].
class _FilterResult {
  const _FilterResult({
    this.newDateRange,
    this.categoryName,
    this.clearCategory = false,
  });

  final ({String from, String to})? newDateRange;
  final String? categoryName;
  final bool clearCategory;
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  const _FilterBottomSheet({required this.currentFilter});

  final TransactionFilter currentFilter;

  @override
  ConsumerState<_FilterBottomSheet> createState() =>
      _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  late DateTime _fromDate;
  late DateTime _toDate;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.parse(widget.currentFilter.from);
    _toDate = DateTime.parse(widget.currentFilter.to);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.cardPrimary,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.cardPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _applyFilters() {
    final fromStr = DateFormatter.toRfc3339(_fromDate);
    final toStr = DateFormatter.toRfc3339(_toDate);

    final currentFrom = widget.currentFilter.from;
    final currentTo = widget.currentFilter.to;

    final dateChanged = fromStr != currentFrom || toStr != currentTo;

    Navigator.of(context).pop(
      _FilterResult(
        newDateRange: dateChanged ? (from: fromStr, to: toStr) : null,
        categoryName: _selectedCategoryName,
        clearCategory: _selectedCategoryName == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(metadataProvider);
    final categories = metaAsync.value?.categories ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter', style: AppTextStyles.headlineMedium),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        final range = DateFormatter.currentMonthRange();
                        _fromDate = DateTime.parse(range.from);
                        _toDate = DateTime.parse(range.to);
                        _selectedCategoryName = null;
                      });
                    },
                    child: Text(
                      'Reset',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Date range section
                  Text(
                    'DATE RANGE',
                    style: AppTextStyles.labelSmall.copyWith(
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DateRangeTile(
                    fromDate: _fromDate,
                    toDate: _toDate,
                    onTap: _pickDateRange,
                  ),
                  const SizedBox(height: 24),

                  // Category section
                  Text(
                    'CATEGORY',
                    style: AppTextStyles.labelSmall.copyWith(
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (metaAsync.isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // "All" chip
                        _CategoryFilterChip(
                          label: 'All',
                          selected: _selectedCategoryName == null,
                          onTap: () =>
                              setState(() => _selectedCategoryName = null),
                        ),
                        ...categories.map(
                          (cat) => _CategoryFilterChip(
                            label: cat.name,
                            selected: _selectedCategoryName == cat.name,
                            onTap: () => setState(
                              () => _selectedCategoryName = cat.name,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Apply button
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorderRadius,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DateRangeTile extends StatelessWidget {
  const _DateRangeTile({
    required this.fromDate,
    required this.toDate,
    required this.onTap,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    return '${DateFormatter.monthAbbr(date)} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSecondary,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.mutedText,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_formatDate(fromDate)}  →  ${_formatDate(toDate)}',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(40)
              : AppColors.cardSecondary,
          borderRadius: AppRadius.pillBorderRadius,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.primary : AppColors.mutedText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _TransactionListLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 12,
      itemBuilder: (_, index) {
        // Every 4th item is a "date header" skeleton
        if (index % 4 == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: LoadingSkeleton(
              width: 80,
              height: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const LoadingSkeleton(
                width: 44,
                height: 44,
                borderRadius:
                    BorderRadius.all(Radius.circular(AppRadius.medium)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(
                      width: 130,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    LoadingSkeleton(
                      width: 90,
                      height: 11,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LoadingSkeleton(
                width: 60,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
