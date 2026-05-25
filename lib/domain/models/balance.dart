/// Represents the user's current account balance.
///
/// [amount] is in the smallest currency unit (e.g. cents).
/// Total income and total expenses are NOT part of this model — they are
/// computed client-side from the transaction list by [AnalyticsService].
///
/// JSON parsing is handled in `data/json/balance_json.dart`.
class Balance {
  const Balance({required this.amount});

  /// Current balance in the smallest currency unit (cents).
  final int amount;
}
