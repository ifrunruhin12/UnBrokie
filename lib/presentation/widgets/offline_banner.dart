// presentation/widgets/offline_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../providers/network_status_provider.dart';

/// Displays a persistent "Offline" banner at the top of the screen when the
/// app has no network connectivity.
///
/// Stale cached data is shown transparently — the banner only appears when a
/// live foreground request fails with a [NetworkException].
///
/// Requirements: 3.5, 3.6
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(networkStatusProvider);
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.cardSecondary,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 14,
            color: AppColors.mutedText,
          ),
          const SizedBox(width: 6),
          Text(
            'Offline — showing cached data',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
