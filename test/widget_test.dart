import 'package:flutter_test/flutter_test.dart';

import 'package:dart_flutter_app/app/app.dart';

void main() {
  testWidgets('main menu renders', (WidgetTester tester) async {
    await tester.pumpWidget(const DartFlutterApp());

    expect(find.text('DartCore'), findsOneWidget);
    expect(find.text('Match Setup'), findsOneWidget);
    expect(find.text('Turniere'), findsOneWidget);
  });
}
