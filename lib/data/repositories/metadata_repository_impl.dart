import '../../core/cache/cache_policy.dart';
import '../../core/cache/cached_fetch.dart';
import '../../core/cache/response_cache.dart';
import '../../domain/models/big_buy.dart';
import '../../domain/models/category.dart';
import '../../domain/repositories/i_metadata_repository.dart';
import '../api/api_client.dart';
import '../json/big_buy_json.dart';
import '../json/category_json.dart';

/// Concrete implementation of [IMetadataRepository].
///
/// Uses [CachedFetch] for SWR-style caching on [getCategories] and
/// [getBigBuys]. Mutations bypass the cache and invalidate it after a
/// successful call.
class MetadataRepositoryImpl implements IMetadataRepository {
  /// Cache key used for all category cache entries.
  static const _categoriesCacheKey = 'categories';

  /// Cache key prefix used for all big-buy cache entries.
  static const _bigBuysCachePrefix = 'big-buys';

  final ApiClient _client;
  final ResponseCache _cache;
  final CachedFetch<List<Category>> _categoriesFetch;
  final CachedFetch<List<BigBuy>> _bigBuysFetch;

  MetadataRepositoryImpl(ApiClient client, ResponseCache cache)
      : _client = client,
        _cache = cache,
        _categoriesFetch = CachedFetch<List<Category>>(cache),
        _bigBuysFetch = CachedFetch<List<BigBuy>>(cache);

  // ---------------------------------------------------------------------------
  // Categories — queries
  // ---------------------------------------------------------------------------

  /// Fetches all categories via `GET /categories`.
  ///
  /// Returns cached data immediately if available (stale-while-revalidate),
  /// then triggers a background refresh. On cache miss, fetches and caches.
  /// TTL is [CachePolicy.categories] (60 s).
  @override
  Future<List<Category>> getCategories() {
    return _categoriesFetch(
      key: _categoriesCacheKey,
      fetch: () => _client.get('/categories').then(CategoryJson.fromJson),
      backgroundFetch: () =>
          _client.getOnce('/categories').then(CategoryJson.fromJson),
      ttl: CachePolicy.categories,
      fromJson: CategoryJson.fromJson,
      toJson: (categories) => {
        'categories': categories.map((c) => c.toJson()).toList(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Categories — mutations
  // ---------------------------------------------------------------------------

  /// Creates a new category via `POST /categories`.
  ///
  /// Body: `{ "name": name }`.
  /// Invalidates the categories cache on success.
  @override
  Future<Category> createCategory(String name) async {
    final json = await _client.post(
      '/categories',
      body: {'name': name},
    );
    _cache.invalidate(_categoriesCacheKey);
    return CategoryJson.fromJsonObject(json);
  }

  /// Renames an existing category via `PATCH /categories/:id`.
  ///
  /// Body: `{ "name": name }`.
  /// Invalidates the categories cache on success.
  @override
  Future<Category> updateCategory(String id, String name) async {
    final json = await _client.patch(
      '/categories/$id',
      body: {'name': name},
    );
    _cache.invalidate(_categoriesCacheKey);
    return CategoryJson.fromJsonObject(json);
  }

  /// Deletes a category via `DELETE /categories/:id`.
  ///
  /// Invalidates the categories cache on success.
  /// Throws [ServerException] if the category is in use.
  @override
  Future<void> deleteCategory(String id) async {
    await _client.delete('/categories/$id');
    _cache.invalidate(_categoriesCacheKey);
  }

  // ---------------------------------------------------------------------------
  // Big Buys — queries
  // ---------------------------------------------------------------------------

  /// Fetches big buys for the given [month] via `GET /big-buys?month=YYYY-MM`.
  ///
  /// Returns cached data immediately if available (stale-while-revalidate),
  /// then triggers a background refresh. On cache miss, fetches and caches.
  /// TTL is [CachePolicy.bigBuys] (30 s).
  @override
  Future<List<BigBuy>> getBigBuys({required String month}) {
    final cacheKey = '$_bigBuysCachePrefix:$month';
    final query = {'month': month};

    return _bigBuysFetch(
      key: cacheKey,
      fetch: () =>
          _client.get('/big-buys', query: query).then(BigBuyJson.fromJson),
      backgroundFetch: () =>
          _client.getOnce('/big-buys', query: query).then(BigBuyJson.fromJson),
      ttl: CachePolicy.bigBuys,
      fromJson: BigBuyJson.fromJson,
      toJson: (bigBuys) => {
        'big_buys': bigBuys.map((b) => b.toJson()).toList(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Big Buys — mutations
  // ---------------------------------------------------------------------------

  /// Creates a new big buy via `POST /big-buys`.
  ///
  /// Body from [CreateBigBuyInput.toJson()].
  /// Invalidates the big-buys cache on success.
  @override
  Future<BigBuy> createBigBuy(CreateBigBuyInput input) async {
    final json = await _client.post(
      '/big-buys',
      body: input.toJson(),
    );
    _cache.invalidate(_bigBuysCachePrefix);
    return BigBuyJson.fromSingleJson(json);
  }

  /// Updates an existing big buy via `PATCH /big-buys/:id`.
  ///
  /// Body from [UpdateBigBuyInput.toJson()] — only non-null fields are sent.
  /// Invalidates the big-buys cache on success.
  @override
  Future<BigBuy> updateBigBuy(String id, UpdateBigBuyInput input) async {
    final json = await _client.patch(
      '/big-buys/$id',
      body: input.toJson(),
    );
    _cache.invalidate(_bigBuysCachePrefix);
    return BigBuyJson.fromSingleJson(json);
  }

  /// Deletes a big buy via `DELETE /big-buys/:id`.
  ///
  /// Invalidates the big-buys cache on success.
  @override
  Future<void> deleteBigBuy(String id) async {
    await _client.delete('/big-buys/$id');
    _cache.invalidate(_bigBuysCachePrefix);
  }
}
