// Feature: flutter-finance-app, Property 5: Currency formatting invariant
// Validates: Requirements 3.1

import 'package:finance_app/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect, Throws;

void main() {
  // ---------------------------------------------------------------------------
  // Unit tests — specific examples
  // ---------------------------------------------------------------------------
  group('CurrencyFormatter.format — unit tests', () {
    test('formats zero cents', () {
      expect(CurrencyFormatter.format(0), '\$0.00');
    });

    test('formats positive cents less than one dollar', () {
      expect(CurrencyFormatter.format(99), '\$0.99');
    });

    test('formats exactly one dollar', () {
      expect(CurrencyFormatter.format(100), '\$1.00');
    });

    test('formats 150000 cents as \$1,500.00', () {
      expect(CurrencyFormatter.format(150000), '\$1,500.00');
    });

    test('formats negative amount with leading minus', () {
      expect(CurrencyFormatter.format(-5050), '-\$50.50');
    });

    test('formats large amount with multiple comma groups', () {
      expect(CurrencyFormatter.format(1234567890), '\$12,345,678.90');
    });

    test('formats 1 cent', () {
      expect(CurrencyFormatter.format(1), '\$0.01');
    });

    test('formats negative zero as positive zero', () {
      // -0 in Dart int is 0
      expect(CurrencyFormatter.format(-0), '\$0.00');
    });

    test('formats amount with no cents remainder', () {
      expect(CurrencyFormatter.format(200000), '\$2,000.00');
    });
  });

  // ---------------------------------------------------------------------------
  // Property-based tests — Property 5: Currency formatting invariant
  // Validates: Requirements 3.1
  // ---------------------------------------------------------------------------
  group('CurrencyFormatter.format — property tests', () {
    // Property: result is always a non-empty string
    Glados<int>().test(
      'result is always a non-empty string',
      (amount) {
        final result = CurrencyFormatter.format(amount);
        expect(result, isNotEmpty);
      },
    );

    // Property: result always contains a dollar sign
    Glados<int>().test(
      'result always contains a dollar sign',
      (amount) {
        final result = CurrencyFormatter.format(amount);
        expect(result, contains('\$'));
      },
    );

    // Property: result always contains a decimal point
    Glados<int>().test(
      'result always contains a decimal point',
      (amount) {
        final result = CurrencyFormatter.format(amount);
        expect(result, contains('.'));
      },
    );

    // Property: negative amounts produce a result starting with '-'
    Glados(any.positiveInt).test(
      'negative amounts start with minus sign',
      (amount) {
        // Use a positive amount and negate it (skip zero)
        if (amount == 0) return;
        final result = CurrencyFormatter.format(-amount);
        expect(result, startsWith('-'));
      },
    );

    // Property: positive amounts do NOT start with '-'
    Glados(any.positiveInt).test(
      'positive amounts do not start with minus sign',
      (amount) {
        final result = CurrencyFormatter.format(amount);
        expect(result, isNot(startsWith('-')));
      },
    );

    // Property: the numeric value is recoverable from the formatted string
    // i.e. the absolute dollar value appears in the string
    Glados<int>().test(
      'formatted string contains the numeric value',
      (amount) {
        final result = CurrencyFormatter.format(amount);
        final absAmount = amount.abs();
        final dollars = absAmount ~/ 100;
        final cents = absAmount % 100;
        final centsStr = cents.toString().padLeft(2, '0');

        // The cents part must appear after the decimal point
        expect(result, contains('.$centsStr'));

        // The dollar integer (without commas) must be reconstructable
        final dollarsInResult = result
            .replaceAll('-', '')
            .replaceAll('\$', '')
            .split('.')[0]
            .replaceAll(',', '');
        expect(int.parse(dollarsInResult), dollars);
      },
    );

    // Property: format never throws for any int input
    Glados<int>().test(
      'format never throws for any int input',
      (amount) {
        expect(() => CurrencyFormatter.format(amount), returnsNormally);
      },
    );

    // Property: format(0) == format(-0) (zero has no sign)
    test('zero has no negative sign', () {
      expect(CurrencyFormatter.format(0), '\$0.00');
      expect(CurrencyFormatter.format(0), isNot(startsWith('-')));
    });
  });
}
