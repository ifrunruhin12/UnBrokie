import '../models/balance.dart';
import '../models/transaction.dart';

/// Pure domain service for balance business rules.
///
/// No HTTP, no Riverpod, no UI concerns. [BalanceNotifier] delegates to this
/// service rather than implementing the reconciliation check inline.
class BalanceService {
  const BalanceService();

  /// Minimum divergence (in cents) that triggers a reconciliation request.
  static const reconcileThresholdCents = 1;

  /// Returns `true` if [balance] diverges from the sum of [transactions] by
  /// more than [reconcileThresholdCents].
  ///
  /// A divergence of exactly 1 cent does NOT trigger reconciliation; only
  /// divergences strictly greater than the threshold do.
  bool needsReconciliation(Balance balance, List<Transaction> transactions) {
    final txSum = transactions.fold<int>(0, (sum, t) => sum + t.amount);
    return (balance.amount - txSum).abs() > reconcileThresholdCents;
  }
}
