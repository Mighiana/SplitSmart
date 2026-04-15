import 'package:flutter_test/flutter_test.dart';
import 'package:Splitsmart/main.dart';
import 'package:provider/provider.dart';
import 'package:Splitsmart/providers/app_state.dart';

void main() {
  testWidgets('SplitSmart app renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const SplitSmartApp(),
      ),
    );
    // App shows the loading gate or home screen — either is valid.
    expect(find.byType(SplitSmartApp), findsOneWidget);
  });
}
