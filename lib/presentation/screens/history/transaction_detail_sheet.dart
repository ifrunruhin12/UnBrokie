import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/transaction_filter.dart';
import '../../providers/transaction_stream_provider.dart';

/// Bottom sheet showing all fields of a [Transaction] with override/skip/restore actions.
///
/// Requirements: 4.7, 4.8, 4.9, 4.10
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.filter,
  });

  final Transaction transaction;
  final TransactionFilter filter;

  bool get _isSkipped => transaction.status == TransactionStatus.skipped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
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
                    'Transaction Details',
                    style: AppTextStyles.headlineMedium,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  // Amount card
                  _AmountCard(transaction: transaction),
                  const SizedBox(height: 20),

                  // Detail fields
                  _DetailCard(
                    children: [
                      _DetailRow(
                        label: 'Category',
                        value: transaction.categoryName,
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        label: 'Date',
                        value: _formatFullDate(transaction.date),
                      ),
                      if (transaction.note != null &&
                          transaction.note!.isNotEmpty) ...[
                        _DetailDivider(),
                        _DetailRow(
                          label: 'Note',
                          value: transaction.note!,
                        ),
                      ],
                      _DetailDivider(),
                      _DetailRow(
                        label: 'Status',
                        value: _statusLabel(transaction.status),
                        valueColor: _statusColor(transaction.status),
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        label: 'ID',
                        value: transaction.id,
                        valueStyle: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Skipped visual indicator
                  if (_isSkipped)
                    _SkippedBanner(),

                  const SizedBox(height: 8),

                  // Action buttons
                  _ActionButtons(
                    transaction: transaction,
                    filter: filter,
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 24,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatFullDate(DateTime date) {
    final local = date.toLocal();
    final weekday = _weekdayFull(local.weekday);
    final month = _monthFull(local.month);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$weekday, $month ${local.day}, ${local.year}  $hour:$minute';
  }

  String _weekdayFull(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return names[(weekday - 1) % 7];
  }

  String _monthFull(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[(month - 1) % 12];
  }

  String _statusLabel(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.active:
        return 'Active';
      case TransactionStatus.skipped:
        return 'Skipped';
      case TransactionStatus.overridden:
        return 'Overridden';
      case TransactionStatus.pending:
        return 'Pending';
    }
  }

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.active:
        return AppColors.primary;
      case TransactionStatus.skipped:
        return AppColors.mutedText;
      case TransactionStatus.overridden:
        return const Color(0xFFF59E0B); // amber
      case TransactionStatus.pending:
        return AppColors.mutedText;
    }
  }
}

// ---------------------------------------------------------------------------
// Amount card
// ---------------------------------------------------------------------------

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.transaction});

  final Transaction transaction;

  bool get _isIncome => transaction.amount > 0;
  bool get _isSkipped => transaction.status == TransactionStatus.skipped;

  @override
  Widget build(BuildContext context) {
    final amountText = CurrencyFormatter.format(transaction.amount.abs());
    final sign = _isIncome ? '+' : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.cardSecondary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Category icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardPrimary,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.mutedText,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),

          // Category name
          Text(
            transaction.categoryName,
            style: _isSkipped
                ? AppTextStyles.titleMedium.copyWith(
                    color: AppColors.mutedText,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.mutedText,
                  )
                : AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 8),

          // Amount
          Text(
            '$sign$amountText',
            style: _isSkipped
                ? AppTextStyles.displayLarge.copyWith(
                    color: AppColors.mutedText,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.mutedText,
                  )
                : AppTextStyles.displayLarge.copyWith(
                    color: _isIncome
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
          ),

          // Date label
          const SizedBox(height: 4),
          Text(
            DateFormatter.transactionDateLabel(transaction.date),
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail card + rows
// ---------------------------------------------------------------------------

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSecondary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  AppTextStyles.bodyMedium.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: AppColors.border,
      indent: 16,
      endIndent: 16,
    );
  }
}

// ---------------------------------------------------------------------------
// Skipped banner
// ---------------------------------------------------------------------------

class _SkippedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mutedText.withAlpha(20),
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(
          color: AppColors.mutedText.withAlpha(60),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.block_outlined,
            color: AppColors.mutedText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'This transaction has been skipped and is excluded from your balance.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends ConsumerStatefulWidget {
  const _ActionButtons({
    required this.transaction,
    required this.filter,
  });

  final Transaction transaction;
  final TransactionFilter filter;

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool _isLoading = false;

  bool get _isSkipped =>
      widget.transaction.status == TransactionStatus.skipped;

  Future<void> _handleOverride() async {
    final result = await showDialog<_OverrideResult>(
      context: context,
      builder: (context) =>
          _OverrideDialog(transaction: widget.transaction),
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(transactionStreamProvider(widget.filter).notifier)
          .overrideTransaction(
            widget.transaction.id,
            amount: result.amount,
            note: result.note,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to override: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSkip() async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: 'Skip Transaction',
      message:
          'This transaction will be excluded from your balance. You can restore it later.',
      confirmLabel: 'Skip',
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(transactionStreamProvider(widget.filter).notifier)
          .skipTransaction(widget.transaction.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to skip: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: 'Restore Transaction',
      message: 'This transaction will be included in your balance again.',
      confirmLabel: 'Restore',
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(transactionStreamProvider(widget.filter).notifier)
          .restoreTransaction(widget.transaction.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Override button — always available (unless pending)
        if (widget.transaction.status != TransactionStatus.pending)
          _ActionButton(
            label: 'Override Amount / Note',
            icon: Icons.edit_outlined,
            color: AppColors.primary,
            onTap: _handleOverride,
          ),

        const SizedBox(height: 10),

        // Skip / Restore toggle
        if (_isSkipped)
          _ActionButton(
            label: 'Restore Transaction',
            icon: Icons.restore_outlined,
            color: AppColors.primary,
            onTap: _handleRestore,
          )
        else if (widget.transaction.status != TransactionStatus.pending)
          _ActionButton(
            label: 'Skip Transaction',
            icon: Icons.block_outlined,
            color: AppColors.mutedText,
            onTap: _handleSkip,
            outlined: true,
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withAlpha(100)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorderRadius,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorderRadius,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Override dialog
// ---------------------------------------------------------------------------

class _OverrideResult {
  const _OverrideResult({this.amount, this.note});

  final int? amount;
  final String? note;
}

class _OverrideDialog extends StatefulWidget {
  const _OverrideDialog({required this.transaction});

  final Transaction transaction;

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current values (show absolute amount for editing)
    final absAmount = widget.transaction.amount.abs();
    _amountController = TextEditingController(
      text: (absAmount / 100).toStringAsFixed(2),
    );
    _noteController = TextEditingController(
      text: widget.transaction.note ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final rawText = _amountController.text.trim().replaceAll(',', '');
    final parsed = double.tryParse(rawText);

    if (parsed == null || parsed <= 0) {
      setState(() => _amountError = 'Enter a valid amount greater than zero');
      return;
    }

    // Convert back to cents, preserving sign from original transaction
    final cents = (parsed * 100).round();
    final signedCents =
        widget.transaction.amount < 0 ? -cents : cents;

    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      _OverrideResult(
        amount: signedCents,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Override Transaction', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),

            // Amount field
            Text(
              'Amount',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                prefixText: '\$  ',
                prefixStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.mutedText,
                ),
                filled: true,
                fillColor: AppColors.cardSecondary,
                errorText: _amountError,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorderRadius,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorderRadius,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorderRadius,
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorderRadius,
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
            ),
            const SizedBox(height: 16),

            // Note field
            Text(
              'Note (optional)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: AppTextStyles.bodyMedium,
              maxLines: 3,
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
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedText,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Override'),
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

// ---------------------------------------------------------------------------
// Shared confirm dialog helper
// ---------------------------------------------------------------------------

Future<bool> _showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.cardPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedText,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
