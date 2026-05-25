import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/analytics_summary.dart';
import '../../../domain/models/transaction_filter.dart';
import '../../providers/analytics_provider.dart';
import '../../widgets/chart_wrapper.dart';
import '../../widgets/stat_card.dart';

// ---------------------------------------------------------------------------
// Period enum
// ---------------------------------------------------------------------------

/// The three selectable time periods for the analytics screen.
enum _Period {
  thisMonth('This Month'),
  last3Months('Last 3 Months'),
  thisYear('This Year');

  const _Period(this.label);
  final String label;
}

// ---------------------------------------------------------------------------
// Analytics Screen
// ---------------------------------------------------------------------------

/// Analytics screen — period selector, stat cards, bar chart, pie chart.
///
/// Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Period _selectedPeriod = _Period.thisMonth;

  /// Builds a [TransactionFilter] for the given [period].
  static TransactionFilter _filterForPeriod(_Period period) {
    final now = DateTime.now();
    switch (period) {
      case _Period.thisMonth:
        final range = DateFormatter.currentMonthRange();
        return TransactionFilter(from: range.from, to: range.to);
      case _Period.last3Months:
        // From 3 months ago (start of that month) to end of current month
        final startMonth = DateTime(now.year, now.month - 2, 1);
        final rangeStart = DateFormatter.monthRange(
          startMonth.year,
          startMonth.month,
        );
        final rangeEnd = DateFormatter.currentMonthRange();
        return TransactionFilter(from: rangeStart.from, to: rangeEnd.to);
      case _Period.thisYear:
        final yearStart = DateTime.utc(now.year, 1, 1);
        final yearEnd = DateTime.utc(now.year, 12, 31, 23, 59, 59, 999);
        return TransactionFilter(
          from: DateFormatter.toRfc3339(yearStart),
          to: DateFormatter.toRfc3339(yearEnd),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filterForPeriod(_selectedPeriod);
    final analyticsAsync = ref.watch(analyticsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Analytics', style: AppTextStyles.headlineMedium),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardPrimary,
        onRefresh: () async {
          ref.invalidate(analyticsProvider(filter));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period selector (Req 8.1)
              _PeriodSelector(
                selected: _selectedPeriod,
                onChanged: (period) => setState(() {
                  _selectedPeriod = period;
                }),
              ),
              const SizedBox(height: 20),

              // Stat cards row (Req 8.2)
              _StatCardsRow(analyticsAsync: analyticsAsync),
              const SizedBox(height: 20),

              // Monthly Overview bar chart (Req 8.3)
              _MonthlyOverviewChart(analyticsAsync: analyticsAsync),
              const SizedBox(height: 20),

              // Spending by Category pie/donut chart (Req 8.4, 8.5)
              _SpendingByCategoryChart(analyticsAsync: analyticsAsync),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period Selector
// ---------------------------------------------------------------------------

/// Horizontal row of period selector chips (Req 8.1).
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final _Period selected;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _Period.values.map((period) {
        final isSelected = period == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: period != _Period.values.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(40)
                      : AppColors.cardPrimary,
                  borderRadius: AppRadius.pillBorderRadius,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    period.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.mutedText,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Cards Row
// ---------------------------------------------------------------------------

/// Three [StatCard] widgets: Total Income, Total Expenses, Net Savings (Req 8.2).
class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({required this.analyticsAsync});

  final AsyncValue<AnalyticsSummary> analyticsAsync;

  @override
  Widget build(BuildContext context) {
    final summary = analyticsAsync.value;
    final isLoading = analyticsAsync.isLoading;

    // Show zero values while loading so layout is stable
    final totalIncome = summary?.totalIncome ?? 0;
    final totalExpenses = summary?.totalExpenses ?? 0;
    final netSavings = summary?.netSavings ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCardWithLoading(
            label: 'Total Income',
            amount: totalIncome,
            color: AppColors.primary,
            isLoading: isLoading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCardWithLoading(
            label: 'Total Expenses',
            amount: totalExpenses,
            color: AppColors.textPrimary,
            isLoading: isLoading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCardWithLoading(
            label: 'Net Savings',
            amount: netSavings,
            color: netSavings >= 0 ? AppColors.primary : AppColors.error,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}

class _StatCardWithLoading extends StatelessWidget {
  const _StatCardWithLoading({
    required this.label,
    required this.amount,
    required this.color,
    required this.isLoading,
  });

  final String label;
  final int amount;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StatCard(label: label, amount: amount, color: color),
        if (isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardPrimary.withAlpha(160),
                borderRadius: AppRadius.cardBorderRadius,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly Overview Bar Chart
// ---------------------------------------------------------------------------

/// Bar chart showing income and expenses per month (Req 8.3).
class _MonthlyOverviewChart extends StatelessWidget {
  const _MonthlyOverviewChart({required this.analyticsAsync});

  final AsyncValue<AnalyticsSummary> analyticsAsync;

  @override
  Widget build(BuildContext context) {
    final isLoading = analyticsAsync.isLoading;
    final bars = analyticsAsync.value?.monthlyBars ?? [];

    return ChartWrapper(
      title: 'Monthly Overview',
      isLoading: isLoading,
      child: bars.isEmpty && !isLoading
          ? _EmptyChartState(message: 'No monthly data available.')
          : SizedBox(
              height: 200,
              child: _MonthlyBarChart(bars: bars),
            ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.bars});

  final List<MonthlyBar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find max value for Y axis scaling
    final maxVal = bars.fold<int>(
      0,
      (max, b) => b.income > max
          ? (b.expenses > b.income ? b.expenses : b.income)
          : (b.expenses > max ? b.expenses : max),
    );
    final yMax = maxVal == 0 ? 100.0 : (maxVal * 1.2).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.cardPrimary,
            tooltipBorder: const BorderSide(color: AppColors.border),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final bar = bars[groupIndex];
              final isIncome = rodIndex == 0;
              final label = isIncome ? 'Income' : 'Expenses';
              final amount = isIncome ? bar.income : bar.expenses;
              return BarTooltipItem(
                '$label\n${CurrencyFormatter.format(amount)}',
                AppTextStyles.bodySmall.copyWith(
                  color: isIncome ? AppColors.primary : AppColors.textPrimary,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= bars.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    bars[index].month,
                    style: AppTextStyles.labelSmall,
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(bars.length, (index) {
          final bar = bars[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              // Income bar (teal)
              BarChartRodData(
                toY: bar.income.toDouble(),
                color: AppColors.primary,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              // Expense bar (white/muted)
              BarChartRodData(
                toY: bar.expenses.toDouble(),
                color: AppColors.mutedText,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
            barsSpace: 4,
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spending by Category Pie/Donut Chart
// ---------------------------------------------------------------------------

/// Donut chart showing spending breakdown by category (Req 8.4, 8.5).
class _SpendingByCategoryChart extends StatelessWidget {
  const _SpendingByCategoryChart({required this.analyticsAsync});

  final AsyncValue<AnalyticsSummary> analyticsAsync;

  @override
  Widget build(BuildContext context) {
    final isLoading = analyticsAsync.isLoading;
    final slices = analyticsAsync.value?.categorySlices ?? [];

    return ChartWrapper(
      title: 'Spending by Category',
      isLoading: isLoading,
      child: slices.isEmpty && !isLoading
          ? _EmptyChartState(message: 'No category data available.')
          : _DonutChartWithLegend(slices: slices),
    );
  }
}

class _DonutChartWithLegend extends StatelessWidget {
  const _DonutChartWithLegend({required this.slices});

  final List<CategorySlice> slices;

  /// Palette of colors for the pie slices.
  static const _sliceColors = [
    AppColors.primary,
    Color(0xFF6366F1), // indigo
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFF06B6D4), // cyan
    Color(0xFFF97316), // orange
    Color(0xFF10B981), // emerald
  ];

  Color _colorForIndex(int index) =>
      _sliceColors[index % _sliceColors.length];

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: List.generate(slices.length, (index) {
                final slice = slices[index];
                return PieChartSectionData(
                  value: slice.percentage,
                  color: _colorForIndex(index),
                  radius: 50,
                  title: '',
                  showTitle: false,
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        _CategoryLegend(slices: slices, colorForIndex: _colorForIndex),
      ],
    );
  }
}

/// Legend rows: color dot + category name + percentage (Req 8.5).
class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({
    required this.slices,
    required this.colorForIndex,
  });

  final List<CategorySlice> slices;
  final Color Function(int index) colorForIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(slices.length, (index) {
        final slice = slices[index];
        final color = colorForIndex(index);
        final pct = slice.percentage.toStringAsFixed(1);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Color dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Category name
              Expanded(
                child: Text(
                  slice.categoryName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Percentage
              Text(
                '$pct%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty state for charts
// ---------------------------------------------------------------------------

class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bar_chart_outlined,
              size: 36,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
