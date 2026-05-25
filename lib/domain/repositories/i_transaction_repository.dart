import '../models/transaction.dart';

/// Domain interface for transaction operations.
///
/// Implementations live in `data/repositories/transaction_repository_impl.dart`.
abstract interface class ITransactionRepository {
  /// Fetches a paginated page of transactions via `GET /transactions`.
  ///
  /// [from] and [to] are ISO 8601 date strings ("YYYY-MM-DD") sent as RFC3339
  /// to the API. [cursorDate] and [cursorId] are the two separate cursor query
  /// params from the previous page's `next_cursor` field.
  ///
  /// Results are cached per [CachePolicy.transactions] (30 s).
  Future<TransactionPage> getTransactions({
    String? cursorDate,
    String? cursorId,
    int limit = 50,
    required String from,
    required String to,
    String? categoryId,
  });

  /// Creates a new transaction via `POST /transactions`.
  ///
  /// Invalidates the transactions cache and the balance cache on success.
  Future<Transaction> createTransaction(CreateTransactionInput input);

  /// Overrides the amount and/or note of a transaction via
  /// `PATCH /transactions/:id/override`.
  ///
  /// Invalidates the transactions cache and the balance cache on success.
  Future<Transaction> overrideTransaction(
    String id, {
    int? amount,
    String? note,
  });

  /// Marks a transaction as skipped via `PATCH /transactions/:id/skip`.
  ///
  /// Invalidates the transactions cache and the balance cache on success.
  Future<Transaction> skipTransaction(String id);

  /// Restores a previously skipped transaction via
  /// `PATCH /transactions/:id/restore`.
  ///
  /// Invalidates the transactions cache and the balance cache on success.
  Future<Transaction> restoreTransaction(String id);

  /// Fetches the audit history for a single transaction via
  /// `GET /transactions/:id/history`.
  Future<List<Transaction>> getTransactionHistory(String id);
}
