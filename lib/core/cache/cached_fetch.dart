// core/cache/cached_fetch.dart
import 'dart:async';

import 'package:finance_app/core/cache/response_cache.dart';

/// Reusable SWR helper. Repositories call this instead of implementing
/// cache-check + background-refresh logic themselves.
class CachedFetch<T> {
  final ResponseCache _cache;

  const CachedFetch(this._cache);

  /// Returns cached data immediately if available (stale-while-revalidate),
  /// then triggers a background refresh. On cache miss, fetches and caches.
  ///
  /// [fetch] uses apiClient.get (with retry) — for the cache miss foreground path.
  /// [backgroundFetch] uses apiClient.getOnce (no retry) — for SWR background refresh only.
  Future<T> call({
    required String key,
    required Future<T> Function() fetch,
    required Future<T> Function() backgroundFetch,
    required Duration ttl,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    final cached = _cache.get(key);
    if (cached != null) {
      // Return stale data immediately; refresh in background (non-retrying)
      unawaited(_backgroundRefresh(key, backgroundFetch, ttl, toJson));
      return fromJson(cached);
    }
    // Cache miss — fetch (with retry), store, return
    final result = await fetch();
    _cache.set(key, toJson(result), ttl);
    return result;
  }

  Future<void> _backgroundRefresh(
    String key,
    Future<T> Function() backgroundFetch,
    Duration ttl,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final result = await backgroundFetch(); // getOnce — no retry
      _cache.set(key, toJson(result), ttl);
    } catch (_) {
      // Silently ignore background refresh failures — stale data remains
    }
  }
}
