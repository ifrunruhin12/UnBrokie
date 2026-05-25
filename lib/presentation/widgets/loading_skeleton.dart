import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Shimmer placeholder widget shown while content is loading.
///
/// Renders an animated shimmer effect over a rounded rectangle of the given
/// [width], [height], and [borderRadius]. All values reference design tokens
/// rather than hardcoded constants.
///
/// Requirements: 12.8
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.small)),
  });

  /// Width of the skeleton placeholder.
  final double width;

  /// Height of the skeleton placeholder.
  final double height;

  /// Corner radius of the skeleton placeholder.
  /// Defaults to [AppRadius.small] (8px).
  final BorderRadius borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.cardSecondary.withAlpha(
                  (255 * (_animation.value - 0.1).clamp(0.2, 0.6)).round(),
                ),
                AppColors.cardSecondary.withAlpha(
                  (255 * (_animation.value + 0.1).clamp(0.2, 0.8)).round(),
                ),
                AppColors.cardSecondary.withAlpha(
                  (255 * (_animation.value - 0.1).clamp(0.2, 0.6)).round(),
                ),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
