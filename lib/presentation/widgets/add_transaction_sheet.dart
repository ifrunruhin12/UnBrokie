import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../domain/models/category.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_filter.dart';
import '../providers/metadata_provider.dart';
import '../providers/transaction_stream_provider.dart';

/// Reusable bottom sheet for adding a new transaction.
///
/// Used from the History screen and Calendar screen.
///
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5
///
/// Parameters:
/// - [filter]: the [TransactionFilter] key for the [transactionStreamProvider]
///   instance to call [createTransaction] on.
/// - [initialDate]: optional pre-filled date (used by Calendar screen when
///   the user taps a specific day cell).
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    required this.filter,
    this.initialDate,
  });

  /// The filter key identifying which [transactionStreamProvider] instance
  /// to call [createTransaction] on.
  final TransactionFilter filter;

  /// Optional pre-filled date (e.g. from Calendar screen day tap).
  final DateTime? initialDate;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  Category? _selectedCategory;
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  // Field-level error messages (Req 5.4)
  String? _categoryError;
  String? _amountError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Validates all fields and returns true if the form is valid.
  ///
  /// Sets field-level error messages for any invalid fields (Req 5.4).
  bool _validate() {
    bool valid = true;

    // Category required (Req 5.3)
    if (_selectedCategory == null) {
      _categoryError = 'Please select a category';
      valid = false;
    } else {
      _categoryError = null;
    }

    // Amount required and non-zero (Req 5.4)
    final rawAmount = _amountController.text.trim();
    if (rawAmount.isEmpty) {
      _amountError = 'Amount is required';
      valid = false;
    } else {
      final parsed = int.tryParse(rawAmount);
      if (parsed == null) {
        _amountError = 'Enter a valid whole number';
        valid = false;
      } else if (parsed == 0) {
        _amountError = 'Amount cannot be zero';
        valid = false;
      } else {
        _amountError = null;
      }
    }

    // Date required (Req 5.4)
    if (_selectedDate == null) {
      _dateError = 'Please select a date';
      valid = false;
    } else {
      _dateError = null;
    }

    setState(() {});
    return valid;
  }

  // ---------------------------------------------------------------------------
  // Date picker
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.cardPrimary,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.cardPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateError = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    // Client-side validation before any API call (Req 5.4)
    if (!_validate()) return;

    final category = _selectedCategory!;
    final amount = int.parse(_amountController.text.trim());
    final date = _selectedDate!;
    final note = _noteController.text.trim();

    final input = CreateTransactionInput(
      categoryId: category.id,
      amount: amount,
      date: date,
      note: note.isEmpty ? null : note,
    );

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(transactionStreamProvider(widget.filter).notifier)
          .createTransaction(input);

      // Req 5.5: dismiss sheet on success
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to add transaction: ${_friendlyError(e)}',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    return msg;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(metadataProvider);
    final categories = metaAsync.value?.categories ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Transaction',
                    style: AppTextStyles.headlineMedium,
                  ),
                  IconButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.mutedText,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  children: [
                    // ── Category selector (Req 5.3) ──────────────────────
                    _FieldLabel(label: 'Category'),
                    const SizedBox(height: 8),
                    metaAsync.isLoading
                        ? _CategoryLoadingPlaceholder()
                        : _CategorySelector(
                            categories: categories,
                            selected: _selectedCategory,
                            error: _categoryError,
                            onSelected: (cat) {
                              setState(() {
                                _selectedCategory = cat;
                                _categoryError = null;
                              });
                            },
                          ),
                    if (_categoryError != null) ...[
                      const SizedBox(height: 6),
                      _FieldError(message: _categoryError!),
                    ],
                    const SizedBox(height: 20),

                    // ── Amount input ─────────────────────────────────────
                    _FieldLabel(label: 'Amount'),
                    const SizedBox(height: 8),
                    _AmountField(
                      controller: _amountController,
                      error: _amountError,
                      enabled: !_isSubmitting,
                      onChanged: (_) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Date picker ──────────────────────────────────────
                    _FieldLabel(label: 'Date'),
                    const SizedBox(height: 8),
                    _DatePickerTile(
                      selectedDate: _selectedDate,
                      error: _dateError,
                      enabled: !_isSubmitting,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 20),

                    // ── Note input (optional) ────────────────────────────
                    _FieldLabel(label: 'Note (optional)'),
                    const SizedBox(height: 8),
                    _NoteField(
                      controller: _noteController,
                      enabled: !_isSubmitting,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Submit button
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppColors.primary.withAlpha(100),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorderRadius,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Text('Add Transaction'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Field label
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.mutedText,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field error
// ---------------------------------------------------------------------------

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category selector
// ---------------------------------------------------------------------------

class _CategoryLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.cardSecondary,
        borderRadius: AppRadius.inputBorderRadius,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selected,
    required this.error,
    required this.onSelected,
  });

  final List<Category> categories;
  final Category? selected;
  final String? error;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSecondary,
        borderRadius: AppRadius.inputBorderRadius,
        border: Border.all(
          color: error != null ? AppColors.error : AppColors.border,
          width: error != null ? 1.5 : 0.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Category>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.cardPrimary,
          borderRadius: AppRadius.cardBorderRadius,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          style: AppTextStyles.bodyMedium,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.mutedText,
            size: 20,
          ),
          hint: Row(
            children: [
              const Icon(
                Icons.category_outlined,
                color: AppColors.mutedText,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Select a category',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) {
            return categories.map((cat) {
              return Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(cat.name, style: AppTextStyles.bodyMedium),
                ],
              );
            }).toList();
          },
          items: categories.map((cat) {
            return DropdownMenuItem<Category>(
              value: cat,
              child: Text(cat.name, style: AppTextStyles.bodyMedium),
            );
          }).toList(),
          onChanged: (cat) {
            if (cat != null) onSelected(cat);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount field
// ---------------------------------------------------------------------------

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.error,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        // Allow optional leading minus sign followed by digits only
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      style: AppTextStyles.bodyMedium,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'e.g. -500 for expense, 1000 for income',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.mutedText,
        ),
        prefixIcon: const Icon(
          Icons.attach_money_rounded,
          color: AppColors.mutedText,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.cardSecondary,
        errorText: error,
        errorStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date picker tile
// ---------------------------------------------------------------------------

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.selectedDate,
    required this.error,
    required this.enabled,
    required this.onTap,
  });

  final DateTime? selectedDate;
  final String? error;
  final bool enabled;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final weekday = DateFormatter.monthAbbr(local);
    return '${_weekdayAbbr(local.weekday)}, $weekday ${local.day}, ${local.year}';
  }

  String _weekdayAbbr(int weekday) {
    const abbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrs[(weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.inputBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSecondary,
          borderRadius: AppRadius.inputBorderRadius,
          border: Border.all(
            color: error != null ? AppColors.error : AppColors.border,
            width: error != null ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: selectedDate != null
                  ? AppColors.primary
                  : AppColors.mutedText,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDate != null
                    ? _formatDate(selectedDate!)
                    : 'Select a date',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selectedDate != null
                      ? AppColors.textPrimary
                      : AppColors.mutedText,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Note field
// ---------------------------------------------------------------------------

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: 3,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Add a note…',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.mutedText,
        ),
        filled: true,
        fillColor: AppColors.cardSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
    );
  }
}
