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
import '../../widgets/add_transaction_sheet.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/transaction_list_item.dart';

/// Calendar screen — monthly calendar view with daily spend and day detail.
///
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _displayedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _selectedDay = null;
  }

  TransactionFilter _filterForMonth(DateTime month) {
    final range = DateFormatter.monthRange(month.year, month.month);
    return TransactionFilter(from: range.from, to: range.to);
  }

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
      _selectedDay = null;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
      _selectedDay = null;
    });
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      _selectedDay = _selectedDay != null &&
              _selectedDay!.year == day.year &&
              _selectedDay!.month == day.month &&
              _selectedDay!.day == day.day
          ? null
          : day;
    });
  }

  Future<void> _openAddTransactionSheet() async {
    final filter = _filterForMonth(_displayedMonth);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => AddTransactionSheet(
        filter: filter,
        initialDate: _selectedDay ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filterForMonth(_displayedMonth);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Calendar', style: AppTextStyles.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_calendar',
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
          ref.invalidate(transactionStreamProvider(filter));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month navigation header (Req 7.2)
              _MonthNavigationHeader(
                displayedMonth: _displayedMonth,
                onPrevious: _goToPreviousMonth,
                onNext: _goToNextMonth,
              ),

              const SizedBox(height: 8),

              // Calendar grid with week summary (Req 7.1, 7.2)
              _CalendarSection(
                filter: filter,
                displayedMonth: _displayedMonth,
                selectedDay: _selectedDay,
                onDayTapped: _onDayTapped,
              ),

              const SizedBox(height: 16),

              // Category filter chips (Req 7.4)
              _CategoryFilterChips(filter: filter),

              const SizedBox(height: 16),

              // Day detail list (Req 7.3)
              if (_selectedDay != null)
                _DayDetailList(
                  filter: filter,
                  selectedDay: _selectedDay!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month Navigation Header
// ---------------------------------------------------------------------------

/// Displays "← Month Year →" navigation controls (Req 7.2).
class _MonthNavigationHeader extends StatelessWidget {
  const _MonthNavigationHeader({
    required this.displayedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime displayedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormatter.monthYearLabel(displayedMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(
              Icons.chevron_left,
              color: AppColors.textPrimary,
              size: 28,
            ),
            tooltip: 'Previous month',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Text(
            label,
            style: AppTextStyles.headlineMedium,
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_right,
              color: AppColors.textPrimary,
              size: 28,
            ),
            tooltip: 'Next month',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar Section (week summary + grid)
// ---------------------------------------------------------------------------

/// Renders the week summary row and the 7-column calendar grid (Req 7.1, 7.2).
class _CalendarSection extends ConsumerWidget {
  const _CalendarSection({
    required this.filter,
    required this.displayedMonth,
    required this.selectedDay,
    required this.onDayTapped,
  });

  final TransactionFilter filter;
  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(transactionStreamProvider(filter));

    return streamAsync.when(
      loading: () => _CalendarLoading(displayedMonth: displayedMonth),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ErrorStateWidget(
          message: 'Failed to load calendar data.',
          onRetry: () => ref.invalidate(transactionStreamProvider(filter)),
        ),
      ),
      data: (page) {
        // Build a map of day → total spend (sum of amounts on that date)
        final spendByDay = _buildSpendByDay(page.items);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardPrimary,
              borderRadius: AppRadius.cardBorderRadius,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                // Weekday header row
                _WeekdayHeaderRow(),

                const Divider(height: 1, color: AppColors.border),

                // Week summary row (Req 7.2)
                _WeekSummaryRow(
                  displayedMonth: displayedMonth,
                  selectedDay: selectedDay,
                  spendByDay: spendByDay,
                ),

                const Divider(height: 1, color: AppColors.border),

                // Calendar grid
                _CalendarGrid(
                  displayedMonth: displayedMonth,
                  selectedDay: selectedDay,
                  spendByDay: spendByDay,
                  onDayTapped: onDayTapped,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Aggregates transaction amounts by calendar day.
  ///
  /// Excludes pending transactions (id prefixed `"pending-"`).
  Map<int, int> _buildSpendByDay(List<Transaction> transactions) {
    final map = <int, int>{};
    for (final tx in transactions) {
      if (tx.id.startsWith('pending-')) continue;
      final localDate = tx.date.toLocal();
      // Only include transactions in the displayed month
      if (localDate.year == displayedMonth.year &&
          localDate.month == displayedMonth.month) {
        map[localDate.day] = (map[localDate.day] ?? 0) + tx.amount;
      }
    }
    return map;
  }
}

// ---------------------------------------------------------------------------
// Weekday Header Row
// ---------------------------------------------------------------------------

class _WeekdayHeaderRow extends StatelessWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: _weekdays.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week Summary Row
// ---------------------------------------------------------------------------

/// Shows the total spend for the currently selected week (or current week
/// if no day is selected). (Req 7.2)
class _WeekSummaryRow extends StatelessWidget {
  const _WeekSummaryRow({
    required this.displayedMonth,
    required this.selectedDay,
    required this.spendByDay,
  });

  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final Map<int, int> spendByDay;

  /// Returns the week (Mon–Sun) containing [day].
  List<int> _weekDaysFor(DateTime day) {
    // weekday: 1=Mon, 7=Sun
    final startOfWeek = day.subtract(Duration(days: day.weekday - 1));
    return List.generate(7, (i) {
      final d = startOfWeek.add(Duration(days: i));
      if (d.month == displayedMonth.month) return d.day;
      return -1; // outside current month
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use selected day's week, or current week if in this month, else first week
    final now = DateTime.now();
    DateTime referenceDay;
    if (selectedDay != null) {
      referenceDay = selectedDay!;
    } else if (now.year == displayedMonth.year &&
        now.month == displayedMonth.month) {
      referenceDay = now;
    } else {
      referenceDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    }

    final weekDays = _weekDaysFor(referenceDay);
    final weekTotal = weekDays
        .where((d) => d > 0)
        .fold(0, (sum, d) => sum + (spendByDay[d] ?? 0));

    final isExpense = weekTotal < 0;
    final isIncome = weekTotal > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Week Total',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            weekTotal == 0
                ? '—'
                : (isIncome ? '+' : '-') +
                    CurrencyFormatter.format(weekTotal.abs()),
            style: AppTextStyles.bodySmall.copyWith(
              color: isIncome
                  ? AppColors.primary
                  : isExpense
                      ? AppColors.textPrimary
                      : AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar Grid
// ---------------------------------------------------------------------------

/// 7-column grid of [_DayCell] widgets for the displayed month (Req 7.1).
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.displayedMonth,
    required this.selectedDay,
    required this.spendByDay,
    required this.onDayTapped,
  });

  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final Map<int, int> spendByDay;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context) {
    // First day of month (weekday: 1=Mon, 7=Sun)
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    // Days in month
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;

    // Leading empty cells (Mon=0 offset, Tue=1, ..., Sun=6)
    final leadingBlanks = firstDay.weekday - 1;

    // Total cells = leading blanks + days in month
    final totalCells = leadingBlanks + daysInMonth;
    // Round up to full weeks
    final totalRows = (totalCells / 7).ceil();
    final gridCells = totalRows * 7;

    final today = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.75,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: gridCells,
      itemBuilder: (context, index) {
        final dayNumber = index - leadingBlanks + 1;

        // Blank cell before the first day or after the last day
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final cellDate = DateTime(
          displayedMonth.year,
          displayedMonth.month,
          dayNumber,
        );

        final isToday = today.year == cellDate.year &&
            today.month == cellDate.month &&
            today.day == cellDate.day;

        final isSelected = selectedDay != null &&
            selectedDay!.year == cellDate.year &&
            selectedDay!.month == cellDate.month &&
            selectedDay!.day == cellDate.day;

        final spend = spendByDay[dayNumber];

        return _DayCell(
          day: dayNumber,
          date: cellDate,
          spend: spend,
          isToday: isToday,
          isSelected: isSelected,
          onTap: () => onDayTapped(cellDate),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day Cell
// ---------------------------------------------------------------------------

/// A single cell in the calendar grid showing day number + spend (Req 7.1).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.spend,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final DateTime date;
  final int? spend;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSpend = spend != null && spend != 0;
    final isIncome = (spend ?? 0) > 0;

    Color bgColor = Colors.transparent;
    Color dayNumberColor = AppColors.textPrimary;

    if (isSelected) {
      bgColor = AppColors.primary.withAlpha(40);
      dayNumberColor = AppColors.primary;
    } else if (isToday) {
      bgColor = AppColors.cardSecondary;
      dayNumberColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : isToday
                  ? Border.all(color: AppColors.primary.withAlpha(80), width: 1)
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day number
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: dayNumberColor,
              ),
            ),

            // Spend amount (shown only if non-zero)
            if (hasSpend) ...[
              const SizedBox(height: 2),
              Text(
                _formatSpend(spend!),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isIncome ? AppColors.primary : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(height: 2),
              const SizedBox(height: 11), // placeholder to keep height stable
            ],
          ],
        ),
      ),
    );
  }

  /// Formats spend as a compact string (e.g. "1.2k", "-500").
  String _formatSpend(int amount) {
    final abs = amount.abs();
    final prefix = amount < 0 ? '-' : '+';
    if (abs >= 100000) {
      return '$prefix${(abs / 100).round() ~/ 10}k';
    }
    return '$prefix${CurrencyFormatter.format(abs)}';
  }
}

// ---------------------------------------------------------------------------
// Calendar Loading Skeleton
// ---------------------------------------------------------------------------

class _CalendarLoading extends StatelessWidget {
  const _CalendarLoading({required this.displayedMonth});

  final DateTime displayedMonth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardPrimary,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Weekday header skeleton
            Row(
              children: List.generate(
                7,
                (_) => Expanded(
                  child: Center(
                    child: LoadingSkeleton(
                      width: 24,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Grid skeleton rows
            ...List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: List.generate(
                    7,
                    (_) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LoadingSkeleton(
                          width: double.infinity,
                          height: 44,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Filter Chips
// ---------------------------------------------------------------------------

/// Horizontal scrolling category filter chips (Req 7.4).
///
/// Selecting a chip calls [transactionViewProvider.setCategoryFilter].
class _CategoryFilterChips extends ConsumerWidget {
  const _CategoryFilterChips({required this.filter});

  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(metadataProvider);
    final viewState = ref.watch(transactionViewProvider(filter));
    final categories = metaAsync.value?.categories ?? [];

    if (categories.isEmpty && !metaAsync.isLoading) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: metaAsync.isLoading
          ? ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => LoadingSkeleton(
                width: 72,
                height: 32,
                borderRadius: AppRadius.pillBorderRadius,
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // "All" chip
                _FilterChip(
                  label: 'All',
                  selected: viewState.categoryFilter == null,
                  onTap: () => ref
                      .read(transactionViewProvider(filter).notifier)
                      .setCategoryFilter(null),
                ),
                const SizedBox(width: 8),
                ...categories.map((cat) {
                  final isSelected =
                      viewState.categoryFilter == cat.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: cat.name,
                      selected: isSelected,
                      onTap: () => ref
                          .read(transactionViewProvider(filter).notifier)
                          .setCategoryFilter(isSelected ? null : cat.name),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
// Day Detail List
// ---------------------------------------------------------------------------

/// Shows transactions for the selected day below the calendar grid (Req 7.3).
///
/// Watches [transactionViewProvider] (which applies the active category filter)
/// and filters to the selected day.
class _DayDetailList extends ConsumerWidget {
  const _DayDetailList({
    required this.filter,
    required this.selectedDay,
  });

  final TransactionFilter filter;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(transactionViewProvider(filter));
    final streamAsync = ref.watch(transactionStreamProvider(filter));

    // Filter to selected day
    final dayTransactions = viewState.filtered.where((tx) {
      final local = tx.date.toLocal();
      return local.year == selectedDay.year &&
          local.month == selectedDay.month &&
          local.day == selectedDay.day;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final dayLabel = DateFormatter.transactionDateLabel(selectedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayLabel,
                style: AppTextStyles.headlineMedium,
              ),
              if (streamAsync.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (dayTransactions.isEmpty)
            _EmptyDayState()
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardPrimary,
                borderRadius: AppRadius.cardBorderRadius,
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayTransactions.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.border,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  return TransactionListItem(
                    transaction: dayTransactions[index],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDayState extends StatelessWidget {
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
          const Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: AppColors.mutedText,
          ),
          const SizedBox(height: 8),
          Text(
            'No transactions on this day.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
