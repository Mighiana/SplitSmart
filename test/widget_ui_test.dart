import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitzee/widgets/common_widgets.dart';

/// First widget-layer + accessibility tests for SplitSmart.
///
/// These complement the logic/model unit tests in `widget_test.dart`:
///  - render checks for shared widgets (icons-only mapping, count-up)
///  - automated WCAG/Material accessibility guideline checks on the app's real
///    primary palette and CTA pattern (contrast + tap-target size).
///
/// Full-screen flow tests (add-expense, budget picker, etc.) need a Provider
/// AppState + Firebase mock harness and are tracked as a follow-up.
void main() {
  group('shared widgets render', () {
    testWidgets('CountUpText renders its target value via the builder',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountUpText(
              value: 100,
              duration: Duration.zero,
              builder: (_, v) => Text('${v.round()}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('EmojiBox maps a category emoji to its Material icon',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmojiBox(emoji: '🍽️'))),
      );
      // '🍽️' (Food) resolves to restaurant_rounded via icon_map — and the box
      // must render an Icon, never the raw emoji glyph (icons-only UI).
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    });

    testWidgets('EmojiBox maps a sub-category key to its Material icon',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmojiBox(emoji: 'sub:food:groceries')),
        ),
      );
      expect(find.byIcon(Icons.local_grocery_store_rounded), findsOneWidget);
    });
  });

  group('accessibility guidelines', () {
    testWidgets('primary CTA meets contrast + tap-target + labeling guidelines',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFFF7F5F0), // app bg
            body: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7377), // TC.primary
                  foregroundColor: Colors.white,
                ),
                onPressed: () {},
                child: const Text('Create Budget'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // White-on-teal (#0D7377) is ~5.6:1 — passes WCAG AA for normal text.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      // Material requires a >=48x48 logical-pixel tap target.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // Every tappable must expose a semantic label.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });
  });
}
