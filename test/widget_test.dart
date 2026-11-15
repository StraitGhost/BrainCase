import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:braincase/main.dart'; 

void main() {
  testWidgets('BrainCase app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BrainCaseApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}