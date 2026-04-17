import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_lora_frontend/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkingLoraApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
