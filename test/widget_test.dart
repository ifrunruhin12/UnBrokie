// Basic smoke test for the Finance App root widget.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    // Pump a few frames to let the router and session provider initialize.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The app should render without throwing — the router will redirect to
    // /login since no token is stored in the test environment.
    // We just verify the widget tree is present and stable.
    expect(find.byType(App), findsOneWidget);
  });
}
