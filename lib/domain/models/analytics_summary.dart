/// Client-side computed analytics summary for a given time period.
///
/// Computed by [AnalyticsService.compute] from a list of [Transaction]s.
/// There is no analytics endpoint on the backend — all values are derived
/// client-side.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netSavings,
    required this.monthlyBars,
    required this.categorySlices,
  });

  /// Sum of all positive transaction amounts (in smallest currency unit).
  final int totalIncome;

  /// Sum of absolute values of all negative transaction amounts.
  final int totalExpenses;

  /// [totalIncome] − [totalExpenses].
  final int netSavings;

  final List<MonthlyBar> monthlyBars;
  final List<CategorySlice> categorySlices;
}

/// Income and expense totals for a single calendar month.
class MonthlyBar {
  const MonthlyBar({
    required this.month,
    required this.income,
    required this.expenses,
  });

  /// Short month label, e.g. "Jan", "Feb", …
  final String month;

  /// Total income for this month (in smallest currency unit).
  final int income;

  /// Total expenses for this month (absolute value, in smallest currency unit).
  final int expenses;
}

/// Spending breakdown for a single category.
class CategorySlice {
  const CategorySlice({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  final String categoryName;

  /// Total amount spent in this category (in smallest currency unit).
  final int amount;

  /// Percentage of total spend represented by this category (0–100).
  final double percentage;
}
