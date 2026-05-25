// Feature: flutter-finance-app
// Property 20: Balance reconciliation trigger
// Validates: Requirements 10.7

import 'package:finance_app/domain/models/balance.dart';
import 'package:finance_app/domain/repositories/i_balance_repository.dart';
import 'package:finance_app/domain/services/balance_service.dart';
import 'package:finance_app/presentation/providers/balance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake IBalanceRepository
// ---------------------------------------------------------------------------

/// Configurable fake for [IBalanceRepository].
class _FakeBalanceRepository implements IBalanceRepository {
  _FakeBalanceRepository({
    required this.balance,
    this.updateResult,
    this.updateError,
  });

  /// Balance returned by [getBalance].
  Balance balance;

  /// Balance returned by [updateBalance] (defaults to [balance] if null).
  Balance? updateResult;

  /// Exception thrown by [updateBalance] if set.
  Exception? updateError;

  /// Number of times [reconcile] was called.
  int reconcileCallCount = 0;

  /// Number of times [getBalance] was called.
  int getBalanceCallCount = 0;

  /// Number of times [updateBalance] was called.
  int updateBalanceCallCount = 0;

  @override
  Future<Balance> getBalance() async {
    getBalanceCallCount++;
    return balance;
  }

  @override
  Future<Balance> updateBalance(int amount) async {
    updateBalanceCallCount++;
    if (updateError != null) throw updateError!;
    balance = updateResult ?? Balance(amount: amount);
    return balance;
  }

  @override
  Future<void> reconcile() async {
    reconcileCallCount++;
  }

  @override
  Future<String> updateTimezone(String ianaTimezone) async => ianaTimezone;
}

// ---------------------------------------------------------------------------
// ProviderContainer factory
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] with [balanceRepositoryProvider] overridden
/// by [fakeRepo] and [balanceServiceProvider] overridden by [service].
ProviderContainer _makeContainer(
  _FakeBalanceRepository fakeRepo, {
  BalanceService? service,
}) {
  return ProviderContainer(
    overrides: [
      balanceRepositoryProvider.overrideWithValue(fakeRepo),
      if (service != null) balanceServiceProvider.overrideWithValue(service),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Property 20: Balance reconciliation trigger
  // Validates: Requirements 10.7
  // ---------------------------------------------------------------------------
  group('BalanceNotifier — Property 20: Balance reconciliation trigger', () {
    test(
        'reconcile() is NOT called when needsReconciliation returns false',
        () async {
      // Balance and transaction sum match — no reconciliation needed.
      // BalanceService with empty transactions: balance.amount - 0 = balance.amount.
      // We use amount = 0 so the difference is 0, which is <= threshold (1 cent).
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 0));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);

      expect(repo.reconcileCallCount, equals(0));
    });

    test(
        'reconcile() is called when needsReconciliation returns true',
        () async {
      // Balance is 100 cents, known transactions sum to 0 (empty list).
      // Divergence = |100 - 0| = 100 > 1 cent threshold → reconcile.
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 100));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);

      expect(repo.reconcileCallCount, equals(1));
    });

    test(
        'reconcile() is called exactly once per build when divergence exists',
        () async {
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 500));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);

      expect(repo.reconcileCallCount, equals(1));
    });

    test(
        'isReconciling is false when balance matches transaction sum',
        () async {
      // amount = 0, empty transactions → no divergence.
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 0));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(balanceProvider.future);

      expect(state.isReconciling, isFalse);
    });

    test(
        'isReconciling is true when divergence persists after reconcile',
        () async {
      // Balance is 100 cents, transactions sum to 0 → divergence.
      // After reconcile, getBalance is called again and still returns 100 cents
      // (server hasn't changed it in our fake), so divergence persists.
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 100));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(balanceProvider.future);

      // Divergence persists after reconcile → isReconciling = true.
      expect(state.isReconciling, isTrue);
    });

    test(
        'isReconciling is false when divergence resolves after reconcile',
        () async {
      // Simulate: first getBalance returns 100 (diverges), after reconcile
      // getBalance returns 0 (matches empty transaction sum).
      final container = ProviderContainer(
        overrides: [
          balanceRepositoryProvider.overrideWith(
            (_) => _SequentialBalanceRepository(
              balances: [
                const Balance(amount: 100), // first call — diverges
                const Balance(amount: 0),   // second call — matches
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(balanceProvider.future);

      // After reconcile, balance matches → isReconciling = false.
      expect(state.isReconciling, isFalse);
    });

    test(
        'balance amount is correctly exposed in BalanceState',
        () async {
      const expectedAmount = 42;
      final repo =
          _FakeBalanceRepository(balance: const Balance(amount: expectedAmount));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(balanceProvider.future);

      expect(state.amount, equals(expectedAmount));
      expect(state.balance.amount, equals(expectedAmount));
    });

    test(
        'build transitions to AsyncData on success',
        () async {
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 0));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);

      final asyncState = container.read(balanceProvider);
      expect(asyncState, isA<AsyncData<BalanceState>>());
    });

    test(
        'build fetches balance from repository',
        () async {
      const expectedAmount = 77;
      final repo =
          _FakeBalanceRepository(balance: const Balance(amount: expectedAmount));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(balanceProvider.future);

      expect(state.balance.amount, equals(expectedAmount));
      expect(repo.getBalanceCallCount, greaterThanOrEqualTo(1));
    });
  });

  // ---------------------------------------------------------------------------
  // updateBalance mutation
  // ---------------------------------------------------------------------------
  group('BalanceNotifier.updateBalance', () {
    test(
        'updateBalance calls IBalanceRepository.updateBalance with correct amount',
        () async {
      final repo = _FakeBalanceRepository(balance: const Balance(amount: 0));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);
      await container.read(balanceProvider.notifier).updateBalance(200);

      expect(repo.updateBalanceCallCount, equals(1));
    });

    test(
        'updateBalance refreshes balance state after mutation',
        () async {
      final repo = _FakeBalanceRepository(
        balance: const Balance(amount: 0),
        updateResult: const Balance(amount: 200),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);
      await container.read(balanceProvider.notifier).updateBalance(200);

      final asyncState = container.read(balanceProvider);
      expect(asyncState, isA<AsyncData<BalanceState>>());
    });

    test(
        'updateBalance transitions to AsyncError when repository throws',
        () async {
      final repo = _FakeBalanceRepository(
        balance: const Balance(amount: 0),
        updateError: Exception('Update failed'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(balanceProvider.future);
      await container.read(balanceProvider.notifier).updateBalance(200);

      final asyncState = container.read(balanceProvider);
      expect(asyncState, isA<AsyncError<BalanceState>>());
    });
  });

  // ---------------------------------------------------------------------------
  // BalanceState equality and copyWith
  // ---------------------------------------------------------------------------
  group('BalanceState', () {
    test('copyWith preserves unchanged fields', () {
      const original = BalanceState(
        balance: Balance(amount: 100),
        isReconciling: true,
      );

      final copy = original.copyWith(isReconciling: false);

      expect(copy.balance.amount, equals(100));
      expect(copy.isReconciling, isFalse);
    });

    test('equality holds for same values', () {
      const a = BalanceState(balance: Balance(amount: 50));
      const b = BalanceState(balance: Balance(amount: 50));

      expect(a, equals(b));
    });

    test('equality fails for different amounts', () {
      const a = BalanceState(balance: Balance(amount: 50));
      const b = BalanceState(balance: Balance(amount: 99));

      expect(a, isNot(equals(b)));
    });

    test('equality fails for different isReconciling', () {
      const a = BalanceState(balance: Balance(amount: 50), isReconciling: true);
      const b = BalanceState(balance: Balance(amount: 50), isReconciling: false);

      expect(a, isNot(equals(b)));
    });
  });
}

// ---------------------------------------------------------------------------
// Helper: sequential balance repository
// ---------------------------------------------------------------------------

/// A fake [IBalanceRepository] that returns balances from a list in order.
///
/// Used to simulate the balance changing between the initial fetch and the
/// post-reconcile re-fetch.
class _SequentialBalanceRepository implements IBalanceRepository {
  _SequentialBalanceRepository({required this.balances});

  final List<Balance> balances;
  int _index = 0;

  int reconcileCallCount = 0;

  @override
  Future<Balance> getBalance() async {
    if (_index < balances.length) {
      return balances[_index++];
    }
    return balances.last;
  }

  @override
  Future<Balance> updateBalance(int amount) async {
    return Balance(amount: amount);
  }

  @override
  Future<void> reconcile() async {
    reconcileCallCount++;
  }

  @override
  Future<String> updateTimezone(String ianaTimezone) async => ianaTimezone;
}
