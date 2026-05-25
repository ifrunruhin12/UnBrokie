// core/cache/response_cache.dart

/// A dumb TTL key-value store. No business logic, no HTTP calls,
/// no retry, and no SWR behavior.
class _CacheEntry {
  final Map<String, dynamic> response;
  final DateTime expiresAt;

  const _CacheEntry({required this.response, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ResponseCache {
  final Map<String, _CacheEntry> _store = {};

  /// Returns the cached value or null if expired/missing.
  Map<String, dynamic>? get(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.response;
  }

  /// Stores [response] under [key] with the given [ttl].
  void set(String key, Map<String, dynamic> response, Duration ttl) {
    _store[key] = _CacheEntry(
      response: response,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Invalidates all keys that start with [pathPrefix].
  void invalidate(String pathPrefix) {
    _store.removeWhere((key, _) => key.startsWith(pathPrefix));
  }

  /// Clears the entire cache.
  void clear() {
    _store.clear();
  }
}
