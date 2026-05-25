import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/network_aware_call.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_filter.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import 'balance_provider.dart';
import 'session_provider.dart';

// ---------------------------------------------------------------------------
// Infrastructure provider
// ---------------------------------------------------------------------------

final transactionRepositoryProvider = Provider<ITransactionRepository>(
  (ref) => TransactionRepositoryImpl(
    ref.read(apiClientProvider),
    ref.read(responseCacheProvider),
  ),
);

// ---------------------------------------------------------------------------
// transactionStreamProvider
// ---------------------------------------------------------------------------

final transactionStreamProvider = AsyncNotifierProvider.family<
    TransactionStreamNotifier, TransactionPage, TransactionFilter>(
  (filter) => TransactionStreamNotifier(filter),
);

class TransactionStreamNotifier extends AsyncNotifier<TransactionPage> {
  TransactionStreamNotifier(this._filter);

  final TransactionFilter _filter;

  @override
  Future<TransactionPage> build() async {
    final repo = ref.read(transactionRepositoryProvider);
    try {
      return await networkAwareCall(
        ref,
        () => repo.getTransactions(
          from: _filter.from,
          to: _filter.to,
          categoryId: _filter.categoryId,
          cursorDate: _filter.cursorDate,
          cursorId: _filter.cursorId,
        ),
      );
    } catch (e, st) {
      debugPrint('[TransactionStreamNotifier] build error: $e\n$st');
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    if (current.nextCursorDate == null && current.nextCursorId == null) return;

    final repo = ref.read(transactionRepositoryProvider);
    final nextPage = await repo.getTransactions(
      from: _filter.from,
      to: _filter.to,
      categoryId: _filter.categoryId,
      cursorDate: current.nextCursorDate,
      cursorId: current.nextCursorId,
    );

    final existingIds = {for (final t in current.items) t.id};
    final newItems = nextPage.items.where((t) => !existingIds.contains(t.id));

    state = AsyncData(TransactionPage(
      items: [...current.items, ...newItems],
      nextCursorDate: nextPage.nextCursorDate,
      nextCursorId: nextPage.nextCursorId,
    ));
  }

  Future<void> createTransaction(CreateTransactionInput input) async {
    final current = state.value;
    if (current == null) return;

    final pendingId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    final pendingTx = Transaction(
      id: pendingId,
      categoryId: input.categoryId,
      categoryName: '',
      amount: input.amount,
      date: input.date,
      note: input.note,
      status: TransactionStatus.pending,
    );

    state = AsyncData(TransactionPage(
      items: [pendingTx, ...current.items],
      nextCursorDate: current.nextCursorDate,
      nextCursorId: current.nextCursorId,
    ));

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final realTx = await networkAwareCall(ref, () => repo.createTransaction(input));

      final currentItems = state.value?.items ?? [];
      state = AsyncData(TransactionPage(
        items: currentItems.map((t) => t.id == pendingId ? realTx : t).toList(),
        nextCursorDate: state.value?.nextCursorDate,
        nextCursorId: state.value?.nextCursorId,
      ));

      ref.invalidate(balanceProvider);
    } catch (e) {
      final currentItems = state.value?.items ?? [];
      state = AsyncData(TransactionPage(
        items: currentItems.where((t) => t.id != pendingId).toList(),
        nextCursorDate: state.value?.nextCursorDate,
        nextCursorId: state.value?.nextCursorId,
      ));
      rethrow;
    }
  }

  Future<void> overrideTransaction(String id, {int? amount, String? note}) async {
    final repo = ref.read(transactionRepositoryProvider);
    final updated = await networkAwareCall(
      ref,
      () => repo.overrideTransaction(id, amount: amount, note: note),
    );
    _replaceItem(updated);
    ref.invalidate(balanceProvider);
  }

  Future<void> skipTransaction(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    final updated = await networkAwareCall(ref, () => repo.skipTransaction(id));
    _replaceItem(updated);
    ref.invalidate(balanceProvider);
  }

  Future<void> restoreTransaction(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    final updated = await networkAwareCall(ref, () => repo.restoreTransaction(id));
    _replaceItem(updated);
    ref.invalidate(balanceProvider);
  }

  void _replaceItem(Transaction updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(TransactionPage(
      items: current.items.map((t) => t.id == updated.id ? updated : t).toList(),
      nextCursorDate: current.nextCursorDate,
      nextCursorId: current.nextCursorId,
    ));
  }
}
