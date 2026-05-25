import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/utils/network_aware_call.dart';
import '../../data/repositories/metadata_repository_impl.dart';
import '../../domain/models/big_buy.dart';
import '../../domain/models/category.dart';
import '../../domain/repositories/i_metadata_repository.dart';
import 'session_provider.dart';

// ---------------------------------------------------------------------------
// Infrastructure provider
// ---------------------------------------------------------------------------

/// [IMetadataRepository] implementation provider.
final metadataRepositoryProvider = Provider<IMetadataRepository>(
  (ref) => MetadataRepositoryImpl(
    ref.read(apiClientProvider),
    ref.read(responseCacheProvider),
  ),
);

// ---------------------------------------------------------------------------
// MetadataState
// ---------------------------------------------------------------------------

/// Combined state for categories and big buys.
class MetadataState {
  const MetadataState({
    required this.categories,
    required this.bigBuys,
    this.error,
  });

  /// All user-defined categories.
  final List<Category> categories;

  /// Big buys scoped to the current month.
  final List<BigBuy> bigBuys;

  /// Non-null when the last mutation failed.
  final String? error;

  MetadataState copyWith({
    List<Category>? categories,
    List<BigBuy>? bigBuys,
    String? error,
    bool clearError = false,
  }) {
    return MetadataState(
      categories: categories ?? this.categories,
      bigBuys: bigBuys ?? this.bigBuys,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// metadataProvider
// ---------------------------------------------------------------------------

/// Source of truth for categories and big buys (current month).
///
/// Use `ref.watch(metadataProvider)` to observe [MetadataState].
/// Use `ref.read(metadataProvider.notifier)` to call CRUD methods.
final metadataProvider =
    AsyncNotifierProvider<MetadataNotifier, MetadataState>(MetadataNotifier.new);

/// Manages categories and big buys with full CRUD support.
///
/// On [build], fetches categories and current-month big buys in parallel.
/// Each mutation invalidates the relevant cache prefix and re-fetches.
class MetadataNotifier extends AsyncNotifier<MetadataState> {
  @override
  Future<MetadataState> build() async {
    final repo = ref.read(metadataRepositoryProvider);
    final currentMonth = DateFormatter.toYearMonth(DateTime.now());

    // Fetch categories and big buys in parallel.
    final results = await networkAwareCall(
      ref,
      () => Future.wait([
        repo.getCategories(),
        repo.getBigBuys(month: currentMonth),
      ]),
    );

    return MetadataState(
      categories: results[0] as List<Category>,
      bigBuys: results[1] as List<BigBuy>,
    );
  }

  // ---------------------------------------------------------------------------
  // Category mutations
  // ---------------------------------------------------------------------------

  /// Creates a new category and refreshes the category list.
  Future<void> createCategory(String name) async {
    final repo = ref.read(metadataRepositoryProvider);
    final newCategory = await repo.createCategory(name);

    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        categories: [...current.categories, newCategory],
        clearError: true,
      ),
    );
  }

  /// Renames an existing category and updates the list in place.
  Future<void> updateCategory(String id, String name) async {
    final repo = ref.read(metadataRepositoryProvider);
    final updated = await repo.updateCategory(id, name);

    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        categories: current.categories
            .map((c) => c.id == id ? updated : c)
            .toList(),
        clearError: true,
      ),
    );
  }

  /// Deletes a category and removes it from the list.
  ///
  /// On failure (e.g. category in use), sets [MetadataState.error] and
  /// leaves the list unchanged.
  Future<void> deleteCategory(String id) async {
    final repo = ref.read(metadataRepositoryProvider);
    final current = state.value;
    if (current == null) return;

    try {
      await repo.deleteCategory(id);
      state = AsyncData(
        current.copyWith(
          categories: current.categories.where((c) => c.id != id).toList(),
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(error: e.toString()),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Big Buy mutations
  // ---------------------------------------------------------------------------

  /// Creates a new big buy and appends it to the list.
  Future<void> createBigBuy(CreateBigBuyInput input) async {
    final repo = ref.read(metadataRepositoryProvider);
    final newBigBuy = await repo.createBigBuy(input);

    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        bigBuys: [...current.bigBuys, newBigBuy],
        clearError: true,
      ),
    );
  }

  /// Updates an existing big buy and replaces it in the list.
  Future<void> updateBigBuy(String id, UpdateBigBuyInput input) async {
    final repo = ref.read(metadataRepositoryProvider);
    final updated = await repo.updateBigBuy(id, input);

    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        bigBuys: current.bigBuys
            .map((b) => b.id == id ? updated : b)
            .toList(),
        clearError: true,
      ),
    );
  }

  /// Deletes a big buy and removes it from the list.
  ///
  /// On failure, sets [MetadataState.error] and leaves the list unchanged.
  Future<void> deleteBigBuy(String id) async {
    final repo = ref.read(metadataRepositoryProvider);
    final current = state.value;
    if (current == null) return;

    try {
      await repo.deleteBigBuy(id);
      state = AsyncData(
        current.copyWith(
          bigBuys: current.bigBuys.where((b) => b.id != id).toList(),
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(error: e.toString()),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Month navigation
  // ---------------------------------------------------------------------------

  /// Re-fetches big buys for the given [month] (format: "YYYY-MM").
  ///
  /// Used by the Big Buys screen when the user navigates to a different month.
  Future<void> loadBigBuysForMonth(String month) async {
    final repo = ref.read(metadataRepositoryProvider);
    final current = state.value;
    if (current == null) return;

    final bigBuys = await repo.getBigBuys(month: month);
    state = AsyncData(current.copyWith(bigBuys: bigBuys, clearError: true));
  }
}
