import 'package:meta/meta.dart';

/// Immutable filter / pagination key for transaction queries.
///
/// Used directly as the Riverpod family key for [transactionStreamProvider]
/// and [transactionViewProvider]. Stable [==] and [hashCode] ensure Riverpod
/// reuses the same notifier instance when the filter has not changed.
///
/// Cache keys are derived from [cacheKey].
@immutable
class TransactionFilter {
  const TransactionFilter({
    required this.from,
    required this.to,
    this.categoryId,
    this.cursorDate,
    this.cursorId,
  });

  /// Start of the date range in ISO 8601 format ("YYYY-MM-DD").
  /// Sent as RFC3339 to the API.
  final String from;

  /// End of the date range in ISO 8601 format ("YYYY-MM-DD").
  /// Sent as RFC3339 to the API.
  final String to;

  /// Optional category UUID to restrict results to a single category.
  final String? categoryId;

  /// RFC3339 cursor date from the previous page's `next_cursor.date`.
  final String? cursorDate;

  /// UUID cursor from the previous page's `next_cursor.id`.
  final String? cursorId;

  /// Stable string key used for [ResponseCache] lookups.
  String get cacheKey =>
      '$from|$to|${categoryId ?? ""}|${cursorDate ?? ""}|${cursorId ?? ""}';

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      from == other.from &&
      to == other.to &&
      categoryId == other.categoryId &&
      cursorDate == other.cursorDate &&
      cursorId == other.cursorId;

  @override
  int get hashCode =>
      Object.hash(from, to, categoryId, cursorDate, cursorId);
}
