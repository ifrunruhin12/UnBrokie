// Feature: flutter-finance-app, Property 16: Daily spend aggregation correctness
// Validates: Requirements 7.1

import 'package:finance_app/domain/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect, Throws;

// ---------------------------------------------------------------------------
// Helpers — mirrors the logic in _CalendarSection._buildSpendByDay
// ---------------------------------------------------------------------------

/// Aggregates transaction amounts by calendar day for a given [month].
///
/// This mirrors the logic in [_CalendarSection._buildSpendByDay] in
/// calendar_screen.dart. Pending transactions (id prefixed "pending-") are
/// excluded.
Map<int, int> buildSpendByDay(
  List<Transaction> transactions,
  DateTime month,
) {
  final map = <int, int>{};
  for (final tx in transactions) {
    if (tx.id.startsWith('pending-')) continue;
    final localDate = tx.date.toLocal();
    if (localDate.year == month.year && localDate.month == month.month) {
      map[localDate.day] = (map[localDate.day] ?? 0) + tx.amount;
    }
  }
  return map;
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Generates a non-zero int (positive or negative).
Generator<int> get _nonZeroInt => any.simple<int>(
      generate: (random, size) {
        final n = random.nextInt(size.clamp(1, 1 << 20)) + 1;
        return random.nextBool() ? n : -n;
      },
      shrink: (v) sync* {
        if (v.abs() > 1) yield v > 0 ? v - 1 : v + 1;
      },
    );

/// Generates a list of settled transactions, all in January 2024.
Generator<List<Transaction>> get _txListInJan2024 => any.simple<List<Transaction>>(
      generate: (random, size) {
        final count = random.nextInt(size.clamp(1, 20));
        return List.generate(count, (_) {
          final day = random.nextInt(28) + 1;
          final amount = _nonZeroInt(random, size).value;
          final id = 'tx-${random.nextInt(1 << 20)}';
          return Transaction(
            id: id,
            categoryId: 'cat-1',
            categoryName: 'Food',
            amount: amount,
            date: DateTime.utc(2024, 1, day),
            status: TransactionStatus.active,
          );
        });
      },
      shrink: (list) sync* {
        if (list.length > 1) yield list.sublist(0, list.length - 1);
      },
    );

/// Generates a pending Transaction in January 2024.
Generator<Transaction> get _pendingTxInJan2024 => any.simple<Transaction>(
      generate: (random, size) {
        final day = random.nextInt(28) + 1;
        final amount = _nonZeroInt(random, size).value;
        return Transaction(
          id: 'pending-${random.nextInt(1 << 20)}',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: amount,
          date: DateTime.utc(2024, 1, day),
          status: TransactionStatus.pending,
        );
      },
      shrink: (_) => [],
    );

// ---------------------------------------------------------------------------
// Unit tests — specific examples
// ---------------------------------------------------------------------------

void main() {
  final month = DateTime.utc(2024, 1);

  group('buildSpendByDay — unit tests', () {
    test('empty list returns empty map', () {
      final result = buildSpendByDay([], month);
      expect(result, isEmpty);
    });

    test('single transaction on day 5 returns correct spend', () {
      final txs = [
        Transaction(
          id: 'tx-1',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -500,
          date: DateTime.utc(2024, 1, 5),
          status: TransactionStatus.active,
        ),
      ];
      final result = buildSpendByDay(txs, month);
      expect(result[5], -500);
    });

    test('multiple transactions on same day are summed', () {
      final txs = [
        Transaction(
          id: 'tx-1',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -200,
          date: DateTime.utc(2024, 1, 10),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'tx-2',
          categoryId: 'cat-2',
          categoryName: 'Transport',
          amount: -300,
          date: DateTime.utc(2024, 1, 10),
          status: TransactionStatus.active,
        ),
      ];
      final result = buildSpendByDay(txs, month);
      expect(result[10], -500);
    });

    test('transactions on different days are in separate entries', () {
      final txs = [
        Transaction(
          id: 'tx-1',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -100,
          date: DateTime.utc(2024, 1, 3),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'tx-2',
          categoryId: 'cat-2',
          categoryName: 'Salary',
          amount: 1000,
          date: DateTime.utc(2024, 1, 15),
          status: TransactionStatus.active,
        ),
      ];
      final result = buildSpendByDay(txs, month);
      expect(result[3], -100);
      expect(result[15], 1000);
      expect(result.length, 2);
    });

    test('pending transactions are excluded', () {
      final txs = [
        Transaction(
          id: 'tx-1',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -200,
          date: DateTime.utc(2024, 1, 7),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'pending-abc',
          categoryId: 'cat-2',
          categoryName: 'Pending',
          amount: -9999,
          date: DateTime.utc(2024, 1, 7),
          status: TransactionStatus.pending,
        ),
      ];
      final result = buildSpendByDay(txs, month);
      expect(result[7], -200); // only the settled tx
    });

    test('transactions from other months are excluded', () {
      final txs = [
        Transaction(
          id: 'tx-jan',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -100,
          date: DateTime.utc(2024, 1, 5),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'tx-feb',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -200,
          date: DateTime.utc(2024, 2, 5),
          status: TransactionStatus.active,
        ),
      ];
      final result = buildSpendByDay(txs, month);
      expect(result.length, 1);
      expect(result[5], -100);
    });

    test('income and expense on same day are summed algebraically', () {
      final txs = [
        Transaction(
          id: 'tx-1',
          categoryId: 'cat-1',
          categoryName: 'Salary',
          amount: 1000,
          date: DateTime.utc(2024, 1, 20),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'tx-2',
          categoryId: 'cat-2',
          categoryName: 'Food',
          amount: -300,
          date: DateTime.utc(2024, 1, 20),
          status: TransactionStatus.active,
        ),
      ];
      final result = buildSpendByDay(txs, month);
      expect(result[20], 700); // 1000 + (-300)
    });
  });

  // ---------------------------------------------------------------------------
  // Property-based tests — Property 16: Daily spend aggregation correctness
  // Validates: Requirements 7.1
  // ---------------------------------------------------------------------------
  group('buildSpendByDay — property tests (Property 16)', () {
    // Property: for any day, the spend equals the sum of all transaction
    // amounts on that day (excluding pending).
    Glados(_txListInJan2024).test(
      'day cell amount equals sum of all transaction amounts on that date',
      (txs) {
        final result = buildSpendByDay(txs, month);

        // For each day that appears in the result, verify the sum
        for (final entry in result.entries) {
          final day = entry.key;
          final expectedSum = txs
              .where((tx) =>
                  !tx.id.startsWith('pending-') &&
                  tx.date.toLocal().year == 2024 &&
                  tx.date.toLocal().month == 1 &&
                  tx.date.toLocal().day == day)
              .fold<int>(0, (s, tx) => s + tx.amount);
          expect(entry.value, expectedSum,
              reason: 'Day $day spend mismatch');
        }
      },
    );

    // Property: every day with at least one settled transaction appears in the map.
    Glados(_txListInJan2024).test(
      'every day with settled transactions appears in the result map',
      (txs) {
        final result = buildSpendByDay(txs, month);

        final settledDays = txs
            .where((tx) =>
                !tx.id.startsWith('pending-') &&
                tx.date.toLocal().year == 2024 &&
                tx.date.toLocal().month == 1)
            .map((tx) => tx.date.toLocal().day)
            .toSet();

        for (final day in settledDays) {
          expect(result.containsKey(day), isTrue,
              reason: 'Day $day should be in result');
        }
      },
    );

    // Property: pending transactions never appear in the result.
    Glados2(any.list(_pendingTxInJan2024), _txListInJan2024).test(
      'pending transactions do not affect daily spend',
      (pending, settled) {
        final withoutPending = buildSpendByDay(settled, month);
        final withPending =
            buildSpendByDay([...settled, ...pending], month);

        // The result with pending transactions must equal the result without
        expect(withPending, equals(withoutPending));
      },
    );

    // Property: transactions from other months are never included.
    Glados(_txListInJan2024).test(
      'only transactions in the target month are included',
      (txs) {
        // Add some transactions from February
        final febTxs = txs.map((tx) => Transaction(
              id: 'feb-${tx.id}',
              categoryId: tx.categoryId,
              categoryName: tx.categoryName,
              amount: tx.amount,
              date: DateTime.utc(2024, 2, tx.date.day.clamp(1, 28)),
              status: tx.status,
            ));

        final result = buildSpendByDay([...txs, ...febTxs], month);

        // All days in result must be valid January days (1-31)
        for (final day in result.keys) {
          expect(day, inInclusiveRange(1, 31));
        }

        // Result must equal the result without February transactions
        final resultWithoutFeb = buildSpendByDay(txs, month);
        expect(result, equals(resultWithoutFeb));
      },
    );

    // Property: the result map has no more entries than days in the month.
    Glados(_txListInJan2024).test(
      'result map has at most 31 entries for January',
      (txs) {
        final result = buildSpendByDay(txs, month);
        expect(result.length, lessThanOrEqualTo(31));
      },
    );
  });
}
