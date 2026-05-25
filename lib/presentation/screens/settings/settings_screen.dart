import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../providers/balance_provider.dart';
import '../../providers/session_provider.dart';

/// Settings screen — profile, preferences, account actions.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);
    final session = sessionAsync.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Settings', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card (Req 10.1)
            _ProfileCard(
              userEmail: session?.userEmail,
              userId: session?.userId,
            ),
            const SizedBox(height: 24),

            // Account settings group (Req 10.2)
            _SettingsGroup(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Profile Settings',
                  onTap: () {
                    // Placeholder — navigates to profile settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile Settings coming soon'),
                        backgroundColor: AppColors.cardSecondary,
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications coming soon'),
                        backgroundColor: AppColors.cardSecondary,
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.security_outlined,
                  title: 'Security & Privacy',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Security & Privacy coming soon'),
                        backgroundColor: AppColors.cardSecondary,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preferences settings group (Req 10.3)
            _SettingsGroup(
              title: 'Preferences',
              children: [
                _SettingsTile(
                  icon: Icons.label_outline,
                  title: 'Categories',
                  onTap: () => context.push(AppRoutes.categories),
                ),
                _SettingsTile(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Big Buys',
                  onTap: () => context.push(AppRoutes.bigBuys),
                ),
                _SettingsTile(
                  icon: Icons.payment_outlined,
                  title: 'Payment Methods',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment Methods coming soon'),
                        backgroundColor: AppColors.cardSecondary,
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & Support coming soon'),
                        backgroundColor: AppColors.cardSecondary,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Timezone tile (Req 10.6)
            _SettingsGroup(
              title: 'Regional',
              children: [
                _TimezoneTile(),
              ],
            ),
            const SizedBox(height: 16),

            // Reconcile Account tile (Req 10.7)
            _SettingsGroup(
              title: 'Data',
              children: [
                _ReconcileAccountTile(),
              ],
            ),
            const SizedBox(height: 32),

            // Log Out destructive button (Req 10.4)
            _LogOutButton(),
            const SizedBox(height: 24),

            // Version string (Req 10.5)
            const Center(
              child: Text(
                'Version 1.0.0',
                style: AppTextStyles.bodySmall,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Card (Req 10.1)
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.userEmail,
    required this.userId,
  });

  final String? userEmail;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Avatar placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withAlpha(80),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User email as display name
                Text(
                  userEmail ?? 'User',
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // User ID (truncated for display)
                Text(
                  userId != null
                      ? 'ID: ${_truncateId(userId!)}'
                      : 'Not signed in',
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Truncates a UUID to first 8 characters for display.
  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }
}

// ---------------------------------------------------------------------------
// Settings Group
// ---------------------------------------------------------------------------

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              letterSpacing: 1.0,
              color: AppColors.mutedText,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardPrimary,
            borderRadius: AppRadius.cardBorderRadius,
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    color: AppColors.border,
                    indent: 52,
                    endIndent: 0,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Tile
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.cardSecondary,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium,
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
// Timezone Tile (Req 10.6)
// ---------------------------------------------------------------------------

class _TimezoneTile extends ConsumerWidget {
  const _TimezoneTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.schedule_outlined,
      title: 'Timezone',
      onTap: () => _openTimezoneDialog(context, ref),
    );
  }

  Future<void> _openTimezoneDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _TimezonePickerDialog(),
    );

    if (result == null || !context.mounted) return;

    // Call PATCH /account/timezone via repository
    try {
      final repo = ref.read(balanceRepositoryProvider);
      await repo.updateTimezone(result);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timezone updated to $result'),
            backgroundColor: AppColors.cardSecondary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update timezone: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Timezone Picker Dialog
// ---------------------------------------------------------------------------

class _TimezonePickerDialog extends StatefulWidget {
  const _TimezonePickerDialog();

  @override
  State<_TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<_TimezonePickerDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  static const _commonTimezones = [
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Sao_Paulo',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Asia/Kolkata',
    'Australia/Sydney',
    'Pacific/Auckland',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = 'Please enter a timezone');
      return;
    }
    if (value != 'UTC' && !value.contains('/')) {
      setState(() => _errorText = 'Enter a valid IANA timezone (e.g. America/New_York)');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: const Text('Select Timezone', style: AppTextStyles.headlineMedium),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter an IANA timezone string', style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'e.g. America/New_York',
                errorText: _errorText,
                filled: true,
                fillColor: AppColors.cardSecondary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              ),
              onChanged: (_) { if (_errorText != null) setState(() => _errorText = null); },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text('Common timezones:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText)),
            const SizedBox(height: 6),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: _commonTimezones.length,
                itemBuilder: (context, index) {
                  final tz = _commonTimezones[index];
                  return InkWell(
                    onTap: () {
                      _controller.text = tz;
                      setState(() => _errorText = null);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                      child: Text(tz, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reconcile Account Tile (Req 10.7)
// ---------------------------------------------------------------------------

class _ReconcileAccountTile extends ConsumerWidget {
  const _ReconcileAccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.sync_outlined,
      title: 'Reconcile Account',
      onTap: () => _confirmReconcile(context, ref),
    );
  }

  Future<void> _confirmReconcile(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text(
          'Reconcile Account',
          style: AppTextStyles.titleMedium,
        ),
        content: Text(
          'This will synchronize your account balance with your transaction history. '
          'Any discrepancies will be resolved by the server.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText),
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.buttonBorderRadius,
              ),
            ),
            child: const Text(
              'Reconcile',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(balanceRepositoryProvider);
      await repo.reconcile();

      // Invalidate balance so it re-fetches after reconciliation
      ref.invalidate(balanceProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account reconciled successfully'),
            backgroundColor: AppColors.cardSecondary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (e is NetworkException) {
          showMutationNetworkError(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reconciliation failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Log Out Button (Req 10.4)
// ---------------------------------------------------------------------------

class _LogOutButton extends ConsumerWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogOut(context, ref),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorderRadius,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text(
          'Log Out',
          style: AppTextStyles.titleMedium,
        ),
        content: Text(
          'Are you sure you want to log out? You will need to sign in again to access your account.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText),
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
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Calls sessionNotifier.logout() — clears token + cache.
    // go_router redirect guard will navigate to /login automatically.
    await ref.read(sessionProvider.notifier).logout();
  }
}
