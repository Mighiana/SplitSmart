import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitsmart/providers/app_state.dart';
import 'package:splitsmart/screens/new_budget_screen.dart';

/// Screen-flow (widget) tests for the New Budget screen — exercises the real
/// widget tree with a Provider-backed AppState, no Firebase/DB writes triggered.
/// Focuses on the subcategory picker added this cycle.
void main() {
  setUpAll(() {
    // Don't hit the network for fonts in tests — fall back immediately.
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // Use .value so the provider does NOT dispose the AppState on unmount —
  // AppState.dispose() calls stopRealtimeServices() which touches Firestore
  // (uninitialized in tests). We own the instance and let it be GC'd.
  Widget harness(AppState state) => ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: NewBudgetScreen()),
      );

  testWidgets('New Budget renders its core fields', (tester) async {
    await tester.pumpWidget(harness(AppState()));
    await tester.pumpAndSettle();

    expect(find.text('New Budget'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Create Budget'), findsOneWidget);
    // Categories field defaults to "All categories".
    expect(find.text('All categories'), findsOneWidget);
  });

  testWidgets('Category picker: expand a parent and select a subcategory',
      (tester) async {
    await tester.pumpWidget(harness(AppState()));
    await tester.pumpAndSettle();

    // Open the category picker sheet.
    await tester.tap(find.text('All categories'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget); // sheet title

    // Tapping a parent that has subs expands it (does not select it).
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget); // sub revealed

    // Select the sub-category, then close the sheet.
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // The field now reflects exactly one selected target (the sub key).
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('All categories'), findsNothing);
  });
}
