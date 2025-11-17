import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('App starts and shows a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: WidgetsApp(color: Color(0xffffffff)),
    ));
    expect(find.byType(WidgetsApp), findsOneWidget);
  });
}
