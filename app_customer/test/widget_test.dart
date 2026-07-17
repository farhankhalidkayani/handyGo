import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_customer/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HandyGoCustomerApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
