import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../domain/models/big_buy.dart';
import '../../../domain/models/category.dart';
import '../../providers/metadata_provider.dart';

/// Big Buys screen — full-screen route outside the shell (no bottom nav).
///
/// Displays large one-off purchases for a given month with full CRUD support.
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
class BigBuysScreen extends ConsumerStatefulWidget {
  const BigBuysScreen({super.key});

  @override
  ConsumerState<BigBuysScreen> createState() => _BigBuysScreenState();
}

class _BigBuysScreenState extends ConsumerState<BigBuysScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Future<void> _goToPreviousMonth() async {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    setState(() => _selectedMonth = prev);
    await ref
        .read(metadataProvider.notifier)
        .loadBigBuysForMonth(DateFormatter.toYearMonth(prev));
  }

  Future<void> _goToNextMonth() async {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    setState(() => _selectedMonth = next);
    await ref
        .read(metadataProvider.notifier)
        .loadBigBuysForMonth(DateFormatter.toYearMonth(next));
  }

  Future<void> _showAddSheet() async {
    final metaState = ref.read(metadataProvider).value;
    if (metaState == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BigBuyFormSheet(
        categories: metaState.categories,
        initialDate: DateTime(_selectedMonth.year, _selectedMonth.month),
      ),
    );
  }

  Future<void> _showEditSheet(BigBuy bigBuy) async {
    final metaState = ref.read(metadataProvider).value;
    if (metaState == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BigBuyFormSheet(
        categories: metaState.categories,
        initialDate: bigBuy.date,
        existing: bigBuy,
      ),
    );
  }

  Future<void> _confirmDelete(BigBuy bigBuy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete Big Buy', style: AppTextStyles.titleMedium),
        content: Text(
          'Are you sure you want to delete "${bigBuy.title}"? This cannot be undone.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorderRadius),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(metadataProvider.notifier).deleteBigBuy(bigBuy.id);
    } catch (e) {
      if (mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete big buy: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(metadataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Big Buys', style: AppTextStyles.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_big_buys',
        onPressed: _showAddSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _MonthNavigator(
            month: _selectedMonth,
            onPrevious: _goToPreviousMonth,
            onNext: _goToNextMonth,
          ),
          metadataAsync.whenOrNull(
                data: (state) => state.error != null
                    ? _ErrorBanner(message: state.error!)
                    : null,
              ) ??
              const SizedBox.shrink(),
          Expanded(
            child: metadataAsync.when(
              loading: () => const _BigBuyListSkeleton(),
              error: (error, _) => _LoadError(
                message: error.toString(),
                onRetry: () => ref.invalidate(metadataProvider),
              ),
              data: (state) {
                final items = state.bigBuys;
                if (items.isEmpty) return const _EmptyState();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final category = state.categories
                        .where((c) => c.id == item.categoryId)
                        .firstOrNull;
                    return _BigBuyTile(
                      bigBuy: item,
                      categoryName: category?.name,
                      onEdit: () => _showEditSheet(item),
                      onDelete: () => _confirmDelete(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month Navigator
// ---------------------------------------------------------------------------

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: onPrevious,
          ),
          Text(
            DateFormatter.monthYearLabel(month),
            style: AppTextStyles.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Big Buy Tile
// ---------------------------------------------------------------------------

class _BigBuyTile extends StatelessWidget {
  const _BigBuyTile({
    required this.bigBuy,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  final BigBuy bigBuy;
  final String? categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(bigBuy.title, style: AppTextStyles.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (categoryName != null)
              Text(categoryName!, style: AppTextStyles.bodySmall),
            Text(
              DateFormatter.transactionDateLabel(bigBuy.date),
              style: AppTextStyles.bodySmall,
            ),
            if (bigBuy.note != null && bigBuy.note!.isNotEmpty)
              Text(
                bigBuy.note!,
                style: AppTextStyles.bodySmall
                    .copyWith(fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(bigBuy.amount),
              style: AppTextStyles.amountExpense,
            ),
            const SizedBox(width: 4),
            PopupMenuButton<_BigBuyAction>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.mutedText, size: 20),
              color: AppColors.cardSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              onSelected: (action) {
                if (action == _BigBuyAction.edit) onEdit();
                if (action == _BigBuyAction.delete) onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _BigBuyAction.edit,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined,
                          color: AppColors.textPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text('Edit', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _BigBuyAction.delete,
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _BigBuyAction { edit, delete }

// ---------------------------------------------------------------------------
// Big Buy Form Sheet (Add + Edit)
// ---------------------------------------------------------------------------

class _BigBuyFormSheet extends ConsumerStatefulWidget {
  const _BigBuyFormSheet({
    required this.categories,
    required this.initialDate,
    this.existing,
  });

  final List<Category> categories;
  final DateTime initialDate;
  final BigBuy? existing;

  @override
  ConsumerState<_BigBuyFormSheet> createState() => _BigBuyFormSheetState();
}

class _BigBuyFormSheetState extends ConsumerState<_BigBuyFormSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  // Field errors
  String? _titleError;
  String? _amountError;
  String? _categoryError;
  String? _dateError;
  String? _submitError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    if (_isEditing) {
      final b = widget.existing!;
      _titleController.text = b.title;
      _amountController.text = (b.amount / 100).toStringAsFixed(2);
      _noteController.text = b.note ?? '';
      _selectedCategoryId = b.categoryId;
      _selectedDate = b.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _titleError = null;
      _amountError = null;
      _categoryError = null;
      _dateError = null;
    });

    if (_titleController.text.trim().isEmpty) {
      _titleError = 'Title is required';
      valid = false;
    }
    if (_selectedCategoryId == null) {
      _categoryError = 'Please select a category';
      valid = false;
    }
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _amountError = 'Amount is required';
      valid = false;
    } else {
      final parsed = double.tryParse(amountText);
      if (parsed == null || parsed <= 0) {
        _amountError = 'Enter a valid amount greater than zero';
        valid = false;
      }
    }
    setState(() {});
    return valid;
  }

  int get _amountInCents {
    final parsed = double.tryParse(_amountController.text.trim()) ?? 0;
    return (parsed * 100).round();
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      if (_isEditing) {
        await ref.read(metadataProvider.notifier).updateBigBuy(
              widget.existing!.id,
              UpdateBigBuyInput(
                title: _titleController.text.trim(),
                amount: _amountInCents,
                categoryId: _selectedCategoryId,
                date: _selectedDate,
                note: _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
            );
      } else {
        await ref.read(metadataProvider.notifier).createBigBuy(
              CreateBigBuyInput(
                title: _titleController.text.trim(),
                amount: _amountInCents,
                categoryId: _selectedCategoryId!,
                date: _selectedDate,
                note: _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
          setState(() => _isSubmitting = false);
        } else {
          setState(() {
            _submitError = 'Failed to ${_isEditing ? 'update' : 'add'} big buy: $e';
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.cardPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Edit Big Buy' : 'Add Big Buy',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 20),

            // Title field
            _FormField(
              label: 'Title',
              child: TextField(
                controller: _titleController,
                style: AppTextStyles.bodyMedium,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
                decoration: _inputDecoration(
                  hint: 'e.g. New laptop',
                  errorText: _titleError,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount field
            _FormField(
              label: 'Amount',
              child: TextField(
                controller: _amountController,
                style: AppTextStyles.bodyMedium,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_amountError != null) setState(() => _amountError = null);
                },
                decoration: _inputDecoration(
                  hint: '0.00',
                  prefixText: '\$ ',
                  errorText: _amountError,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category selector
            _FormField(
              label: 'Category',
              child: _CategoryDropdown(
                categories: widget.categories,
                selectedId: _selectedCategoryId,
                errorText: _categoryError,
                onChanged: (id) {
                  setState(() {
                    _selectedCategoryId = id;
                    _categoryError = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Date picker
            _FormField(
              label: 'Date',
              child: InkWell(
                onTap: _pickDate,
                borderRadius: AppRadius.inputBorderRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSecondary,
                    borderRadius: AppRadius.inputBorderRadius,
                    border: Border.all(
                      color: _dateError != null
                          ? AppColors.error
                          : AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.mutedText, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedDate.year}-'
                        '${_selectedDate.month.toString().padLeft(2, '0')}-'
                        '${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_dateError != null) ...[
              const SizedBox(height: 4),
              Text(_dateError!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 16),

            // Note field (optional)
            _FormField(
              label: 'Note (optional)',
              child: TextField(
                controller: _noteController,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                decoration: _inputDecoration(hint: 'Add a note…'),
              ),
            ),
            const SizedBox(height: 16),

            // Submit error
            if (_submitError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(30),
                  borderRadius: AppRadius.cardBorderRadius,
                  border: Border.all(
                      color: AppColors.error.withAlpha(80), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.primary.withAlpha(100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonBorderRadius,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add Big Buy',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? prefixText,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText),
      prefixText: prefixText,
      prefixStyle: AppTextStyles.bodyMedium,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.cardSecondary,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorderRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Dropdown
// ---------------------------------------------------------------------------

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardSecondary,
            borderRadius: AppRadius.inputBorderRadius,
            border: Border.all(
              color: errorText != null ? AppColors.error : AppColors.border,
              width: 0.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              isExpanded: true,
              dropdownColor: AppColors.cardSecondary,
              style: AppTextStyles.bodyMedium,
              hint: Text(
                'Select category',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.mutedText),
              ),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.mutedText),
              items: categories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: AppTextStyles.bodyMedium),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Form Field wrapper
// ---------------------------------------------------------------------------

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error Banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(30),
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.error.withAlpha(80), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Load Error
// ---------------------------------------------------------------------------

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text('Failed to load big buys',
                style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonBorderRadius),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: AppColors.mutedText.withAlpha(120),
            ),
            const SizedBox(height: 16),
            const Text('No big buys this month',
                style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap + to record a large purchase.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading Skeleton
// ---------------------------------------------------------------------------

class _BigBuyListSkeleton extends StatelessWidget {
  const _BigBuyListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.cardPrimary,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
      ),
    );
  }
}
