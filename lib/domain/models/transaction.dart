/// Lifecycle status of a transaction.
enum TransactionStatus { active, skipped, overridden, pending }

/// A single financial record.
///
/// [amount] is negative for expenses and positive for income.
/// JSON parsing is handled in `data/json/transaction_json.dart`.
class Transaction {
  const Transaction({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.date,
    this.note,
    required this.status,
  });

  final String id;
  final String categoryId;
  final String categoryName;

  /// Negative = expense, positive = income (in smallest currency unit).
  final int amount;

  final DateTime date;
  final String? note;
  final TransactionStatus status;
}

/// A paginated page of [Transaction] items.
///
/// [nextCursorDate] and [nextCursorId] are `null` when there are no more pages.
class TransactionPage {
  const TransactionPage({
    required this.items,
    this.nextCursorDate,
    this.nextCursorId,
  });

  final List<Transaction> items;

  /// RFC3339 date string from `next_cursor.date` in the API response.
  final String? nextCursorDate;

  /// UUID string from `next_cursor.id` in the API response.
  final String? nextCursorId;
}

/// Input payload for creating a new transaction via `POST /transactions`.
class CreateTransactionInput {
  const CreateTransactionInput({
    required this.categoryId,
    required this.amount,
    required this.date,
    this.note,
  });

  final String categoryId;
  final int amount;
  final DateTime date;
  final String? note;
}
