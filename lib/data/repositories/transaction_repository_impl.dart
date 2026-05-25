import 'package:flutter/foundation.dart';

import '../../core/cache/cache_policy.dart';
import '../../core/cache/cached_fetch.dart';
import '../../core/cache/response_cache.dart';
import '../../domain/models/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../api/api_client.dart';
import '../json/transaction_json.dart';

/// Concrete implementation of [ITransactionRepository].
///
/// Uses [CachedFetch] for SWR-style caching on [getTransactions].
/// Mutations ([createTransaction], [overrideTransaction], [skipTransaction],
/// [restoreTransaction]) bypass the cache and invalidate it after a successful
/// call. [getTransactionHistory] is a simple uncached GET.
class TransactionRepositoryImpl implements ITransactionRepository {
  /// Cache key prefix used for all transaction cache entries.
  static const _cachePrefix = 'transactions';

  final ApiClient _client;
  final ResponseCache _cache;
  final CachedFetch<TransactionPage> _cachedFetch;

  TransactionRepositoryImpl(ApiClient client, ResponseCache cache)
      : _client = client,
        _cache = cache,
        _cachedFetch = CachedFetch<TransactionPage>(cache);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Fetches a paginated page of transactions via `GET /transactions`.
  ///
  /// Query params sent: `from`, `to`, `limit`, and optionally `cursor_date`,
  /// `cursor_id`, `category_id`.
  ///
  /// The response key is `transactions` (not `items`). Pagination cursors are
  /// read from `next_cursor.date` and `next_cursor.id` (null-safe). If the
  /// `next_cursor` field is absent from the response, a warning is logged and
  /// the page is treated as complete (no more pages).
  ///
  /// Results are cached per [CachePolicy.transactions] (30 s) using a key
  /// derived from all query parameters.
  @override
  Future<TransactionPage> getTransactions({
    String? cursorDate,
    String? cursorId,
    int limit = 50,
    required String from,
    required String to,
    String? categoryId,
  }) {
    final cacheKey =
        '$_cachePrefix:$from:$to:${cursorDate ?? ""}:${cursorId ?? ""}:${categoryId ?? ""}';

    final query = _buildQuery(
      from: from,
      to: to,
      limit: limit,
      cursorDate: cursorDate,
      cursorId: cursorId,
      categoryId: categoryId,
    );

    return _cachedFetch(
      key: cacheKey,
      fetch: () => _client
          .get('/transactions', query: query)
          .then(_parsePageWithWarning),
      backgroundFetch: () => _client
          .getOnce('/transactions', query: query)
          .then(_parsePageWithWarning),
      ttl: CachePolicy.transactions,
      fromJson: TransactionJson.fromJson,
      toJson: (page) => page.toJson(),
    );
  }

  /// Fetches the audit history for a single transaction via
  /// `GET /transactions/:id/history`.
  ///
  /// Not cached — history is always fetched fresh.
  @override
  Future<List<Transaction>> getTransactionHistory(String id) async {
    final json = await _client.get('/transactions/$id/history');
    final rawList = (json['transactions'] as List<dynamic>?) ?? [];
    return rawList
        .map((e) => TransactionJson.fromJsonObject(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Creates a new transaction via `POST /transactions`.
  ///
  /// Body: `{ "category_id", "amount", "date" (ISO8601), "note"? }`.
  /// Invalidates the transactions cache on success.
  @override
  Future<Transaction> createTransaction(CreateTransactionInput input) async {
    final json = await _client.post(
      '/transactions',
      body: input.toJson(),
    );
    _cache.invalidate(_cachePrefix);
    return TransactionJson.fromJsonObject(
      json['transaction'] as Map<String, dynamic>? ?? json,
    );
  }

  /// Overrides the amount and/or note of a transaction via
  /// `PATCH /transactions/:id/override`.
  ///
  /// Only non-null fields are included in the request body.
  /// Invalidates the transactions cache on success.
  @override
  Future<Transaction> overrideTransaction(
    String id, {
    int? amount,
    String? note,
  }) async {
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount;
    if (note != null) body['note'] = note;

    final json = await _client.patch(
      '/transactions/$id/override',
      body: body,
    );
    _cache.invalidate(_cachePrefix);
    return TransactionJson.fromJsonObject(
      json['transaction'] as Map<String, dynamic>? ?? json,
    );
  }

  /// Marks a transaction as skipped via `PATCH /transactions/:id/skip`.
  ///
  /// Invalidates the transactions cache on success.
  @override
  Future<Transaction> skipTransaction(String id) async {
    final json = await _client.patch('/transactions/$id/skip');
    _cache.invalidate(_cachePrefix);
    return TransactionJson.fromJsonObject(
      json['transaction'] as Map<String, dynamic>? ?? json,
    );
  }

  /// Restores a previously skipped transaction via
  /// `PATCH /transactions/:id/restore`.
  ///
  /// Invalidates the transactions cache on success.
  @override
  Future<Transaction> restoreTransaction(String id) async {
    final json = await _client.patch('/transactions/$id/restore');
    _cache.invalidate(_cachePrefix);
    return TransactionJson.fromJsonObject(
      json['transaction'] as Map<String, dynamic>? ?? json,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Builds the query parameter map for `GET /transactions`.
  Map<String, String> _buildQuery({
    required String from,
    required String to,
    required int limit,
    String? cursorDate,
    String? cursorId,
    String? categoryId,
  }) {
    final query = <String, String>{
      'from': from,
      'to': to,
      'limit': limit.toString(),
    };
    if (cursorDate != null) query['cursor_date'] = cursorDate;
    if (cursorId != null) query['cursor_id'] = cursorId;
    if (categoryId != null) query['category_id'] = categoryId;
    return query;
  }

  /// Parses a [TransactionPage] from the API response JSON, logging a warning
  /// if the `next_cursor` field is absent.
  TransactionPage _parsePageWithWarning(Map<String, dynamic> json) {
    if (!json.containsKey('next_cursor')) {
      debugPrint(
        '[TransactionRepository] Warning: next_cursor missing from response, '
        'treating as complete page',
      );
    }
    return TransactionJson.fromJson(json);
  }
}
