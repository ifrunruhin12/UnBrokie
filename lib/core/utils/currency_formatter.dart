/// Utility for formatting integer paisa amounts as BDT currency strings.
/// Requirements: 3.1
abstract final class CurrencyFormatter {
  /// Formats an integer amount in paisa as a BDT currency string.
  ///
  /// Examples:
  ///   format(150000)  → "৳1,500.00"
  ///   format(-5050)   → "-৳50.50"
  ///   format(0)       → "৳0.00"
  ///   format(99)      → "৳0.99"
  static String format(int amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final taka = absAmount ~/ 100;
    final poisha = absAmount % 100;

    final takaStr = _formatWithCommas(taka);
    final poishaStr = poisha.toString().padLeft(2, '0');

    final formatted = '৳$takaStr.$poishaStr';
    return isNegative ? '-$formatted' : formatted;
  }

  static String _formatWithCommas(int value) {
    final str = value.toString();
    if (str.length <= 3) return str;

    final buffer = StringBuffer();
    final offset = str.length % 3;

    for (var i = 0; i < str.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
