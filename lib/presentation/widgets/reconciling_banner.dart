// presentation/widgets/reconciling_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../providers/balance_provider.dart';

/// Displays an informational "Balance may be updating..." banner when
/// [BalanceNotifier] sets [BalanceState.isReconciling] to `true`.
///
/// Dismissed automatically when the next balance fetch resolves the divergence
/// (i.e. [BalanceState.isReconciling] returns to `false`).
///
/// Requirements: 3.5, 3.6
class ReconcilingBanner extends ConsumerWidget {
  const ReconcilingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    final isReconciling = balanceAsync.value?.isReconciling ?? false;
    if (!isReconciling) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Balance may be updating...',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
