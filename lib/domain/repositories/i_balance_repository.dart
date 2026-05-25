import '../models/balance.dart';

/// Domain interface for balance operations.
///
/// Implementations live in `data/repositories/balance_repository_impl.dart`.
abstract interface class IBalanceRepository {
  /// Fetches the current account balance via `GET /balance`.
  ///
  /// Results are cached per [CachePolicy.balance] (30 s).
  Future<Balance> getBalance();

  /// Updates the account balance via `PATCH /account/balance`.
  ///
  /// Sends `{ "balance": amount }` and invalidates the balance cache.
  Future<Balance> updateBalance(int amount);

  /// Triggers server-side reconciliation via `POST /account/reconcile`.
  ///
  /// Called when [BalanceService.needsReconciliation] returns `true`.
  Future<void> reconcile();

  /// Updates the account timezone via `PATCH /account/timezone`.
  ///
  /// Sends `{ "timezone": ianaTimezone }` (IANA timezone string, e.g. "America/New_York").
  Future<String> updateTimezone(String ianaTimezone);
}
