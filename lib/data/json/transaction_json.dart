import '../../domain/models/transaction.dart';

/// JSON serialization extension for [Transaction], [TransactionPage],
/// and [CreateTransactionInput].
///
/// List API response shape (after envelope unwrap):
/// ```json
/// {
///   "transactions": [...],
///   "next_cursor": { "date": "RFC3339", "id": "uuid" } | null
/// }
/// ```
///
/// Single-item response shape (POST/PATCH):
/// ```json
/// { "transaction": { ... } }
/// ```
///
/// Transaction object shape:
/// ```json
/// {
///   "id": "uuid",
///   "category_id": "uuid",
///   "category_name": "string",
///   "amount": 1234,
///   "date": "RFC3339",
///   "note": "string | null",
///   "status": "active" | "skipped" | "overridden"
/// }
/// ```
extension TransactionJson on Transaction {
  /// Deserializes a single [Transaction] from a JSON object.
  static Transaction fromJsonObject(Map<String, dynamic> json) {
    return Transaction(
      id: (json['id'] ?? json['ID'] ?? '') as String,
      categoryId: (json['category_id'] ?? json['CategoryID'] ?? '') as String,
      categoryName: (json['category_name'] ?? json['CategoryName'] ?? '') as String,
      amount: (json['amount'] ?? json['Amount'] ?? 0) as int,
      date: DateTime.parse((json['date'] ?? json['Date'] ?? json['CreatedAt']) as String),
      note: (json['note'] ?? json['Note']) as String?,
      status: _statusFromString((json['status'] ?? json['Status'] ?? 'active') as String),
    );
  }

  /// Deserializes a [TransactionPage] from the list API response JSON.
  ///
  /// Reads the transaction array from the `transactions` key (not `items`).
  /// Reads pagination cursors from `next_cursor.date` and `next_cursor.id`
  /// (null-safe — both are null when there are no more pages).
  static TransactionPage fromJson(Map<String, dynamic> json) {
    final rawList = (json['transactions'] as List<dynamic>?) ?? [];
    final items = rawList
        .map((e) => fromJsonObject(e as Map<String, dynamic>))
        .toList();

    final nextCursor = (json['next_cursor'] ?? json['NextCursor']) as Map<String, dynamic>?;
    final nextCursorDate = nextCursor?['date'] as String? ?? nextCursor?['Date'] as String?;
    final nextCursorId = nextCursor?['id'] as String? ?? nextCursor?['ID'] as String?;

    return TransactionPage(
      items: items,
      nextCursorDate: nextCursorDate,
      nextCursorId: nextCursorId,
    );
  }

  /// Serializes this [Transaction] to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'category_name': categoryName,
        'amount': amount,
        'date': date.toUtc().toIso8601String(),
        'note': note,
        'status': _statusToString(status),
      };

  static TransactionStatus _statusFromString(String value) {
    switch (value) {
      case 'active':
        return TransactionStatus.active;
      case 'skipped':
        return TransactionStatus.skipped;
      case 'overridden':
        return TransactionStatus.overridden;
      case 'pending':
        return TransactionStatus.pending;
      default:
        return TransactionStatus.active;
    }
  }

  static String _statusToString(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.active:
        return 'active';
      case TransactionStatus.skipped:
        return 'skipped';
      case TransactionStatus.overridden:
        return 'overridden';
      case TransactionStatus.pending:
        return 'pending';
    }
  }
}

/// JSON serialization extension for [TransactionPage].
extension TransactionPageJson on TransactionPage {
  /// Serializes this [TransactionPage] to a JSON map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {
      'transactions': items.map((t) => t.toJson()).toList(),
    };
    if (nextCursorDate != null || nextCursorId != null) {
      result['next_cursor'] = {
        'date': nextCursorDate,
        'id': nextCursorId,
      };
    } else {
      result['next_cursor'] = null;
    }
    return result;
  }
}

/// JSON serialization extension for [CreateTransactionInput].
extension CreateTransactionInputJson on CreateTransactionInput {
  /// Serializes this input to the request body JSON for `POST /transactions`.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> body = {
      'category_id': categoryId,
      'amount': amount,
      'date': date.toUtc().toIso8601String(),
    };
    if (note != null) body['note'] = note;
    return body;
  }
}
