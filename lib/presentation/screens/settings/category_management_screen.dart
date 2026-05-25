import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/models/category.dart';
import '../../providers/metadata_provider.dart';

/// Category management screen — full-screen route outside the shell.
///
/// Allows the user to view, add, rename, and delete categories.
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  bool _isAdding = false;
  String? _addError;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Add category
  // ---------------------------------------------------------------------------

  Future<void> _submitAdd() async {
    final name = _addController.text.trim();
    if (name.isEmpty) {
      setState(() => _addError = 'Category name cannot be empty');
      return;
    }

    setState(() {
      _isAdding = true;
      _addError = null;
    });

    try {
      await ref.read(metadataProvider.notifier).createCategory(name);
      _addController.clear();
      _addFocusNode.unfocus();
    } catch (e) {
      if (mounted) {
        setState(() => _addError = 'Failed to add category: $e');
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Rename category
  // ---------------------------------------------------------------------------

  Future<void> _showRenameDialog(Category category) async {
    final controller = TextEditingController(text: category.name);
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: const Text('Rename Category', style: AppTextStyles.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Category name',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.mutedText,
                  ),
                  errorText: errorText,
                  filled: true,
                  fillColor: AppColors.cardSecondary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorderRadius,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorderRadius,
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 0.5,
                    ),
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
                      width: 1.0,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorderRadius,
                    borderSide: const BorderSide(
                      color: AppColors.error,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                onSubmitted: (_) {
                  if (controller.text.trim().isEmpty) {
                    setDialogState(
                        () => errorText = 'Category name cannot be empty');
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(
                      () => errorText = 'Category name cannot be empty');
                  return;
                }
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorderRadius,
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final newName = controller.text.trim();
    if (newName == category.name) return; // no change

    try {
      await ref
          .read(metadataProvider.notifier)
          .updateCategory(category.id, newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename category: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete category
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete Category', style: AppTextStyles.titleMedium),
        content: Text(
          'Are you sure you want to delete "${category.name}"? '
          'This action cannot be undone.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.buttonBorderRadius,
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(metadataProvider.notifier).deleteCategory(category.id);
    } catch (e) {
      // On failure (e.g. category in use), show descriptive error and retain item.
      // The notifier already retains the item in state on failure.
      if (mounted) {
        final message = _deletionErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Returns a user-friendly error message for deletion failures.
  String _deletionErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('in use') ||
        lower.contains('referenced') ||
        lower.contains('constraint') ||
        lower.contains('409')) {
      return 'Cannot delete "${_categoryNameFromError(raw)}" — it is used by existing transactions.';
    }
    return 'Failed to delete category: $raw';
  }

  String _categoryNameFromError(String raw) => raw;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
        title: const Text('Categories', style: AppTextStyles.headlineMedium),
      ),
      body: Column(
        children: [
          // ----------------------------------------------------------------
          // Add category input
          // ----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _AddCategoryField(
              controller: _addController,
              focusNode: _addFocusNode,
              isLoading: _isAdding,
              errorText: _addError,
              onSubmit: _submitAdd,
              onChanged: (_) {
                if (_addError != null) {
                  setState(() => _addError = null);
                }
              },
            ),
          ),

          // ----------------------------------------------------------------
          // Error banner from provider (e.g. last mutation error)
          // ----------------------------------------------------------------
          metadataAsync.whenOrNull(
                data: (state) => state.error != null
                    ? _ErrorBanner(message: state.error!)
                    : null,
              ) ??
              const SizedBox.shrink(),

          // ----------------------------------------------------------------
          // Category list
          // ----------------------------------------------------------------
          Expanded(
            child: metadataAsync.when(
              loading: () => const _CategoryListSkeleton(),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load categories',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(metadataProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.buttonBorderRadius,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (state) {
                final categories = state.categories;
                if (categories.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryTile(
                      category: category,
                      onRename: () => _showRenameDialog(category),
                      onDelete: () => _confirmDelete(category),
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
// Add Category Field
// ---------------------------------------------------------------------------

class _AddCategoryField extends StatelessWidget {
  const _AddCategoryField({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.errorText,
    required this.onSubmit,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD CATEGORY',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTextStyles.bodyMedium,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'New category name',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mutedText,
                    ),
                    errorText: errorText,
                    filled: true,
                    fillColor: AppColors.cardSecondary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBorderRadius,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputBorderRadius,
                      borderSide: const BorderSide(
                        color: AppColors.border,
                        width: 0.5,
                      ),
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
                        width: 1.0,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputBorderRadius,
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                width: 80,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        AppColors.primary.withAlpha(100),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorderRadius,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Add',
                          style: TextStyle(fontWeight: FontWeight.w600),
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

// ---------------------------------------------------------------------------
// Category Tile (swipe-to-delete + rename action)
// ---------------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onRename,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(category.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(200),
          borderRadius: AppRadius.cardBorderRadius,
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (_) async {
        // Show confirmation dialog before actually dismissing
        onDelete();
        // Return false so the Dismissible doesn't remove the item itself —
        // the notifier handles list state (retains on failure).
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardPrimary,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Icon(
              Icons.label_outline,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            category.name,
            style: AppTextStyles.bodyMedium,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rename button
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.mutedText,
                  size: 20,
                ),
                onPressed: onRename,
                tooltip: 'Rename',
              ),
              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
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
              Icons.label_off_outlined,
              size: 56,
              color: AppColors.mutedText.withAlpha(120),
            ),
            const SizedBox(height: 16),
            const Text(
              'No categories yet',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first category above to get started.',
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

class _CategoryListSkeleton extends StatelessWidget {
  const _CategoryListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.cardPrimary,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
      ),
    );
  }
}
