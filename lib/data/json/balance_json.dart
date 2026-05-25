import '../../domain/models/balance.dart';

/// JSON serialization extension for [Balance].
///
/// API response shape (after envelope unwrap):
/// ```json
/// { "balance": 12345 }
/// ```
///
/// Note: income and expense totals are NOT part of this model — they are
/// computed client-side from the transaction list by [AnalyticsService].
extension BalanceJson on Balance {
  /// Deserializes a [Balance] from the API response JSON.
  ///
  /// Reads the integer balance from the `balance` key.
  static Balance fromJson(Map<String, dynamic> json) {
    return Balance(amount: (json['balance'] ?? json['Balance'] ?? 0) as int);
  }

  /// Serializes this [Balance] to a JSON map.
  Map<String, dynamic> toJson() => {'balance': amount};
}
