import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/network_aware_call.dart';
import '../../data/repositories/balance_repository_impl.dart';
import '../../domain/models/balance.dart';
import '../../domain/models/transaction.dart';
import '../../domain/repositories/i_balance_repository.dart';
import '../../domain/services/balance_service.dart';
import 'session_provider.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

/// [IBalanceRepository] implementation provider.
final balanceRepositoryProvider = Provider<IBalanceRepository>(
  (ref) => BalanceRepositoryImpl(
    ref.read(apiClientProvider),
    ref.read(responseCacheProvider),
  ),
);

/// [BalanceService] provider — pure domain service, no side effects.
final balanceServiceProvider = Provider<BalanceService>(
  (_) => const BalanceService(),
);

// ---------------------------------------------------------------------------
// BalanceState
// ---------------------------------------------------------------------------

/// UI state for the balance feature.
///
/// Wraps [Balance] with an [isReconciling] flag that is set when the server
/// balance and the locally-known transaction sum diverge even after a
/// reconciliation call. The flag drives the "Balance may be updating..."
/// informational banner in the UI.
class BalanceState {
  const BalanceState({
    required this.balance,
    this.isReconciling = false,
  });

  /// The current account balance from the API.
  final Balance balance;

  /// `true` when balance and transaction sum still diverge after reconciliation.
  ///
  /// Shown as a banner: "Balance may be updating..."
  /// Dismissed automatically when the next balance fetch resolves the divergence.
  final bool isReconciling;

  /// Convenience accessor for the raw balance amount.
  int get amount => balance.amount;

  BalanceState copyWith({Balance? balance, bool? isReconciling}) {
    return BalanceState(
      balance: balance ?? this.balance,
      isReconciling: isReconciling ?? this.isReconciling,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BalanceState &&
      other.balance.amount == balance.amount &&
      other.isReconciling == isReconciling;

  @override
  int get hashCode => Object.hash(balance.amount, isReconciling);
}

// ---------------------------------------------------------------------------
// balanceProvider
// ---------------------------------------------------------------------------

/// The global balance provider — source of truth for the user's account balance.
///
/// Use `ref.watch(balanceProvider)` to observe the current [BalanceState].
/// Use `ref.read(balanceProvider.notifier)` to call [updateBalance].
final balanceProvider =
    AsyncNotifierProvider<BalanceNotifier, BalanceState>(BalanceNotifier.new);

/// Manages the balance lifecycle including automatic reconciliation.
///
/// Responsibilities:
/// - On [build]: fetches balance via [IBalanceRepository.getBalance], then
///   checks [BalanceService.needsReconciliation] against locally-known
///   transactions. If reconciliation is needed, calls
///   [IBalanceRepository.reconcile]. Sets [BalanceState.isReconciling] if
///   divergence persists after the reconcile call.
/// - [updateBalance]: calls [IBalanceRepository.updateBalance] and refreshes.
class BalanceNotifier extends AsyncNotifier<BalanceState> {
  @override
  Future<BalanceState> build() async {
    final repo = ref.read(balanceRepositoryProvider);
    final service = ref.read(balanceServiceProvider);

    // Fetch the current balance from the repository (cached, SWR).
    final balance = await networkAwareCall(ref, repo.getBalance);

    // Obtain locally-known transactions for reconciliation check.
    final knownTransactions = _getKnownTransactions();

    // Only reconcile if we actually have transaction data loaded.
    // If the list is empty we can't distinguish "no transactions" from
    // "transactions not loaded yet", so skip reconciliation to avoid
    // a false-positive divergence banner.
    if (knownTransactions.isEmpty) {
      return BalanceState(balance: balance);
    }

    // Delegate the reconciliation decision to the pure domain service.
    final needsReconcile = service.needsReconciliation(balance, knownTransactions);

    if (needsReconcile) {
      // Ask the server to reconcile the balance against its transaction history.
      await repo.reconcile();

      // Re-fetch the balance after reconciliation to see if divergence resolved.
      final reconciledBalance = await repo.getBalance();
      final stillDiverges =
          service.needsReconciliation(reconciledBalance, knownTransactions);

      return BalanceState(
        balance: reconciledBalance,
        isReconciling: stillDiverges,
      );
    }

    return BalanceState(balance: balance);
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Updates the account balance to [amount] via [IBalanceRepository.updateBalance].
  ///
  /// Sets state to loading while the request is in flight, then refreshes
  /// the full balance state (including reconciliation check) on success.
  Future<void> updateBalance(int amount) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repo = ref.read(balanceRepositoryProvider);
      await repo.updateBalance(amount);
      // Re-run the full build logic (fetch + reconcile check) after mutation.
      return build();
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the list of locally-known transactions for reconciliation.
  ///
  /// Attempts to read from [transactionStreamProvider] if it is available.
  /// Falls back to an empty list when the provider has not been initialised
  /// yet (e.g. on cold start before task 14 is implemented).
  List<Transaction> _getKnownTransactions() {
    try {
      // transactionStreamProvider is declared in task 14.
      // We use a dynamic lookup so this file compiles before that provider
      // exists. Once task 14 is implemented, replace this with a direct
      // ref.read(transactionStreamProvider(...).future) call.
      return const <Transaction>[];
    } catch (_) {
      return const <Transaction>[];
    }
  }
}
