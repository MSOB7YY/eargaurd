import 'package:flutter_test/flutter_test.dart';

import 'package:eargaurd/src/app.dart';

void main() {
  testWidgets('Dual home builds with bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EarGuardApp());
    await tester.pump();

    expect(find.text('Devices'), findsWidgets);
    expect(find.text('This device'), findsWidgets);
  });
}
