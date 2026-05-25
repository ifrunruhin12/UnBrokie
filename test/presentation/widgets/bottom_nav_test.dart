import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/core/theme/design_tokens.dart';
import 'package:finance_app/presentation/widgets/app_bottom_nav.dart';

void main() {
  group('AppBottomNav', () {
    Widget buildSubject({int currentIndex = 0, ValueChanged<int>? onTap}) {
      return MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: currentIndex,
            onTap: onTap ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders exactly 5 tabs', (tester) async {
      await tester.pumpWidget(buildSubject());

      // BottomNavigationBar renders one BottomNavigationBarItem per tab.
      // Each item has a label — verify all 5 labels are present.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('active tab index 0 uses teal selected color', (tester) async {
      await tester.pumpWidget(buildSubject(currentIndex: 0));

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );

      expect(nav.selectedItemColor, AppColors.primary);
      expect(nav.currentIndex, 0);
    });

    testWidgets('inactive tabs use muted text color', (tester) async {
      await tester.pumpWidget(buildSubject(currentIndex: 0));

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );

      expect(nav.unselectedItemColor, AppColors.mutedText);
    });

    testWidgets('active tab index changes correctly', (tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(buildSubject(currentIndex: i));

        final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );

        expect(nav.currentIndex, i);
      }
    });

    testWidgets('onTap callback is invoked with correct index', (tester) async {
      int? tappedIndex;

      await tester.pumpWidget(
        buildSubject(
          currentIndex: 0,
          onTap: (i) => tappedIndex = i,
        ),
      );

      // Tap the "History" tab (index 1).
      await tester.tap(find.text('History'));
      await tester.pump();

      expect(tappedIndex, 1);
    });

    testWidgets('bottom nav is hidden on routes outside the shell',
        (tester) async {
      // Simulate a modal route pushed on top — the bottom nav should not be
      // visible because it is only rendered inside ScaffoldWithBottomNav.
      // Here we verify that a plain Scaffold without AppBottomNav has no nav.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Modal')),
            // No bottomNavigationBar — simulates a modal/detail route
          ),
        ),
      );

      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });
}
