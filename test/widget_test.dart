import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:busana_prima/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BusanaPrimaApp()));

    // Verify the app renders
    expect(find.byType(BusanaPrimaApp), findsOneWidget);
  });
}
