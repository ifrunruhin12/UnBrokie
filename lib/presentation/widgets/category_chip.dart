import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/models/category.dart';

/// Pill-shaped filter chip for a transaction category.
///
/// When [selected] is `true` the chip uses [AppColors.primary] (teal) as its
/// background and label color. When unselected it uses the card secondary
/// surface with muted text.
///
/// Requirements: 11.5, 11.6
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final Category category;

  /// Whether this chip is currently selected.
  final bool selected;

  /// Called when the user taps the chip.
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(category.name),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: AppColors.cardSecondary,
      selectedColor: AppColors.primary.withAlpha(40),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.mutedText,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? 1.5 : 1.0,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.pillBorderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      showCheckmark: false,
    );
  }
}
