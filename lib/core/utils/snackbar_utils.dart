// core/utils/snackbar_utils.dart

import 'package:flutter/material.dart';

import '../error/app_exception.dart';
import '../theme/design_tokens.dart';

/// Shows a "No connection" snackbar when a mutation fails with [NetworkException].
///
/// Call this in catch blocks for POST/PATCH/DELETE operations.
/// Requirements: 3.5, 3.6
void showMutationNetworkError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No connection — changes could not be saved.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.cardSecondary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        side: const BorderSide(color: AppColors.border),
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Shows the snackbar only if [error] is a [NetworkException]; otherwise
/// rethrows so callers can handle other error types.
void showNetworkErrorOrRethrow(BuildContext context, Object error) {
  if (error is NetworkException) {
    showMutationNetworkError(context);
  } else {
    throw error;
  }
}
