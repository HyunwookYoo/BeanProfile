import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots and shows app name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('BeanProfile'))),
    ));
    expect(find.text('BeanProfile'), findsOneWidget);
  });
}
