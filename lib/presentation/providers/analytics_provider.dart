import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/analytics_summary.dart';
import '../../domain/models/transaction_filter.dart';
import '../../domain/services/analytics_service.dart';
import 'transaction_stream_provider.dart';

// ---------------------------------------------------------------------------
// Infrastructure provider
// ---------------------------------------------------------------------------

/// [AnalyticsService] provider — pure domain service, no side effects.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (_) => const AnalyticsService(),
);

// ---------------------------------------------------------------------------
// analyticsProvider
// ---------------------------------------------------------------------------

/// Client-computed analytics, keyed by [TransactionFilter].
///
/// Watches [transactionStreamProvider] directly — NOT [transactionViewProvider].
/// This prevents unnecessary recomputation when only UI filters (search query,
/// category chip) change.
///
/// Pending transactions (id prefixed `"pending-"`) are filtered out by
/// [AnalyticsService.compute] before any computation.
final analyticsProvider = AsyncNotifierProvider.family<
    AnalyticsNotifier, AnalyticsSummary, TransactionFilter>(
  (filter) => AnalyticsNotifier(filter),
);

class AnalyticsNotifier extends AsyncNotifier<AnalyticsSummary> {
  AnalyticsNotifier(this._filter);

  final TransactionFilter _filter;

  @override
  Future<AnalyticsSummary> build() async {
    final page = await ref.watch(transactionStreamProvider(_filter).future);
    final service = ref.read(analyticsServiceProvider);
    return service.compute(page.items);
  }
}
