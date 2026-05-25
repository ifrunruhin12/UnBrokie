import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_filter.dart';
import 'transaction_stream_provider.dart';

// ---------------------------------------------------------------------------
// TransactionViewState
// ---------------------------------------------------------------------------

/// UI view state for the transaction list.
///
/// Derived from [transactionStreamProvider] with client-side search and
/// category filter applied on top.
class TransactionViewState {
  const TransactionViewState({
    required this.filtered,
    this.searchQuery = '',
    this.categoryFilter,
    this.isLoadingMore = false,
  });

  /// Transactions after [searchQuery] and [categoryFilter] have been applied.
  final List<Transaction> filtered;

  /// Current search string (case-insensitive match on name or note).
  final String searchQuery;

  /// Optional category name to restrict results to.
  final String? categoryFilter;

  /// `true` while [TransactionStreamNotifier.loadMore] is in progress.
  final bool isLoadingMore;

  TransactionViewState copyWith({
    List<Transaction>? filtered,
    String? searchQuery,
    String? categoryFilter,
    bool clearCategoryFilter = false,
    bool? isLoadingMore,
  }) {
    return TransactionViewState(
      filtered: filtered ?? this.filtered,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionViewState &&
      other.searchQuery == searchQuery &&
      other.categoryFilter == categoryFilter &&
      other.isLoadingMore == isLoadingMore &&
      _listEquals(other.filtered, filtered);

  @override
  int get hashCode =>
      Object.hash(searchQuery, categoryFilter, isLoadingMore, filtered.length);

  static bool _listEquals(List<Transaction> a, List<Transaction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// transactionViewProvider
// ---------------------------------------------------------------------------

/// UI view state for transactions, keyed by [TransactionFilter].
///
/// Watches [transactionStreamProvider] and applies client-side filters:
/// - [TransactionViewState.searchQuery]: case-insensitive match on
///   [Transaction.categoryName] or [Transaction.note].
/// - [TransactionViewState.categoryFilter]: exact match on
///   [Transaction.categoryName].
///
/// Use [TransactionViewNotifier.setSearch] and
/// [TransactionViewNotifier.setCategoryFilter] to update the filters.
///
/// [analyticsProvider] watches [transactionStreamProvider] directly — NOT this
/// provider — to avoid recomputing analytics when only UI filters change.
final transactionViewProvider = NotifierProvider.family<TransactionViewNotifier,
    TransactionViewState, TransactionFilter>(
  (filter) => TransactionViewNotifier(filter),
);

class TransactionViewNotifier extends Notifier<TransactionViewState> {
  TransactionViewNotifier(this._filter);

  final TransactionFilter _filter;

  @override
  TransactionViewState build() {
    final streamAsync = ref.watch(transactionStreamProvider(_filter));
    final allItems = streamAsync.value?.items ?? const [];
    return TransactionViewState(
      filtered: _applyFilters(allItems, '', null),
      searchQuery: '',
      categoryFilter: null,
      isLoadingMore: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Updates the search query and re-applies client-side filters.
  ///
  /// Filtering is case-insensitive and matches against [Transaction.categoryName]
  /// or [Transaction.note].
  void setSearch(String query) {
    final allItems = _getAllItems();
    state = state.copyWith(
      filtered: _applyFilters(allItems, query, state.categoryFilter),
      searchQuery: query,
    );
  }

  /// Updates the category filter and re-applies client-side filters.
  ///
  /// Pass `null` to clear the category filter.
  void setCategoryFilter(String? categoryName) {
    final allItems = _getAllItems();
    if (categoryName == null) {
      state = state.copyWith(
        filtered: _applyFilters(allItems, state.searchQuery, null),
        clearCategoryFilter: true,
      );
    } else {
      state = state.copyWith(
        filtered: _applyFilters(allItems, state.searchQuery, categoryName),
        categoryFilter: categoryName,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns all items from the current [transactionStreamProvider] state.
  List<Transaction> _getAllItems() {
    return ref.read(transactionStreamProvider(_filter)).value?.items ??
        const [];
  }

  /// Applies [searchQuery] and [categoryFilter] to [items].
  ///
  /// - [searchQuery]: case-insensitive substring match on
  ///   [Transaction.categoryName] or [Transaction.note].
  /// - [categoryFilter]: exact (case-insensitive) match on
  ///   [Transaction.categoryName].
  static List<Transaction> _applyFilters(
    List<Transaction> items,
    String searchQuery,
    String? categoryFilter,
  ) {
    var result = items;

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      final lowerCategory = categoryFilter.toLowerCase();
      result = result
          .where((t) => t.categoryName.toLowerCase() == lowerCategory)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      result = result.where((t) {
        final nameMatch = t.categoryName.toLowerCase().contains(lowerQuery);
        final noteMatch =
            t.note != null && t.note!.toLowerCase().contains(lowerQuery);
        return nameMatch || noteMatch;
      }).toList();
    }

    return result;
  }
}
