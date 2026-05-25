// Feature: flutter-finance-app, Property 17: Analytics computation invariant
// Validates: Requirements 8.1

import 'dart:math';

import 'package:finance_app/domain/models/analytics_summary.dart';
import 'package:finance_app/domain/models/transaction.dart';
import 'package:finance_app/domain/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect, Throws;

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Generates a non-zero int (positive or negative, excluding 0).
Generator<int> get _nonZeroInt => any.simple<int>(
      generate: (random, size) {
        final n = random.nextInt(size.clamp(1, 1 << 30)) + 1;
        return random.nextBool() ? n : -n;
      },
      shrink: (v) sync* {
        if (v.abs() > 1) yield v > 0 ? v - 1 : v + 1;
      },
    );

/// Generates a positive int (income amount).
Generator<int> get _positiveInt => any.positiveInt;

/// Generates a negative int (expense amount).
Generator<int> get _negativeInt => any.negativeInt;

/// Generates a short alphanumeric string suitable for ids/names.
Generator<String> get _shortString => any.letterOrDigits;

/// Builds a settled (non-pending) Transaction from raw parts.
Transaction _makeSettled({
  required String id,
  required int amount,
  required String categoryId,
  required String categoryName,
  DateTime? date,
}) =>
    Transaction(
      id: 'tx-$id',
      categoryId: categoryId.isEmpty ? 'cat-default' : categoryId,
      categoryName: categoryName.isEmpty ? 'Default' : categoryName,
      amount: amount,
      date: date ?? DateTime(2024, 1, 15),
      status: TransactionStatus.active,
    );

/// Builds a pending Transaction from raw parts.
Transaction _makePending({
  required String id,
  required int amount,
}) =>
    Transaction(
      id: 'pending-$id',
      categoryId: 'cat-pending',
      categoryName: 'Pending',
      amount: amount,
      date: DateTime(2024, 1, 15),
      status: TransactionStatus.pending,
    );

/// Generator for a settled Transaction with a non-zero amount.
Generator<Transaction> get _settledTx => any.simple<Transaction>(
      generate: (random, size) {
        final id = _shortString(random, size).value;
        final amount = _nonZeroInt(random, size).value;
        final catId = _shortString(random, size).value;
        final catName = _shortString(random, size).value;
        return _makeSettled(
          id: id,
          amount: amount,
          categoryId: catId,
          categoryName: catName,
        );
      },
      shrink: (_) => [],
    );

/// Generator for a pending Transaction with a non-zero amount.
Generator<Transaction> get _pendingTx => any.simple<Transaction>(
      generate: (random, size) {
        final id = _shortString(random, size).value;
        final amount = _nonZeroInt(random, size).value;
        return _makePending(id: id, amount: amount);
      },
      shrink: (_) => [],
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _service = const AnalyticsService();

List<Transaction> _txList(List<(String, int, String, String)> specs) {
  return specs
      .map((s) => Transaction(
            id: s.$1,
            categoryId: s.$3,
            categoryName: s.$4,
            amount: s.$2,
            date: DateTime(2024, 1, 15),
            status: TransactionStatus.active,
          ))
      .toList();
}

// ---------------------------------------------------------------------------
// Unit tests — specific examples
// ---------------------------------------------------------------------------

void main() {
  group('AnalyticsService.compute — unit tests', () {
    test('empty list returns all zeros and empty lists', () {
      final result = _service.compute([]);
      expect(result.totalIncome, 0);
      expect(result.totalExpenses, 0);
      expect(result.netSavings, 0);
      expect(result.monthlyBars, isEmpty);
      expect(result.categorySlices, isEmpty);
    });

    test('single income transaction', () {
      final txs = _txList([('tx-1', 500, 'cat-1', 'Food')]);
      final result = _service.compute(txs);
      expect(result.totalIncome, 500);
      expect(result.totalExpenses, 0);
      expect(result.netSavings, 500);
    });

    test('single expense transaction', () {
      final txs = _txList([('tx-1', -300, 'cat-1', 'Food')]);
      final result = _service.compute(txs);
      expect(result.totalIncome, 0);
      expect(result.totalExpenses, 300);
      expect(result.netSavings, -300);
    });

    test('mixed income and expense', () {
      final txs = _txList([
        ('tx-1', 1000, 'cat-1', 'Salary'),
        ('tx-2', -400, 'cat-2', 'Food'),
        ('tx-3', -200, 'cat-3', 'Transport'),
      ]);
      final result = _service.compute(txs);
      expect(result.totalIncome, 1000);
      expect(result.totalExpenses, 600);
      expect(result.netSavings, 400);
    });

    test('pending transactions are excluded from computation', () {
      final txs = [
        Transaction(
          id: 'tx-1',
          categoryId: 'cat-1',
          categoryName: 'Salary',
          amount: 1000,
          date: DateTime(2024, 1, 15),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'pending-abc',
          categoryId: 'cat-2',
          categoryName: 'Food',
          amount: -9999,
          date: DateTime(2024, 1, 15),
          status: TransactionStatus.pending,
        ),
      ];
      final result = _service.compute(txs);
      expect(result.totalIncome, 1000);
      expect(result.totalExpenses, 0);
      expect(result.netSavings, 1000);
    });

    test('list of only pending transactions returns all zeros', () {
      final txs = [
        Transaction(
          id: 'pending-1',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -500,
          date: DateTime(2024, 1, 15),
          status: TransactionStatus.pending,
        ),
        Transaction(
          id: 'pending-2',
          categoryId: 'cat-2',
          categoryName: 'Salary',
          amount: 2000,
          date: DateTime(2024, 1, 15),
          status: TransactionStatus.pending,
        ),
      ];
      final result = _service.compute(txs);
      expect(result.totalIncome, 0);
      expect(result.totalExpenses, 0);
      expect(result.netSavings, 0);
      expect(result.monthlyBars, isEmpty);
      expect(result.categorySlices, isEmpty);
    });

    test('category slices only include expense transactions', () {
      final txs = _txList([
        ('tx-1', 1000, 'cat-income', 'Salary'),
        ('tx-2', -400, 'cat-food', 'Food'),
        ('tx-3', -200, 'cat-transport', 'Transport'),
      ]);
      final result = _service.compute(txs);
      final names = result.categorySlices.map((s) => s.categoryName).toSet();
      expect(names, isNot(contains('Salary')));
      expect(names, containsAll(['Food', 'Transport']));
    });

    test('category slice percentages sum to 100 for two equal categories', () {
      final txs = _txList([
        ('tx-1', -500, 'cat-1', 'Food'),
        ('tx-2', -500, 'cat-2', 'Transport'),
      ]);
      final result = _service.compute(txs);
      final total = result.categorySlices
          .fold<double>(0.0, (s, c) => s + c.percentage);
      expect(total, closeTo(100.0, 0.001));
    });

    test('monthly bars group by month correctly', () {
      final txs = [
        Transaction(
          id: 'tx-jan',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -100,
          date: DateTime(2024, 1, 10),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'tx-feb',
          categoryId: 'cat-1',
          categoryName: 'Food',
          amount: -200,
          date: DateTime(2024, 2, 5),
          status: TransactionStatus.active,
        ),
        Transaction(
          id: 'tx-jan2',
          categoryId: 'cat-2',
          categoryName: 'Salary',
          amount: 500,
          date: DateTime(2024, 1, 20),
          status: TransactionStatus.active,
        ),
      ];
      final result = _service.compute(txs);
      expect(result.monthlyBars.length, 2);
      final jan = result.monthlyBars.firstWhere((b) => b.month == 'Jan');
      final feb = result.monthlyBars.firstWhere((b) => b.month == 'Feb');
      expect(jan.income, 500);
      expect(jan.expenses, 100);
      expect(feb.income, 0);
      expect(feb.expenses, 200);
    });

    test('netSavings equals totalIncome minus totalExpenses', () {
      final txs = _txList([
        ('tx-1', 800, 'cat-1', 'Salary'),
        ('tx-2', -300, 'cat-2', 'Food'),
      ]);
      final result = _service.compute(txs);
      expect(result.netSavings, result.totalIncome - result.totalExpenses);
    });
  });

  // ---------------------------------------------------------------------------
  // Property-based tests — Property 17: Analytics computation invariant
  // Validates: Requirements 8.1
  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute — property tests (Property 17)', () {
    // Property: totalIncome equals the sum of all positive amounts.
    Glados(any.list(_settledTx)).test(
      'totalIncome equals sum of positive amounts',
      (txs) {
        final result = _service.compute(txs);
        final expected = txs
            .where((t) => t.amount > 0)
            .fold<int>(0, (s, t) => s + t.amount);
        expect(result.totalIncome, expected);
      },
    );

    // Property: totalExpenses equals the sum of abs(negative amounts).
    Glados(any.list(_settledTx)).test(
      'totalExpenses equals sum of absolute negative amounts',
      (txs) {
        final result = _service.compute(txs);
        final expected = txs
            .where((t) => t.amount < 0)
            .fold<int>(0, (s, t) => s + t.amount.abs());
        expect(result.totalExpenses, expected);
      },
    );

    // Property: netSavings == totalIncome - totalExpenses.
    Glados(any.list(_settledTx)).test(
      'netSavings equals totalIncome minus totalExpenses',
      (txs) {
        final result = _service.compute(txs);
        expect(result.netSavings, result.totalIncome - result.totalExpenses);
      },
    );

    // Property: category percentages sum to ~100% when there are expense transactions.
    Glados(any.list(_settledTx)).test(
      'category percentages sum to 100 when expenses exist',
      (txs) {
        final hasExpenses = txs.any((t) => t.amount < 0);
        if (!hasExpenses) return; // vacuously true — no slices to check

        final result = _service.compute(txs);
        if (result.categorySlices.isEmpty) return;

        final total = result.categorySlices
            .fold<double>(0.0, (s, c) => s + c.percentage);
        expect(total, closeTo(100.0, 0.01));
      },
    );

    // Property: pending transactions never affect any computed totals.
    Glados2(any.list(_settledTx), any.list(_pendingTx)).test(
      'pending transactions do not affect totals',
      (settled, pending) {
        final withoutPending = _service.compute(settled);
        final withPending = _service.compute([...settled, ...pending]);

        expect(withPending.totalIncome, withoutPending.totalIncome);
        expect(withPending.totalExpenses, withoutPending.totalExpenses);
        expect(withPending.netSavings, withoutPending.netSavings);
      },
    );

    // Property: category slices contain only categories that have expenses.
    Glados(any.list(_settledTx)).test(
      'category slices only include categories with expenses',
      (txs) {
        final result = _service.compute(txs);
        final expenseCategoryNames =
            txs.where((t) => t.amount < 0).map((t) => t.categoryName).toSet();
        for (final slice in result.categorySlices) {
          expect(expenseCategoryNames, contains(slice.categoryName));
        }
      },
    );

    // Property: totalIncome and totalExpenses are always non-negative.
    Glados(any.list(_settledTx)).test(
      'totalIncome and totalExpenses are always non-negative',
      (txs) {
        final result = _service.compute(txs);
        expect(result.totalIncome, greaterThanOrEqualTo(0));
        expect(result.totalExpenses, greaterThanOrEqualTo(0));
      },
    );
  });
}
