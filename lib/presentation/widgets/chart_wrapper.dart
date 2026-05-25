import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// A titled container for chart widgets with an optional loading overlay.
///
/// When [isLoading] is `true` a semi-transparent overlay with a
/// [CircularProgressIndicator] is shown on top of the [child] chart widget.
///
/// Requirements: 11.5
class ChartWrapper extends StatelessWidget {
  const ChartWrapper({
    super.key,
    required this.title,
    required this.child,
    this.isLoading = false,
  });

  /// Section title displayed above the chart.
  final String title;

  /// The chart widget (e.g. a `BarChart` or `PieChart` from fl_chart).
  final Widget child;

  /// When `true`, renders a loading overlay on top of [child].
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 16),
          Stack(
            children: [
              child,
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardPrimary.withAlpha(180),
                      borderRadius: AppRadius.cardBorderRadius,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
