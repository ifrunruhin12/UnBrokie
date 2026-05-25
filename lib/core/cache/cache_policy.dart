// core/cache/cache_policy.dart

/// Single source of truth for all cache TTLs.
/// Update here — all repositories pick up the change automatically.
abstract final class CachePolicy {
  static const balance = Duration(seconds: 30);
  static const transactions = Duration(seconds: 30);
  static const categories = Duration(seconds: 60); // rarely change
  static const bigBuys = Duration(seconds: 30);
}
