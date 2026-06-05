import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking/main.dart';

void main() {
  testWidgets('App should build without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartParkApp());
    expect(find.text('SmartPark'), findsOneWidget);
  });
}
