import '../models/big_buy.dart';
import '../models/category.dart';

/// Domain interface for category and big-buy metadata operations.
///
/// Implementations live in `data/repositories/metadata_repository_impl.dart`.
abstract interface class IMetadataRepository {
  // ── Categories ────────────────────────────────────────────────────────────

  /// Fetches all categories via `GET /categories`.
  ///
  /// Results are cached per [CachePolicy.categories] (60 s).
  Future<List<Category>> getCategories();

  /// Creates a new category via `POST /categories`.
  ///
  /// Invalidates the categories cache on success.
  Future<Category> createCategory(String name);

  /// Renames an existing category via `PATCH /categories/:id`.
  ///
  /// Invalidates the categories cache on success.
  Future<Category> updateCategory(String id, String name);

  /// Deletes a category via `DELETE /categories/:id`.
  ///
  /// Invalidates the categories cache on success.
  /// Throws [ServerException] if the category is in use.
  Future<void> deleteCategory(String id);

  // ── Big Buys ──────────────────────────────────────────────────────────────

  /// Fetches big buys for the given [month] via `GET /big-buys?month=YYYY-MM`.
  ///
  /// Results are cached per [CachePolicy.bigBuys] (30 s).
  Future<List<BigBuy>> getBigBuys({required String month});

  /// Creates a new big buy via `POST /big-buys`.
  ///
  /// Invalidates the big-buys cache on success.
  Future<BigBuy> createBigBuy(CreateBigBuyInput input);

  /// Updates an existing big buy via `PATCH /big-buys/:id`.
  ///
  /// Invalidates the big-buys cache on success.
  Future<BigBuy> updateBigBuy(String id, UpdateBigBuyInput input);

  /// Deletes a big buy via `DELETE /big-buys/:id`.
  ///
  /// Invalidates the big-buys cache on success.
  Future<void> deleteBigBuy(String id);
}
