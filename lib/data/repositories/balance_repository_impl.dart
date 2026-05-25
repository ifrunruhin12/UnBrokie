import '../../core/cache/cache_policy.dart';
import '../../core/cache/cached_fetch.dart';
import '../../core/cache/response_cache.dart';
import '../../domain/models/balance.dart';
import '../../domain/repositories/i_balance_repository.dart';
import '../api/api_client.dart';
import '../json/balance_json.dart';

/// Concrete implementation of [IBalanceRepository].
///
/// Uses [CachedFetch] for SWR-style caching on [getBalance].
/// Mutations ([updateBalance], [reconcile]) bypass the cache and invalidate
/// it after a successful call.
class BalanceRepositoryImpl implements IBalanceRepository {
  /// Cache key used for the balance entry.
  static const _cacheKey = 'balance';

  final ApiClient _client;
  final ResponseCache _cache;
  final CachedFetch<Balance> _cachedFetch;

  BalanceRepositoryImpl(ApiClient client, ResponseCache cache)
      : _client = client,
        _cache = cache,
        _cachedFetch = CachedFetch<Balance>(cache);

  /// Fetches the current account balance via `GET /balance`.
  ///
  /// Returns cached data immediately if available (stale-while-revalidate),
  /// then triggers a background refresh. On cache miss, fetches and caches.
  /// TTL is [CachePolicy.balance] (30 s).
  @override
  Future<Balance> getBalance() {
    return _cachedFetch(
      key: _cacheKey,
      fetch: () => _client.get('/balance').then(BalanceJson.fromJson),
      backgroundFetch: () =>
          _client.getOnce('/balance').then(BalanceJson.fromJson),
      ttl: CachePolicy.balance,
      fromJson: BalanceJson.fromJson,
      toJson: (balance) => balance.toJson(),
    );
  }

  /// Updates the account balance via `PATCH /account/balance`.
  ///
  /// Sends `{ "balance": amount }` (field name is `"balance"`, not `"amount"`).
  /// Invalidates the balance cache after a successful mutation so the next
  /// [getBalance] call fetches fresh data.
  @override
  Future<Balance> updateBalance(int amount) async {
    final json = await _client.patch(
      '/account/balance',
      body: {'balance': amount},
    );
    _cache.invalidate(_cacheKey);
    return BalanceJson.fromJson(json);
  }

  /// Triggers server-side reconciliation via `POST /account/reconcile`.
  ///
  /// Called when [BalanceService.needsReconciliation] returns `true`.
  /// The server reconciles the balance against the transaction history.
  @override
  Future<void> reconcile() async {
    await _client.post('/account/reconcile');
  }

  /// Updates the account timezone via `PATCH /account/timezone`.
  ///
  /// Sends `{ "timezone": ianaTimezone }` and returns the confirmed timezone string.
  @override
  Future<String> updateTimezone(String ianaTimezone) async {
    final json = await _client.patch(
      '/account/timezone',
      body: {'timezone': ianaTimezone},
    );
    return json['timezone'] as String? ?? ianaTimezone;
  }
}
