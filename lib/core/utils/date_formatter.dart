/// Date formatting utilities for the finance app.
///
/// Provides:
/// - RFC3339 parsing
/// - "Today" / "Yesterday" / formatted date label for transaction list headers
/// - Month-range generation (returns from/to RFC3339 strings for a given month)
abstract final class DateFormatter {
  // ---------------------------------------------------------------------------
  // RFC3339 parsing
  // ---------------------------------------------------------------------------

  /// Parses an RFC3339 / ISO8601 date-time string and returns a UTC [DateTime].
  ///
  /// Throws [FormatException] if the string cannot be parsed.
  static DateTime parseRfc3339(String value) {
    return DateTime.parse(value).toUtc();
  }

  /// Parses an RFC3339 string and returns a local [DateTime].
  static DateTime parseRfc3339Local(String value) {
    return DateTime.parse(value).toLocal();
  }

  // ---------------------------------------------------------------------------
  // Transaction list date labels
  // ---------------------------------------------------------------------------

  /// Returns a human-readable label for a transaction group header.
  ///
  /// - Same calendar day as today  → "Today"
  /// - Same calendar day as yesterday → "Yesterday"
  /// - Otherwise → "Mon, Jan 1" style (abbreviated weekday + month + day)
  static String transactionDateLabel(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();

    if (_isSameDay(localDate, now)) return 'Today';
    if (_isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }

    return _formatShortDate(localDate);
  }

  /// Returns a human-readable label from an RFC3339 string.
  static String transactionDateLabelFromString(String rfc3339) {
    return transactionDateLabel(parseRfc3339(rfc3339));
  }

  // ---------------------------------------------------------------------------
  // Month-range generation
  // ---------------------------------------------------------------------------

  /// Returns the RFC3339 start-of-month and end-of-month strings for the
  /// given [year] and [month] (1-based).
  ///
  /// Example: monthRange(2024, 3) →
  ///   from: "2024-03-01T00:00:00.000Z"
  ///   to:   "2024-03-31T23:59:59.999Z"
  static ({String from, String to}) monthRange(int year, int month) {
    final start = DateTime.utc(year, month, 1);
    // Last day of month: day 0 of next month
    final end = DateTime.utc(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    return (from: _toRfc3339(start), to: _toRfc3339(end));
  }

  /// Returns the month range for the current month.
  static ({String from, String to}) currentMonthRange() {
    final now = DateTime.now();
    return monthRange(now.year, now.month);
  }

  /// Returns the month range for the month containing [date].
  static ({String from, String to}) monthRangeForDate(DateTime date) {
    return monthRange(date.year, date.month);
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  /// Formats a [DateTime] as an RFC3339 UTC string.
  static String toRfc3339(DateTime date) => _toRfc3339(date.toUtc());

  /// Formats a [DateTime] as "YYYY-MM" (used for big-buys month param).
  static String toYearMonth(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Formats a [DateTime] as "Jan 2024" (month + year label).
  static String monthYearLabel(DateTime date) {
    return '${_monthAbbr(date.month)} ${date.year}';
  }

  /// Formats a [DateTime] as "Jan" (abbreviated month).
  static String monthAbbr(DateTime date) => _monthAbbr(date.month);

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Formats as "Mon, Jan 1" — abbreviated weekday, abbreviated month, day.
  static String _formatShortDate(DateTime date) {
    final weekday = _weekdayAbbr(date.weekday);
    final month = _monthAbbr(date.month);
    return '$weekday, $month ${date.day}';
  }

  static String _toRfc3339(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    final ms = utc.millisecond.toString().padLeft(3, '0');
    return '$y-$mo-${d}T$h:$mi:$s.${ms}Z';
  }

  static String _weekdayAbbr(int weekday) {
    const abbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrs[(weekday - 1) % 7];
  }

  static String _monthAbbr(int month) {
    const abbrs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return abbrs[(month - 1) % 12];
  }
}
