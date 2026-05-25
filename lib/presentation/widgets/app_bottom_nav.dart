import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// 5-tab persistent bottom navigation bar.
///
/// Active tab icon and label use [AppColors.primary] (teal).
/// Inactive tabs use [AppColors.mutedText] (grey).
///
/// Tabs (in order):
///   0 — Home (Dashboard)
///   1 — History
///   2 — Calendar
///   3 — Analytics
///   4 — Settings
///
/// Requirements: 2.1, 2.4, 11.5, 11.6
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Index of the currently active tab (0–4).
  final int currentIndex;

  /// Called when the user taps a tab.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.cardPrimary,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.mutedText,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
      elevation: 0,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          activeIcon: Icon(Icons.calendar_month),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
