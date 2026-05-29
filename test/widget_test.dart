import 'package:flutter_test/flutter_test.dart';
import 'package:blaziq/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BlaziQApp());
    expect(find.byType(BlaziQApp), findsOneWidget);
  });
}
