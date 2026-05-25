import '../models/analytics_summary.dart';
import '../models/transaction.dart';

/// Pure domain service for computing analytics from a list of transactions.
///
/// This service has no side effects — no HTTP calls, no repository access,
/// no Riverpod dependencies. It is a pure function over its inputs.
///
/// Transactions whose [Transaction.id] starts with `"pending-"` are filtered
/// out before any computation, so optimistic UI items never skew the numbers.
class AnalyticsService {
  const AnalyticsService();

  /// Computes an [AnalyticsSummary] from [transactions].
  ///
  /// Pending transactions (id starts with `"pending-"`) are excluded.
  AnalyticsSummary compute(List<Transaction> transactions) {
    // Filter out optimistic pending transactions before any computation.
    final settled = transactions
        .where((t) => !t.id.startsWith('pending-'))
        .toList(growable: false);

    final totalIncome = settled
        .where((t) => t.amount > 0)
        .fold<int>(0, (sum, t) => sum + t.amount);

    final totalExpenses = settled
        .where((t) => t.amount < 0)
        .fold<int>(0, (sum, t) => sum + t.amount.abs());

    final netSavings = totalIncome - totalExpenses;

    final monthlyBars = _groupByMonth(settled);
    final categorySlices = _groupByCategory(settled);

    return AnalyticsSummary(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netSavings: netSavings,
      monthlyBars: monthlyBars,
      categorySlices: categorySlices,
    );
  }

  /// Groups transactions by calendar month and sums income and expenses per month.
  ///
  /// Returns one [MonthlyBar] per month that has at least one transaction,
  /// ordered chronologically.
  List<MonthlyBar> _groupByMonth(List<Transaction> transactions) {
    // Use a map keyed by "YYYY-MM" for stable ordering.
    final Map<String, _MonthAccumulator> buckets = {};

    for (final t in transactions) {
      final key =
          '${t.date.year.toString().padLeft(4, '0')}-${t.date.month.toString().padLeft(2, '0')}';
      final acc = buckets.putIfAbsent(key, () => _MonthAccumulator(t.date));
      if (t.amount > 0) {
        acc.income += t.amount;
      } else if (t.amount < 0) {
        acc.expenses += t.amount.abs();
      }
    }

    // Sort by year-month key (lexicographic == chronological for zero-padded strings).
    final sortedKeys = buckets.keys.toList()..sort();

    return sortedKeys.map((key) {
      final acc = buckets[key]!;
      return MonthlyBar(
        month: _shortMonthLabel(acc.date.month),
        income: acc.income,
        expenses: acc.expenses,
      );
    }).toList(growable: false);
  }

  /// Groups expense transactions by category and computes each category's
  /// percentage of total spend.
  ///
  /// Only negative-amount transactions are included. Returns an empty list
  /// when there are no expense transactions.
  List<CategorySlice> _groupByCategory(List<Transaction> transactions) {
    final expenses = transactions.where((t) => t.amount < 0);

    final Map<String, _CategoryAccumulator> buckets = {};
    for (final t in expenses) {
      final acc = buckets.putIfAbsent(
        t.categoryId,
        () => _CategoryAccumulator(t.categoryName),
      );
      acc.amount += t.amount.abs();
    }

    if (buckets.isEmpty) return const [];

    final totalSpend = buckets.values.fold<int>(0, (s, a) => s + a.amount);

    return buckets.values.map((acc) {
      final percentage =
          totalSpend > 0 ? (acc.amount / totalSpend) * 100.0 : 0.0;
      return CategorySlice(
        categoryName: acc.categoryName,
        amount: acc.amount,
        percentage: percentage,
      );
    }).toList(growable: false);
  }

  /// Returns the 3-letter abbreviated month name for a 1-based [month] number.
  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _shortMonthLabel(int month) => _monthLabels[month - 1];
}

// ---------------------------------------------------------------------------
// Private accumulator helpers (not part of the public API)
// ---------------------------------------------------------------------------

class _MonthAccumulator {
  _MonthAccumulator(this.date);
  final DateTime date;
  int income = 0;
  int expenses = 0;
}

class _CategoryAccumulator {
  _CategoryAccumulator(this.categoryName);
  final String categoryName;
  int amount = 0;
}
